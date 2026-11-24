extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()

func pitch(bus: int) -> float:
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectPitchShift: return effect.pitch_scale
	return 1.0

func run_test() -> void:
	# This destructive fixture must NEVER operate on real console/user data.
	if OS.get_name() != "Linux" or not OS.get_environment("XDG_DATA_HOME").contains("opensaberplus-profile-test"):
		push_error("Profile fixture requires an isolated Linux XDG_DATA_HOME")
		quit(1)
		return
	assert(OS.has_feature("ps4"))
	var settings = root.get_node("Settings")
	var constants = root.get_node("Constants")
	assert(constants.APPDATA_PATH == "user://OpenSaber/")
	assert(constants.CONFIG_ROOT_PATH == "user://plus/users/00000001/")
	for invalid in ["", "00000000", "../00001", "00000/01", "-1000000", "000000001"]:
		assert(constants.ps4_profile_path(invalid) == "user://plus/unidentified/")
	assert(constants.ps4_profile_path("7FFFFFFF") == "user://plus/users/7fffffff/")
	var legacy := "[OpenSaber]\n\naudio_music=0.42\nleft_handed=true\n".to_utf8_buffer()
	var original := "[OpenSaber]\n\nplayer_height_offset=0.25\n".to_utf8_buffer()
	var old_scores := '{"fallback-profile-must-not-change":true}'.to_utf8_buffer()
	var scores := '{"plus-legacy-profile-must-not-change":true}'.to_utf8_buffer()
	var counts := '{"test-map":3}'.to_utf8_buffer()
	put("user://config.ini", original)
	put("user://highscores.json", old_scores)
	put("user://plus/config.ini", legacy)
	put("user://plus/highscores.json", scores)
	put("user://plus/play_count.json", counts)
	if FileAccess.file_exists("user://plus/legacy_owner"):
		assert(DirAccess.remove_absolute("user://plus/legacy_owner") == OK)
	for name in ["config.ini", "play_count.json", "highscores.json"]:
		if FileAccess.file_exists(constants.CONFIG_ROOT_PATH + name):
			assert(DirAccess.remove_absolute(constants.CONFIG_ROOT_PATH + name) == OK)
	settings._ready()
	assert(settings.left_handed and is_equal_approx(settings.audio_music, 0.42))
	assert(is_equal_approx(settings.default_values.player_height_offset, 0.0))
	assert(is_equal_approx(settings.player_height_offset, 0.0), "New default is zero, without silently moving explicit saved offsets")
	assert(FileAccess.get_file_as_string("user://plus/legacy_owner") == "00000001")
	for name in ["play_count.json", "highscores.json"]:
		assert(FileAccess.get_file_as_bytes(constants.CONFIG_ROOT_PATH + name) == FileAccess.get_file_as_bytes("user://plus/" + name))
	settings.player_height_offset = 0.1
	settings.save()
	var user_a := FileAccess.get_file_as_bytes(settings.CONFIG_PATH)

	# Simulate a new native launch under account B (in-game account switching is not claimed).
	constants.PS4_PROFILE_ID = "00000002"
	constants.CONFIG_ROOT_PATH = constants.ps4_profile_path(constants.PS4_PROFILE_ID)
	settings.CONFIG_PATH = constants.CONFIG_ROOT_PATH + "config.ini"
	settings._ready()
	assert(is_equal_approx(settings.player_height_offset, 0.0) and not settings.left_handed)
	assert(not FileAccess.file_exists(constants.CONFIG_ROOT_PATH + "highscores.json"))
	assert(not FileAccess.file_exists(constants.CONFIG_ROOT_PATH + "play_count.json"))
	settings.player_height_offset = 0.2
	settings.save()
	var user_b := FileAccess.get_file_as_bytes(settings.CONFIG_PATH)
	constants.PS4_PROFILE_ID = "00000001"
	constants.CONFIG_ROOT_PATH = constants.ps4_profile_path(constants.PS4_PROFILE_ID)
	settings.CONFIG_PATH = constants.CONFIG_ROOT_PATH + "config.ini"
	settings._ready()
	assert(is_equal_approx(settings.player_height_offset, 0.1) and settings.left_handed)
	assert(FileAccess.get_file_as_bytes(settings.CONFIG_PATH) == user_a)
	assert(FileAccess.get_file_as_bytes("user://plus/users/00000002/config.ini") == user_b)
	assert(FileAccess.get_file_as_bytes("user://config.ini") == original)
	assert(FileAccess.get_file_as_bytes("user://highscores.json") == old_scores)
	assert(FileAccess.get_file_as_bytes("user://plus/config.ini") == legacy)
	assert(FileAccess.get_file_as_bytes("user://plus/highscores.json") == scores)
	assert(FileAccess.get_file_as_bytes("user://plus/play_count.json") == counts)
	var high_scores = load("res://game/scripts/HighscoreTable/HighscoreTable.gd").new()
	assert(high_scores.HIGHSCORES_FILEPATH == "user://plus/users/00000001/highscores.json")
	high_scores.free()
	assert(root.get_node("PlayCount").PLAY_COUNT_FILEPATH == "user://plus/users/00000001/play_count.json")

	settings.audio_master = 0.8
	settings.audio_music = 0.8
	settings.audio_music_preview = 0.6
	settings.music_speed = 125.0
	var music := AudioServer.get_bus_index(&"Music")
	var preview := AudioServer.get_bus_index(&"MusicPreview")
	assert(music >= 0 and preview >= 0)
	assert(is_equal_approx(pitch(music), 0.8) and is_equal_approx(pitch(preview), 0.8))
	settings.music_speed = 150.0
	assert(is_equal_approx(pitch(music), 2.0 / 3.0) and is_equal_approx(pitch(preview), 2.0 / 3.0))
	settings.audio_music = 0.0
	assert(is_equal_approx(pitch(music), 1.0) and is_equal_approx(pitch(preview), 2.0 / 3.0))
	settings.music_speed = 100.0
	assert(is_equal_approx(pitch(music), 1.0) and is_equal_approx(pitch(preview), 1.0))
	print("PLUS_PROFILE_TEST PASS: two isolated native accounts, legacy preferences/scores/counts migrate once, old files untouched, shared songs, zero default height, repeat music-speed changes")
	quit(0)
