extends Node

static func get_str(dict: Dictionary, key: String, default: String, platform_defaults: Dictionary = {}) -> String:
	if dict.has(key) and dict[key] is String:
		@warning_ignore("unsafe_cast")
		return dict[key] as String
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_bool(dict: Dictionary, key: String, default: bool, platform_defaults: Dictionary = {}) -> bool:
	if dict.has(key) and dict[key] is bool:
		@warning_ignore("unsafe_cast")
		return dict[key] as bool
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_float(dict: Dictionary, key: String, default: float, platform_defaults: Dictionary = {}) -> float:
	if dict.has(key) and dict[key] is float:
		@warning_ignore("unsafe_cast")
		return dict[key] as float
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_array(dict: Dictionary, key: String, default: Array, platform_defaults: Dictionary = {}) -> Array:
	if dict.has(key) and dict[key] is Array:
		@warning_ignore("unsafe_cast")
		return dict[key] as Array
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_dict(dict: Dictionary, key: String, default: Dictionary, platform_defaults: Dictionary = {}) -> Dictionary:
	if dict.has(key) and dict[key] is Dictionary:
		@warning_ignore("unsafe_cast")
		return dict[key] as Dictionary
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default
	
static func ends_in(name: String, exts: Array) -> bool:
	for ext in exts:
		if name.to_lower().ends_with(ext.to_lower()):
			return true
	return false

static func safe_relative_path(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or path.contains(":") or path.contains("\\"):
		return false
	for part in path.split("/", false):
		if part in [".", ".."]: return false
	return true

# ZIPReader allocates whole entries; validate directory sizes BEFORE reading payloads.
static func _zip_entries(zip_file: String) -> Dictionary:
	var file := FileAccess.open(zip_file, FileAccess.READ)
	if not file or file.get_length() < 22 or file.get_length() > 64 * 1024 * 1024: return {}
	var tail_size := mini(file.get_length(), 65557)
	file.seek(file.get_length() - tail_size)
	var tail := file.get_buffer(tail_size)
	var end := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(i) == 0x06054b50:
			if i + 22 + tail.decode_u16(i + 20) != tail.size(): return {}
			end = i
			break
	if end < 0: return {}
	var count := tail.decode_u16(end + 10)
	var directory_start := tail.decode_u32(end + 16)
	var directory_end := directory_start + tail.decode_u32(end + 12)
	if (tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0
		or count < 1 or count > 4096 or tail.decode_u16(end + 8) != count
		or directory_end != file.get_length() - tail_size + end): return {}
	file.seek(directory_start)
	var entries := {}
	var seen := {}
	var total_size := 0
	for i in count:
		if file.get_position() + 46 > directory_end: return {}
		var header := file.get_buffer(46)
		if header.size() != 46 or header.decode_u32(0) != 0x02014b50: return {}
		var size := header.decode_u32(24)
		var name_size := header.decode_u16(28)
		var next := file.get_position() + name_size + header.decode_u16(30) + header.decode_u16(32)
		if (header.decode_u16(8) & 1 or header.decode_u16(10) not in [0, 8]
			or header.decode_u16(34) != 0 or header.decode_u32(42) >= directory_start
			or size > 64 * 1024 * 1024 or name_size < 1 or name_size > 1024 or next > directory_end): return {}
		var name := file.get_buffer(name_size).get_string_from_utf8()
		if not safe_relative_path(name) or seen.has(name.to_lower()): return {}
		if name.ends_with("/") and size != 0: return {}
		total_size += size
		if total_size > 128 * 1024 * 1024: return {}
		entries[name] = size
		seen[name.to_lower()] = true
		file.seek(next)
	return entries if file.get_position() == directory_end else {}

static func unzip(zip_file: String, destination: String) -> Error:
	var entries := _zip_entries(zip_file)
	if entries.is_empty(): return ERR_FILE_CORRUPT
	var reader := ZIPReader.new()
	var error := reader.open(zip_file)
	if error != OK: return error
	var files := reader.get_files()
	if files.size() != entries.size():
		reader.close()
		return ERR_FILE_CORRUPT
	for name in files:
		if not entries.has(name):
			reader.close()
			return ERR_FILE_CORRUPT
	for name in files:
		var path := destination.path_join(name)
		if FileAccess.file_exists(path):
			error = ERR_ALREADY_EXISTS
			break
		error = DirAccess.make_dir_recursive_absolute(path if name.ends_with("/") else path.get_base_dir())
		if error != OK: break
		if name.ends_with("/"): continue
		var buffer := reader.read_file(name)
		if buffer.size() != entries[name]:
			error = ERR_FILE_CORRUPT
			break
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			error = FileAccess.get_open_error()
			break
		file.store_buffer(buffer)
		error = file.get_error()
		file.close()
		if error != OK: break
	reader.close()
	return error
	
static func file_exists(base: String, file: String) -> bool:
	if not safe_relative_path(file): return false
	if DirAccess.dir_exists_absolute(base):
		var path : String
		if base.ends_with("/"):
			path = base + file
		else:
			path = base + "/" + file
		return FileAccess.file_exists(path)
	elif base.to_lower().ends_with(".zip") and FileAccess.file_exists(base):
		var zreader := ZIPReader.new()
		if zreader.open(base) == OK:
			var exists := zreader.file_exists(file)
			zreader.close()
			return exists
	return false
			
static func read_binary_file(base: String, file: String) -> PackedByteArray:
	if not safe_relative_path(file): return PackedByteArray()
	if DirAccess.dir_exists_absolute(base):
		var path : String
		if base.ends_with("/"):
			path = base + file
		else:
			path = base + "/" + file
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle and handle.get_length() <= 64 * 1024 * 1024:
			return handle.get_buffer(handle.get_length())
	elif base.to_lower().ends_with(".zip") and _zip_entries(base).has(file):
		var zreader := ZIPReader.new()
		if zreader.open(base) == OK:
			var data := zreader.read_file(file)
			zreader.close()
			return data
	return PackedByteArray()
	
static func binary_to_json(data: PackedByteArray) -> Dictionary:
	if len(data) == 0:
		return {}
	else:
		var dict: Variant = JSON.parse_string(data.get_string_from_utf8())
		return dict as Dictionary if dict is Dictionary else {}
	
static var thread_finished : Array[Thread] = []
static var fake_thread_finished = {}

static func custom_thread_wait_to_finish(thread : Thread):
	if thread in thread_finished:
		var r = thread.wait_to_finish()
		thread_finished.remove_at(thread_finished.find(thread))
		return r
	elif thread in fake_thread_finished:
		var r = fake_thread_finished[thread]
		fake_thread_finished.erase(thread)
		return r
	return null

static func custom_thread_call(thread : Thread, function : Callable, params := []):
	# shortcut: nested map workers share arrays; serialize PS4 until that threaded path is safe.
	if OS.get_name() == &"Web" or OS.has_feature("ps4"):
		fake_thread_finished[thread] = function.callv(params)
		return 0
	else:
		thread_finished.append(thread)
		return thread.start(function.bindv(params))

static func precise_measurement(x : int) -> float:
	if x < 1000:
		return x
	else:
		return (x-1000.)/1000.

static func precise_angle_rad(direction: float, offset: float) -> float:
	var angle : float
	if direction < 1000:
		angle = Constants.CUBE_ROTATIONS[direction]
	else:
		angle = direction - 1000
	angle += offset * (PI/180.)
	if angle < 0:
		angle += TAU
	elif angle >= TAU:
		angle -= TAU
	if Settings.flip & Constants.FLIP_VERTICAL:
		angle = PI - angle
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		angle = -angle
		if angle < 0:
			angle += TAU
	if direction == 8:
		angle += Constants.DIRECTION8_OFFSET
	return angle

static func rotation_unit_vector(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))

static func close_angle(angle1: float, angle2: float) -> bool:
	return abs(angle1-angle2)<1e-5
	
static func update_bus_speed(bus_name: String) -> void:
	var speed := Settings.music_speed / 100.
	if (Settings.audio_master == 0. or 
			(bus_name == &"Music" and Settings.audio_music == 0.) or 
			(bus_name == &"MusicPreview" and Settings.audio_music_preview == 0.)):
		# ignore when silent
		speed = 1.
	
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		vr.log_error("Unknown bus "+bus_name)
		return
	for i in range(AudioServer.get_bus_effect_count(bus)):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectPitchShift:
			if speed == 1.:
				AudioServer.remove_bus_effect(bus, i)
			else:
				(effect as AudioEffectPitchShift).pitch_scale = 1./speed
			return
	if speed == 1.:
		return
	var effect := AudioEffectPitchShift.new()
	effect.pitch_scale = 1./speed
	AudioServer.add_bus_effect(bus, effect)

static func adjust_vertical(y: int) -> int:
	if Settings.flip & Constants.FLIP_VERTICAL:
		return 2-y
	else:
		return y

static func adjust_horizontal(x: int) -> int:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return 3-x
	else:
		return x
		
static func adjust_color(c: int) -> int:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return 1-c
	else:
		return c
		
static func adjust_lane_rotation(theta: float) -> float:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return -theta
	else:
		return theta
