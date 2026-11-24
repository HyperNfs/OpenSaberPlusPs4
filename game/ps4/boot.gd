extends Node

const GAME_PATH := "res://game/BeepSaber_Game.tscn"

func _ready() -> void:
	print("Open Saber startup: headless bootstrap ready; waiting for first TV draw")
	await RenderingServer.frame_post_draw
	print("Open Saber startup: first TV draw completed; requesting original scene")
	var error := ResourceLoader.load_threaded_request(GAME_PATH, "PackedScene", false)
	if error != OK:
		fail("Cannot request original scene: %s" % error_string(error))
		return
	while ResourceLoader.load_threaded_get_status(GAME_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(GAME_PATH) != ResourceLoader.THREAD_LOAD_LOADED:
		fail("Original scene loading failed; see opensaber-plus.log")
		return
	var packed := ResourceLoader.load_threaded_get(GAME_PATH) as PackedScene
	if packed == null:
		fail("Original scene is not a PackedScene")
		return
	print("Open Saber startup: original resources loaded; instantiating")
	var game: Variant = packed.instantiate()
	if game == null:
		fail("Cannot instantiate original scene")
		return
	print("Open Saber startup: original instance ready; entering tree")
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	print("Open Saber startup: warming up")
	while game.gamestate == game.gamestate_bootup:
		await get_tree().process_frame
	print("Open Saber startup: bootstrap finished")
	queue_free()

func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
