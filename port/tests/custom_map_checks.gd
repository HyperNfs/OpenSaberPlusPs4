extends Node

class OfflinePanel extends BeatSaverPanel:
	var urls: Array[String] = []
	var request_error := OK
	func _request(_request_node: HTTPRequest, url: String) -> Error:
		urls.append(url)
		return request_error

func _ready() -> void:
	call_deferred("run_test")

func write_zip(path: String, files: Dictionary) -> void:
	var writer := ZIPPacker.new()
	assert(writer.open(path) == OK)
	for name in files:
		assert(writer.start_file(name) == OK)
		assert(writer.write_file(str(files[name]).to_utf8_buffer()) == OK)
		assert(writer.close_file() == OK)
	assert(writer.close() == OK)

func put(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(data)
	file.close()

func check_v4(panel: Variant, base: String) -> void:
	var info_data := {"version": "4.0.1", "song": {"title": "V4 fixture", "author": "Fixture"},
		"audio": {"songFilename": "song.egg", "audioDataFilename": "AudioData.dat", "bpm": 120.0},
		"difficultyBeatmaps": [{"characteristic": "Standard", "difficulty": "ExpertPlus",
			"beatmapDataFilename": "Expert.dat", "lightshowDataFilename": "Lightshow.dat", "noteJumpMovementSpeed": 17.0}]}
	var timing := {"version": "4.0.0", "songFrequency": 44100.0,
		"bpmData": [{"si": 0.0, "ei": 44100.0, "sb": 0.0, "eb": 2.0}]}
	var chart := {"version": "4.1.0", "colorNotes": [{"b": 1.0, "i": 0.0}, {"b": 2.0, "i": 1.0}],
		"colorNotesData": [{"x": 1.0, "y": 0.0, "c": 0.0, "d": 1.0, "a": 15.0}, {"x": 2.0, "y": 2.0, "c": 1.0, "d": 0.0}],
		"bombNotes": [{"b": 3.0, "i": 0.0}], "bombNotesData": [{"x": 3.0, "y": 2.0}],
		"obstacles": [{"b": 4.0, "i": 0.0}], "obstaclesData": [{"x": 0.0, "y": 0.0, "w": 1.0, "h": 5.0, "d": 2.0}],
		"arcs": [{"hb": 1.0, "tb": 2.0, "hi": 0.0, "ti": 1.0, "ai": 0.0}], "arcsData": [{"m": 1.25, "tm": 0.75, "a": 2.0}],
		"chains": [{"hb": 1.0, "tb": 1.5, "i": 0.0, "ci": 0.0}], "chainsData": [{"tx": 1.0, "ty": 2.0, "c": 5.0, "s": 1.0}]}
	var lights := {"version": "4.0.0", "basicEvents": [{"b": 1.0, "i": 0.0}], "basicEventsData": [{"t": 1.0, "i": 5.0, "f": 0.25}]}
	var path := base.path_join("v4/")
	assert(DirAccess.make_dir_recursive_absolute(path) == OK)
	for pair in [["Info.dat", info_data], ["AudioData.dat", timing], ["Expert.dat", chart], ["Lightshow.dat", lights]]:
		put(path + pair[0], JSON.stringify(pair[1]).to_utf8_buffer())
	put(path + "song.egg", "placeholder".to_utf8_buffer())
	assert(panel._map_validation_error(path).is_empty())
	var info := Map.load_map_info(path)
	assert(info != null and info.song_name == "V4 fixture" and info.beats_per_minute == 120.0)
	var diff := info.difficulty_beatmaps[0]
	assert(diff.difficulty == "ExpertPlus" and diff.note_jump_movement_speed == 17.0)
	for iteration in 32:
		assert(Map.load_beatmap(info, diff, chart))
		assert(Map.note_stack.size() == 2 and Map.bomb_stack.size() == 1 and Map.obstacle_stack.size() == 1)
		assert(Map.note_stack.back().beat == 1.0 and is_equal_approx(Map.note_stack.back().cut_angle, deg_to_rad(15.0)))
		assert(Map.note_stack.back().color == 0 and Map.note_stack.front().color == 1)
		assert(Map.arc_stack[0].tail_line_index == 2 and is_equal_approx(Map.arc_stack[0].tail_cut_angle, PI))
		assert(Map.arc_stack[0].head_control_point_length_multiplier == 1.25)
		assert(Map.chain_stack[0].slice_count == 5 and Map.chain_stack[0].tail_beat == 1.5)
		assert(Map.event_stack[0].type == 1 and Map.event_stack[0].float_value == 0.25)
	for index: Variant in [-1.0, 0.5, 10000.0, "not an index", INF, NAN]:
		var bad := chart.duplicate(true)
		bad.colorNotes[0].i = index
		assert(BeatmapV4.to_v3(info, diff, bad).is_empty())
	for key: String in ["arcs", "chains"]:
		var bad := chart.duplicate(true)
		bad[key][0]["ai" if key == "arcs" else "ci"] = 9999.0
		assert(BeatmapV4.to_v3(info, diff, bad).is_empty())
	var bad := chart.duplicate(true)
	bad.colorNotes[0]["r"] = 1.0
	assert(BeatmapV4.to_v3(info, diff, bad).is_empty())
	bad = chart.duplicate(true)
	bad["njsEvents"] = [{"b": 1.0, "i": 0.0}]
	assert(BeatmapV4.to_v3(info, diff, bad).is_empty())
	diff.lightshow_filename = "../outside.dat"
	assert(BeatmapV4.to_v3(info, diff, chart).is_empty())
	diff.lightshow_filename = "Lightshow.dat"
	timing.bpmData.append(timing.bpmData[0].duplicate())
	put(path + "AudioData.dat", JSON.stringify(timing).to_utf8_buffer())
	assert(Map.load_map_info(path) == null)

	# Optional real-map regression: use the caller-supplied ZIP, never fetch during the fixture.
	var args := OS.get_cmdline_user_args()
	var index := args.find("--map-zip")
	if index >= 0:
		assert(index + 1 < args.size())
		var real_path := base.path_join("517ad/")
		assert(get_tree().root.get_node("Utils").unzip(args[index + 1], real_path) == OK)
		assert(panel._map_validation_error(real_path).is_empty())
		var real_info := Map.load_map_info(real_path)
		var audio := AudioStreamOggVorbis.load_from_file(real_path + real_info.song_filename)
		assert(audio != null and audio.get_length() > 103.0)
		var real_diff := real_info.difficulty_beatmaps[0]
		var real_chart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(real_path + real_diff.beatmap_filename))
		for iteration in 32:
			assert(Map.load_beatmap(real_info, real_diff, real_chart))
			assert(Map.note_stack.size() == 612 and Map.arc_stack.size() == 28 and Map.chain_stack.size() == 2)
			assert(Map.event_stack.size() == 962 and Map.chain_stack[0].slice_count == 5)
		print("MAP_517AD PASS: Ogg audio decoded; 32 loads, 612 notes, 28 arcs, 2 chains, 962 events")

func run_test() -> void:
	var utils: Variant = get_tree().root.get_node("Utils")
	var constants: Variant = get_tree().root.get_node("Constants")
	var settings: Variant = get_tree().root.get_node("Settings")
	var base: String = constants.APPDATA_PATH + "temp/custom-map-fixture/"
	assert(DirAccess.make_dir_recursive_absolute(base) == OK)
	var info_dict := {"_version": "2.1.0", "_songName": "Fixture", "_beatsPerMinute": 120.0,
		"_songFilename": "song.egg", "_difficultyBeatmapSets": [{"_difficultyBeatmaps": [{
		"_difficulty": "Expert", "_beatmapFilename": "data/Expert.dat"}]}]}
	var files := {"Info.dat": JSON.stringify(info_dict), "song.egg": "audio placeholder", "data/Expert.dat": "{}", "empty.txt": ""}
	var archive := base + "good.zip"
	write_zip(archive, files)
	assert(utils.unzip(archive, base + "good") == OK)
	assert(FileAccess.file_exists(base + "good/data/Expert.dat"))
	assert(FileAccess.file_exists(base + "good/empty.txt"))
	assert(utils.unzip(archive, base + "good") == ERR_ALREADY_EXISTS)
	for bad_path in ["../escape.txt", "/absolute.txt", "C:/escape.txt", "a/../../escape.txt", "a\\escape.txt"]:
		write_zip(base + "bad.zip", {bad_path: "no"})
		assert(utils.unzip(base + "bad.zip", base + "bad") == ERR_FILE_CORRUPT)
	assert(not FileAccess.file_exists(base + "escape.txt"))
	write_zip(base + "duplicate.zip", {"Info.dat": "a", "info.dat": "b"})
	assert(utils.unzip(base + "duplicate.zip", base + "duplicate") == ERR_FILE_CORRUPT)
	var forged := FileAccess.get_file_as_bytes(archive)
	for i in range(forged.size() - 46):
		if forged.decode_u32(i) == 0x02014b50:
			forged.encode_u32(i + 24, 0x7fffffff)
			break
	put(base + "bomb.zip", forged)
	assert(utils.unzip(base + "bomb.zip", base + "bomb") == ERR_FILE_CORRUPT)
	put(base + "html.zip", "<!DOCTYPE html>error".to_utf8_buffer())
	assert(utils.unzip(base + "html.zip", base + "html") == ERR_FILE_CORRUPT)

	var panel: Variant = load("res://game/ui/BeatSaverPanel/BeatSaverPanel.tscn").instantiate()
	panel.set_script(OfflinePanel)
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	panel._show()
	assert(panel.urls[0] == "https://api.beatsaver.com/maps/plays/0")
	assert(panel.httpdownload.body_size_limit == 64 * 1024 * 1024 and panel.httpdownload.timeout == 120.0)
	panel._on_HTTPRequest_request_completed(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), "{}".to_utf8_buffer())
	assert(not panel.mode_button.disabled and "503" in panel.label.text)
	panel._on_HTTPRequest_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer())
	assert("invalid" in panel.label.text)
	panel._on_HTTPRequest_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"docs":[]}'.to_utf8_buffer())
	assert(panel.next_page_available == -1)
	var hash := "0123456789abcdef0123456789abcdef01234567"
	var song := {"name": "../not-a-path", "metadata": {}, "versions": [{"hash": hash,
		"downloadURL": "https://r2cdn.beatsaver.com/fixture.zip", "diffs": []}]}
	panel._on_HTTPRequest_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"docs": [song]}).to_utf8_buffer())
	panel.item_selected = 0
	panel._on_download_button_up()
	assert(panel._download_active and panel.downloading.size() == 1)
	var count: int = panel.urls.size()
	panel._on_download_button_up()
	panel.download_next()
	assert(panel.urls.size() == count and panel.downloading.size() == 1)
	put(panel._archive_path, FileAccess.get_file_as_bytes(archive))
	panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	var installed: String = constants.APPDATA_PATH + "Songs/BeatSaver-" + hash
	assert(FileAccess.file_exists(installed + "/Info.dat") and "Downloaded:" in panel.label.text)
	assert(panel.downloading.is_empty() and not panel._download_active)
	panel._on_download_button_up()
	assert("not overwritten" in panel.label.text and panel.urls.size() == count)
	panel._remove_stage(installed)
	check_v4(panel, base)
	# Never publish an HTML error or unsupported/missing metadata as a playable map.
	panel._on_download_button_up()
	put(panel._archive_path, FileAccess.get_file_as_bytes(base + "html.zip"))
	panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	assert("install failed" in panel.label.text and not DirAccess.dir_exists_absolute(installed))
	for rejected in [
		{"files": {"Info.dat": '{"version":"4.0.0"}'}, "reason": "Unsupported Info.dat version/features 4.0.0"},
		{"files": {"Info.dat": "not JSON"}, "reason": "Invalid or unrecognized Info.dat JSON"},
		{"files": {"nested/Info.dat": JSON.stringify(info_dict)}, "reason": "Missing or unreadable Info.dat"},
		{"files": {"Info.dat": JSON.stringify(info_dict), "song.egg": "audio"}, "reason": "Missing chart file: data/Expert.dat"},
	]:
		write_zip(base + "rejected.zip", rejected.files)
		panel._on_download_button_up()
		var failed_stage: String = panel._archive_path + ".unpacked"
		put(panel._archive_path, FileAccess.get_file_as_bytes(base + "rejected.zip"))
		panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
		assert(rejected.reason in panel.label.text, panel.label.text)
		assert(not DirAccess.dir_exists_absolute(installed) and not DirAccess.dir_exists_absolute(failed_stage))
		assert(panel.downloading.is_empty() and not panel._download_active)
	panel._on_download_button_up()
	panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	assert("404" in panel.label.text and panel.downloading.is_empty())
	panel.request_error = ERR_CANT_CONNECT
	panel._on_download_button_up()
	assert(not panel._download_active and panel.downloading.is_empty() and "failed to start" in panel.label.text)
	panel.item_selected = 999
	assert(panel._get_selected_song() == null)

	var info := MapInfo.new_v2(JSON.parse_string(JSON.stringify(info_dict)), base)
	var difficulty := info.difficulty_beatmaps[0]
	settings.bombs_enabled = true
	for iteration in range(16):
		var notes := []
		for i in range(513):
			notes.append({"_time": float(i), "_type": float(i % 2), "_lineIndex": 1.0, "_lineLayer": 1.0, "_cutDirection": 1.0})
		notes.append(null)
		notes.append("malformed record must not hang")
		notes.append({"_time": 1.0, "_type": 3.0})
		var v2: Dictionary = JSON.parse_string(JSON.stringify({"_version": "2.0.0", "_notes": notes,
			"_obstacles": [{}], "_events": [{}], "_sliders": [{}]}))
		assert(Map.load_beatmap(info, difficulty, v2))
		assert(Map.note_stack.size() == 513 and Map.bomb_stack.size() == 1)
		assert(Map.obstacle_stack.size() == 1 and Map.event_stack.size() == 1 and Map.arc_stack.size() == 1)
		assert(Map.load_beatmap(info, difficulty, {"version": "3.3.0", "colorNotes": [{}, {}],
			"bombNotes": [{}], "obstacles": [{}], "basicBeatmapEvents": [{}], "sliders": [{}], "burstSliders": [{}]}))
		assert(Map.note_stack.size() == 2 and Map.bomb_stack.size() == 1 and Map.chain_stack.size() == 1)
		if OS.has_feature("ps4"):
			assert(not Map.note_thread_0.is_started() and not Map.note_thread_1.is_started())
			assert(utils.thread_finished.is_empty() and utils.fake_thread_finished.is_empty())
	panel._remove_stage(base)
	panel.queue_free()
	await get_tree().process_frame
	print("CUSTOM_MAP_TEST PASS: safe ZIPs, staged installs, queue/errors/API, repeated v2/v3 map loads without PS4 script workers")
	get_tree().quit(0)
