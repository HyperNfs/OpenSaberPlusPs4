extends RefCounted
class_name BeatmapV4

static func _read_json(path: String, name: String, limit: int) -> Dictionary:
	if not Utils.safe_relative_path(name): return {}
	var file := FileAccess.open(path.path_join(name), FileAccess.READ)
	if not file or file.get_length() > limit: return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data as Dictionary if data is Dictionary else {}

static func load_info(data: Dictionary, path: String) -> MapInfo:
	if not Utils.get_str(data, "version", "").begins_with("4.0."): return null
	var audio := Utils.get_dict(data, "audio", {})
	var song := Utils.get_dict(data, "song", {})
	var timing := _read_json(path, Utils.get_str(audio, "audioDataFilename", ""), 1024 * 1024)
	if not Utils.get_str(timing, "version", "").begins_with("4.0."): return null
	if not Utils.safe_relative_path(Utils.get_str(audio, "songFilename", "")): return null
	var segments := Utils.get_array(timing, "bpmData", [])
	# shortcut: the game clock is constant-BPM; add tempo-map playback before accepting multiple segments.
	if segments.size() != 1 or not segments[0] is Dictionary: return null
	var segment := segments[0] as Dictionary
	var frequency := Utils.get_float(timing, "songFrequency", 0.0)
	var samples := Utils.get_float(segment, "ei", 0.0)
	var beats := Utils.get_float(segment, "eb", 0.0)
	var bpm := Utils.get_float(audio, "bpm", 0.0)
	if (Utils.get_float(segment, "si", -1.0) != 0 or Utils.get_float(segment, "sb", -1.0) != 0
		or frequency <= 0 or samples <= 0 or beats <= 0 or bpm <= 0
		or absf(60.0 * beats * frequency / samples - bpm) > 0.01): return null
	var diffs := []
	var lightshows: Array[String] = []
	for value: Variant in Utils.get_array(data, "difficultyBeatmaps", []):
		if not value is Dictionary: return null
		var diff := value as Dictionary
		if Utils.get_str(diff, "characteristic", "") != "Standard": continue
		if not Utils.safe_relative_path(Utils.get_str(diff, "beatmapDataFilename", "")): return null
		if not Utils.safe_relative_path(Utils.get_str(diff, "lightshowDataFilename", "")): return null
		var name := Utils.get_str(diff, "difficulty", "")
		var ranks := {"Easy": 1.0, "Normal": 3.0, "Hard": 5.0, "Expert": 7.0, "ExpertPlus": 9.0}
		diffs.append({"_difficulty": name, "_difficultyRank": ranks.get(name, 0.0),
			"_beatmapFilename": Utils.get_str(diff, "beatmapDataFilename", ""),
			"_noteJumpMovementSpeed": Utils.get_float(diff, "noteJumpMovementSpeed", 1.0),
			"_noteJumpStartBeatOffset": Utils.get_float(diff, "noteJumpStartBeatOffset", 0.0),
			"_customData": Utils.get_dict(diff, "customData", {})})
		lightshows.append(Utils.get_str(diff, "lightshowDataFilename", ""))
	if diffs.is_empty(): return null
	var info := MapInfo.new_v2({"_version": data["version"],
		"_songName": Utils.get_str(song, "title", ""), "_songSubName": Utils.get_str(song, "subTitle", ""),
		"_songAuthorName": Utils.get_str(song, "author", ""), "_beatsPerMinute": bpm,
		"_songFilename": Utils.get_str(audio, "songFilename", ""),
		"_previewStartTime": Utils.get_float(audio, "previewStartTime", 0.0),
		"_previewDuration": Utils.get_float(audio, "previewDuration", 0.0),
		"_coverImageFilename": Utils.get_str(data, "coverImageFilename", ""),
		"_environmentName": "DefaultEnvironment", "_customData": Utils.get_dict(data, "customData", {}),
		"_difficultyBeatmapSets": [{"_beatmapCharacteristicName": "Standard", "_difficultyBeatmaps": diffs}]}, path)
	for i in lightshows.size(): info.difficulty_beatmaps[i].lightshow_filename = lightshows[i]
	return info

static func _at(data: Array, index: Variant) -> Dictionary:
	if not (index is float or index is int): return {}
	if not is_finite(float(index)) or index < 0 or index >= data.size() or index != int(index): return {}
	return data[int(index)] as Dictionary if data[int(index)] is Dictionary else {}

static func _expand(refs: Array, definitions: Array) -> Array:
	var result := []
	for value: Variant in refs:
		if not value is Dictionary: return []
		var ref := value as Dictionary
		var entry := _at(definitions, ref.get("i", -1))
		if entry.is_empty() or ref.get("r", 0) != 0: return []
		entry = entry.duplicate()
		entry["b"] = ref.get("b", 0.0)
		result.append(entry)
	return result

static func to_v3(info: MapInfo, difficulty: DifficultyInfo, data: Dictionary) -> Dictionary:
	var version := Utils.get_str(data, "version", "")
	if not (version.begins_with("4.0.") or version.begins_with("4.1.")): return {}
	if not Utils.get_array(data, "njsEvents", []).is_empty(): return {}
	for key: String in ["colorNotes", "colorNotesData", "bombNotes", "bombNotesData", "obstacles", "obstaclesData", "arcs", "arcsData", "chains", "chainsData", "njsEvents"]:
		if data.has(key) and not data[key] is Array: return {}
	var output := {"version": "3.3.0"}
	for key: String in ["colorNotes", "bombNotes", "obstacles"]:
		var refs := Utils.get_array(data, key, [])
		output[key] = _expand(refs, Utils.get_array(data, key + "Data", []))
		if output[key].size() != refs.size(): return {}
	var notes := Utils.get_array(data, "colorNotesData", [])
	output["sliders"] = []
	for value: Variant in Utils.get_array(data, "arcs", []):
		if not value is Dictionary: return {}
		var ref := value as Dictionary
		var head := _at(notes, ref.get("hi", -1))
		var tail := _at(notes, ref.get("ti", -1))
		var arc := _at(Utils.get_array(data, "arcsData", []), ref.get("ai", -1))
		if head.is_empty() or tail.is_empty() or arc.is_empty() or ref.get("hr", 0) != 0 or ref.get("tr", 0) != 0: return {}
		var item := head.duplicate()
		item.merge({"b": ref.get("hb", 0.0), "tb": ref.get("tb", 0.0),
			"tx": tail.get("x", 0.0), "ty": tail.get("y", 0.0), "tc": tail.get("d", 0.0),
			"mu": arc.get("m", 1.0), "tmu": arc.get("tm", 1.0), "m": arc.get("a", 0.0)}, true)
		output["sliders"].append(item)
	output["burstSliders"] = []
	for value: Variant in Utils.get_array(data, "chains", []):
		if not value is Dictionary: return {}
		var ref := value as Dictionary
		var head := _at(notes, ref.get("i", -1))
		var chain := _at(Utils.get_array(data, "chainsData", []), ref.get("ci", -1))
		if head.is_empty() or chain.is_empty() or ref.get("hr", 0) != 0 or ref.get("tr", 0) != 0: return {}
		if chain.get("c", 0) < 1 or chain.get("c", 0) > 128: return {}
		var item := head.duplicate()
		item.merge({"b": ref.get("hb", 0.0), "tb": ref.get("tb", 0.0),
			"tx": chain.get("tx", 0.0), "ty": chain.get("ty", 0.0),
			"sc": chain.get("c", 0.0), "s": chain.get("s", 1.0)}, true)
		output["burstSliders"].append(item)
	var lights := _read_json(info.filepath, difficulty.lightshow_filename, 16 * 1024 * 1024)
	if not Utils.get_str(lights, "version", "").begins_with("4.0."): return {}
	var refs := Utils.get_array(lights, "basicEvents", [])
	var events := _expand(refs, Utils.get_array(lights, "basicEventsData", []))
	if events.size() != refs.size(): return {}
	for event: Dictionary in events: event["et"] = event.get("t", 0.0)
	output["basicBeatmapEvents"] = events
	return output
