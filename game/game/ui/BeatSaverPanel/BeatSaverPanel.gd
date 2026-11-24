extends Panel
class_name BeatSaverPanel

class BeatSaverSongInfo extends RefCounted:
	var name: String
	var description: String
	var song_name: String
	var song_author_name: String
	var level_author_name: String
	var duration: float
	var versions: Array
	var uploader_id: int
	
	func _init(song_info: Dictionary) -> void:
		name = Utils.get_str(song_info, "name", "")
		description = Utils.get_str(song_info, "description", "")
		versions = Utils.get_array(song_info, "versions", [])
		uploader_id = int(Utils.get_float(Utils.get_dict(song_info, "uploader", {}), "id", -1))
		var metadata := Utils.get_dict(song_info, "metadata", {})
		song_name = Utils.get_str(metadata, "songName", "")
		song_author_name = Utils.get_str(metadata, "songAuthorName", "")
		level_author_name = Utils.get_str(metadata, "levelAuthorName", "")
		duration = Utils.get_float(metadata, "duration", 0.0)

var song_data: Array[BeatSaverSongInfo] = []
var current_list := 0
# reference to the main main node (used for playing downloadable song previews)
@export var main_menu_ref: MainMenu
# the next requestable pages for the current list; -1 if prev/next page is
# not requestable (ie. reached end of the list)
var prev_page_available := -1
var next_page_available := -1
# Older API used to support more lists. temporarily limiting to ones that still work
#var list_modes = ["hot","rating","latest","downloads","plays"]
var list_modes: Array[String] = ["plays"]
var search_word := ""
var item_selected := -1
var downloading := []#[["name","version_info"]]
var _download_active := false
var _archive_path := ""
const API := "https://api.beatsaver.com"

func _show_error(message: String) -> void:
	label.text = message
	label.visible = true
	vr.log_warning(message)

func _request(request: HTTPRequest, url: String) -> Error:
	for host in ["api.beatsaver.com", "beatsaver.com", "cdn.beatsaver.com", "r2cdn.beatsaver.com", "cfcdn.beatsaver.com"]:
		if url.begins_with("https://" + host + "/"):
			return request.request(url, ["User-Agent: OpenSaber/1.0"])
	return ERR_UNAUTHORIZED

@onready var item_list := $ItemList as ItemList
@onready var mode_button := $mode as Button
@onready var label := $Label as Label
@onready var httpreq := $HTTPReq as HTTPRequest
@onready var httpdownload := $HTTPDownload as HTTPRequest
@onready var httpcoverdownload := $CoverDownload as HTTPRequest
@onready var httppreviewdownload := $PreviewDownload as HTTPRequest
@onready var placeholder_cover := preload("res://game/data/beepsaber_logo.png")
@onready var goto_maps_by := $gotoMapsBy as Button
@onready var v_scroll := item_list.get_v_scroll_bar()

const MAX_BACK_STACK_DEPTH := 10
# series of previous requests that you can go back to
var back_stack: Array[BeatSaverRequest] = []

# structure representing the previous HTTP request we made to beatsaver
class BeatSaverRequest extends RefCounted:
	var page: int
	var type: String
	var data: String
var prev_request: BeatSaverRequest

@export var keyboard: OQ_UI2DKeyboard

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	($back as Button).visible = false
	v_scroll.value_changed.connect(_on_ListV_Scroll_value_changed)
	
	var is_web := OS.get_name() == "Web"
	
	for request in [httpreq, httpdownload, httpcoverdownload, httppreviewdownload]:
		request.use_threads = not is_web
		request.timeout = 20.0
		request.body_size_limit = 2 * 1024 * 1024
	httpdownload.timeout = 120.0
	httpdownload.body_size_limit = 64 * 1024 * 1024
	httppreviewdownload.body_size_limit = 8 * 1024 * 1024
	
	if keyboard != null:
		keyboard.text_input_enter.connect(_text_input_enter)
		keyboard.text_input_cancel.connect(_text_input_cancel)
	
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).visibility_changed.connect(_on_BeatSaverPanel_visibility_changed)
			break
		parent_canvas = parent_canvas.get_parent()

# override hide() method to handle case where UI is inside a OQ_UI2DCanvas
func _hide() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).hide()
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = false

# override show() method to handle case where UI is inside a OQ_UI2DCanvas
func _show() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).show()
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = true
	_on_BeatSaverPanel_visibility_changed()

func update_list(req: BeatSaverRequest) -> void:
	mode_button.disabled = true
	if req.page == 0:
		# brand new request, clear list to prep for reload
		item_list.clear()
		if goto_maps_by:
			goto_maps_by.visible = false
		song_data = []
		item_selected = -1
		_current_cover_to_download = 0
	if not httpcoverdownload:
		return
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	prev_page_available = req.page
	next_page_available = -1
	
	var request_error := ERR_INVALID_PARAMETER
	match req.type:
		"list":
			var list := req.data
			mode_button.text = list.substr(0,1).capitalize() + list.substr(1)
			request_error = _request(httpreq, API + "/maps/%s/%s" % [list,req.page])
		"text_search":
			var search_text := req.data
			mode_button.text = search_text
			request_error = _request(httpreq, API + "/search/text/%s?q=%s&sortOrder=Relevance&automapper=true" % [req.page,search_text.uri_encode()])
		"uploader":
			var uploader_id := req.data
			mode_button.text = "Uploader"
			request_error = _request(httpreq, API + "/maps/uploader/%s/%s" % [uploader_id,req.page])
		_:
			vr.log_warning("Unsupported request type '%s'" % req.type)
	if request_error != OK:
		mode_button.disabled = false
		_scroll_page_request_pending = false
		_show_error("BeatSaver request failed to start: %s" % error_string(request_error))

func _add_to_back_stack(request: BeatSaverRequest) -> void:
	if request == null: return
	back_stack.push_back(request)
	if back_stack.size() > MAX_BACK_STACK_DEPTH:
		back_stack.pop_front()

# return the selected song's data, or null if not song is selected
func _get_selected_song() -> BeatSaverSongInfo:
	if item_selected >= 0 and item_selected < song_data.size():
		return song_data[item_selected]
	return null

func _on_HTTPRequest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json_data is Dictionary:
			var json_dict := json_data as Dictionary
			if not json_dict.get("docs") is Array:
				_show_error("BeatSaver returned an invalid map list")
			if json_dict.has("docs"):
				var docs: Variant = json_dict["docs"]
				if docs is Array:
					var docs_array := docs as Array
					next_page_available = prev_page_available + 1 if not docs_array.is_empty() else -1
					for i: Variant in docs_array:
						if not i is Dictionary: continue
						var parsed_song := BeatSaverSongInfo.new(i as Dictionary)
						if parsed_song.versions.is_empty() or not parsed_song.versions[0] is Dictionary: continue
						var index := item_list.add_item(parsed_song.name)
						item_list.set_item_icon(index, placeholder_cover)
						var tooltip := "Map author: %s" % parsed_song.level_author_name
						item_list.set_item_tooltip(index, tooltip)
						song_data.append(parsed_song)
		else:
			_show_error("BeatSaver returned invalid JSON")
	else:
		_show_error("BeatSaver list failed: result %d, HTTP %d" % [result, response_code])
	mode_button.disabled = false
	($back as Button).visible = back_stack.size() > 0
	_scroll_page_request_pending = false
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()
	
	_update_all_covers()


func _on_mode_button_up() -> void:
	current_list += 1
	current_list %= list_modes.size()
	mode_button.text = list_modes[current_list].capitalize()
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "list"
	prev_request.data = list_modes[current_list]
	update_list(prev_request)


func _on_ItemList_item_selected(index: int) -> void:
	item_selected = index
	var selected_data := _get_selected_song()
	if selected_data == null or selected_data.versions.is_empty(): return
	var dur_s := int(selected_data.duration)
	var version = selected_data.versions[0]
	goto_maps_by.text = "Maps by %s" % selected_data.level_author_name
	goto_maps_by.visible = true
	var difficulties := ""
	for diff in Utils.get_array(version, "diffs", []):
		if diff is Dictionary:
			difficulties += " %s" % Utils.get_str(diff, "difficulty", "")
	var text := """[center]%s By %s[/center]

Map author: %s
Duration: %dm %ds
Difficulties:%s

[center]Description:[/center]
%s""" % [
		selected_data.song_name,
		selected_data.song_author_name,
		selected_data.level_author_name,
		dur_s/60,dur_s%60,
		difficulties,
		selected_data.description,
	]
	($song_data as RichTextLabel).text = text
	
	($TextureRect as TextureRect).texture = item_list.get_item_icon(index)

	httppreviewdownload.cancel_request()
	var preview_url := Utils.get_str(version, "previewURL", "")
	if not preview_url.is_empty():
		var error := _request(httppreviewdownload, preview_url)
		if error != OK: _show_error("Preview failed to start: %s" % error_string(error))

func _on_download_button_up() -> void:
	OS.request_permissions()
	var song := _get_selected_song()
	if song == null or song.versions.is_empty(): return
	var version: Dictionary = song.versions[0]
	var hash := Utils.get_str(version, "hash", "")
	if hash.length() != 40 or not hash.is_valid_hex_number():
		_show_error("BeatSaver returned an invalid map hash")
		return
	for queued in downloading:
		if queued[1].get("hash") == hash: return
	downloading.append([song.name, version])
	download_next()

func download_next() -> void:
	if _download_active or downloading.is_empty(): return
	var folder := Constants.APPDATA_PATH + "Songs/BeatSaver-" + str(downloading[0][1]["hash"]).to_lower()
	if DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):
		_download_finished("Map folder already exists; not overwritten")
		return
	var temp := Constants.APPDATA_PATH + "temp/"
	var error := DirAccess.make_dir_recursive_absolute(temp)
	if error != OK:
		_download_finished("Unable to create download directory: %s" % error_string(error))
		return
	_archive_path = temp + "beatsaver-%d.zip" % Time.get_ticks_usec()
	httpdownload.download_file = _archive_path
	_download_active = true
	error = _request(httpdownload, Utils.get_str(downloading[0][1], "downloadURL", ""))
	if error != OK:
		_download_finished("Download failed to start: %s" % error_string(error))
		return
	label.text = "Downloading: %s - %d left" % [str(downloading[0][0]), downloading.size() - 1]
	label.visible = true

func _remove_stage(path: String) -> void:
	var directory := DirAccess.open(path)
	if not directory: return
	directory.include_hidden = true
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		_remove_stage(path.path_join(name))
	DirAccess.remove_absolute(path)

func _map_validation_error(path: String) -> String:
	var info_path := path.path_join("Info.dat")
	if not FileAccess.file_exists(info_path): info_path = path.path_join("info.dat")
	var file := FileAccess.open(info_path, FileAccess.READ)
	if not file: return "Missing or unreadable Info.dat (check for an extra folder inside the ZIP)"
	if file.get_length() > 1024 * 1024: return "Info.dat exceeds the 1 MiB limit"
	var info := Map.load_map_info(path + "/")
	if info == null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.has("version"):
			return "Unsupported Info.dat version/features %s; v4 requires Standard charts and constant-BPM AudioData" % str(data["version"]).left(32)
		return "Invalid or unrecognized Info.dat JSON"
	if info.difficulty_beatmaps.is_empty(): return "Map has no supported difficulties"
	if not is_finite(info.beats_per_minute) or info.beats_per_minute <= 0: return "Invalid map BPM"
	if not Utils.safe_relative_path(info.song_filename): return "Unsafe audio filename"
	if not FileAccess.file_exists(path.path_join(info.song_filename)): return "Missing audio file: %s" % info.song_filename
	if info.song_filename.get_extension().to_lower() not in ["egg", "ogg"]: return "Unsupported audio format; Ogg/egg is required"
	if not info.cover_image_filename.is_empty() and not Utils.safe_relative_path(info.cover_image_filename): return "Unsafe cover filename"
	for difficulty in info.difficulty_beatmaps:
		if not Utils.safe_relative_path(difficulty.beatmap_filename): return "Unsafe chart filename"
		var beatmap := FileAccess.open(path.path_join(difficulty.beatmap_filename), FileAccess.READ)
		if not beatmap: return "Missing chart file: %s" % difficulty.beatmap_filename
		if beatmap.get_length() > 16 * 1024 * 1024: return "Chart exceeds the 16 MiB limit: %s" % difficulty.beatmap_filename
		if info.version.begins_with("4."):
			var chart: Variant = JSON.parse_string(beatmap.get_as_text())
			if not chart is Dictionary or BeatmapV4.to_v3(info, difficulty, chart as Dictionary).is_empty():
				return "Invalid v4 chart/lightshow, or unsupported rotation/NJS features: %s" % difficulty.beatmap_filename
	return ""

func _download_finished(message: String, installed := false) -> void:
	if not _archive_path.is_empty():
		DirAccess.remove_absolute(_archive_path)
		_archive_path = ""
	_download_active = false
	if not downloading.is_empty(): downloading.remove_at(0)
	label.text = message
	label.visible = true
	if installed and main_menu_ref:
		main_menu_ref._on_LoadPlaylists_Button_pressed()
	if not installed: vr.log_warning(message)
	download_next()

func _on_HTTPRequest_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _download_active or downloading.is_empty(): return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_download_finished("Download failed: result %d, HTTP %d" % [result, response_code])
		return
	var stage := _archive_path + ".unpacked"
	var error := DirAccess.make_dir_absolute(stage)
	if error == OK: error = Utils.unzip(_archive_path, stage)
	var validation_error := ""
	if error == OK:
		validation_error = _map_validation_error(stage)
		if not validation_error.is_empty(): error = ERR_FILE_UNRECOGNIZED
	var folder := Constants.APPDATA_PATH + "Songs/BeatSaver-" + str(downloading[0][1]["hash"]).to_lower()
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(folder.get_base_dir())
	if error == OK:
		if DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder): error = ERR_ALREADY_EXISTS
		else: error = DirAccess.rename_absolute(stage, folder)
	_remove_stage(stage)
	if error != OK:
		var reason := validation_error if not validation_error.is_empty() else "Archive/filesystem error: %s" % error_string(error)
		_download_finished("Map install failed (%s): %s" % [str(downloading[0][0]).left(96), reason])
	else:
		_download_finished("Downloaded: %s" % downloading[0][0], true)

func _on_preview_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# request preview to be played by the main menu node
		main_menu_ref.play_preview(
			body, # song data buffer
			0,    # start previous at time 0
			-1,   # play preview song for entire duration
			'mp3')# bsaver has all it's previews in mp3 format for now

func _on_search_button_up() -> void:
	keyboard._show()
	keyboard._text_edit.grab_focus()

func _text_input_enter(text: String) -> void:
	keyboard._hide()
	search_word = text
	mode_button.text = search_word
	current_list = -1
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "text_search"
	prev_request.data = search_word
	update_list(prev_request)

func _text_input_cancel() -> void:
	keyboard._hide()


var _current_cover_to_download := 0

func _update_all_covers() -> void:
	httpcoverdownload.cancel_request()
	update_next_cover()

func update_next_cover() -> void:
	if _current_cover_to_download < song_data.size():
		var cover_url := _get_cover_url_from_song_data(song_data[_current_cover_to_download])
		
		if cover_url == "":
			# song didn't have a cover. skip this cover and move to next one
			_current_cover_to_download += 1
			update_next_cover()
		else:
			var error := _request(httpcoverdownload, cover_url)
			if error != OK:
				_current_cover_to_download += 1
				update_next_cover()

func _update_cover(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var img := Image.new()
		if not img.load_jpg_from_buffer(body) == 0:
			img.load_png_from_buffer(body)
		var img_tex := ImageTexture.create_from_image(img)
		item_list.set_item_icon(_current_cover_to_download,img_tex)
	_current_cover_to_download += 1
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()
	
	update_next_cover()

func _on_gotoMapsBy_pressed() -> void:
	var selected_song := _get_selected_song()
	if selected_song == null or selected_song.uploader_id == -1: return
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "uploader"
	prev_request.data = str(selected_song.uploader_id)
	update_list(prev_request)
	
# SCROLL_TO_FETCH_THRESHOLD
# Range: 0.0 to 1.0
# Description: Used to request the next page of songs from the current list
# once the user scrolls past this threshold
const SCROLL_TO_FETCH_THRESHOLD := 0.9
var _scroll_page_request_pending := false

func _on_ListV_Scroll_value_changed(new_value: float) -> void:
	var scroll_range := v_scroll.max_value - v_scroll.min_value
	if scroll_range <= 0: return
	var scroll_ratio := (new_value + v_scroll.page) / scroll_range
	if scroll_ratio > SCROLL_TO_FETCH_THRESHOLD:
		if next_page_available == -1:
			# no next page to load
			return
		
		# prevent back to back requests
		if _scroll_page_request_pending:
			return
		
		# request next page and update list
		prev_request.page += 1
		update_list(prev_request)
		_scroll_page_request_pending = true

func _on_back_pressed() -> void:
	if back_stack.is_empty():
		return
	
	# re-request latest entry
	prev_request = back_stack.back()
	prev_request.page = 0
	back_stack.pop_back()
	update_list(prev_request)
	
	($back as Button).visible = back_stack.size() > 0

func _get_cover_url_from_song_data(song_info: BeatSaverSongInfo) -> String:
	var song_versions := song_info.versions
	var version_data := {}
	if len(song_versions) == 1:
		version_data = song_versions[0]# is there always 1 version?!?
	elif len(song_versions) > 1:
		vr.log_warning("The are %d versions for this song, but only getting cover for the first. song_data = %s" % [len(song_versions),song_data])
		version_data = song_versions[0]
	else:
		vr.log_warning("No version info available in song_data: %s" % song_data)
		return ""
		
	return Utils.get_str(version_data, "coverURL", "")

func _on_CloseButton_pressed() -> void:
	self._hide()

var _is_first_show := true
func _on_BeatSaverPanel_visibility_changed() -> void:
	if _is_first_show:
		# populate initial list of songs with most played on BeatSaver
		var first_req := BeatSaverRequest.new()
		first_req.page = 0
		first_req.type = "list"
		first_req.data = "plays"
		prev_request = first_req
		update_list(prev_request)
		_is_first_show = false
