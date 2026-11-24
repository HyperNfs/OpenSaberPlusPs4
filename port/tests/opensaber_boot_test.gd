extends SceneTree

class NativePSVRFixture extends XRInterfaceExtension:
	var started := false
	var starts := 0
	func _get_name() -> StringName: return &"PSVR"
	func _get_capabilities() -> int: return XRInterface.XR_STEREO | XRInterface.XR_VR
	func _get_system_info() -> Dictionary: return {}
	func _is_initialized() -> bool: return started
	func _initialize() -> bool:

		starts += 1
		started = true
		XRServer.primary_interface = self
		return true
	func _uninitialize() -> void:
		started = false
		XRServer.primary_interface = null
	func _get_view_count() -> int: return 2
	func _get_render_target_size() -> Vector2: return Vector2(1152, 1296)
	func _get_camera_transform() -> Transform3D: return Transform3D.IDENTITY

func _initialize() -> void:
	# Give the loading thread real time instead of racing uncapped headless frames.
	Engine.max_fps = 120
	call_deferred("run_test")

func run_test() -> void:
	assert(not ProjectSettings.get_setting("application/boot_splash/show_image"))
	assert(ProjectSettings.get_setting("application/boot_splash/image", "").is_empty())
	assert(ProjectSettings.get_setting("application/boot_splash/bg_color") == Color.BLACK)
	assert(not FileAccess.file_exists("res://ps4/splashscreen.png.import"))
	var vr: Variant = root.get_node("vr")
	if OS.has_feature("ps4"):
		var factory := root.get_node("StopwatchFactory")
		assert(not factory.is_processing() and not factory._server.is_listening())
		assert(factory._heartbeat_timer == null)
		assert(factory.create("native-local-timing", 4) != null)
	var backend := NativePSVRFixture.new()
	XRServer.add_interface(backend)
	var scene: Variant
	if "--boot-screen" in OS.get_cmdline_user_args():
		var boot := (load("res://ps4/boot.tscn") as PackedScene).instantiate()
		root.add_child(boot)
		current_scene = boot
		assert(not boot is CanvasLayer and not boot is CanvasItem and boot.get_child_count() == 0, "Bootstrap must have no loading overlay or artwork")
		assert(backend.starts == 0 and not root.use_xr)
		# Explicit fixture events, not GPU/SDK completion claims.
		RenderingServer.emit_signal("frame_post_draw")
		for frame in range(600):
			await process_frame
			RenderingServer.emit_signal("frame_post_draw")
			if current_scene != boot:
				scene = current_scene
				break
		assert(scene != null, "Threaded original-scene loading did not complete")
	else:
		scene = (load("res://game/BeepSaber_Game.tscn") as PackedScene).instantiate()
		assert(scene != null)
		root.add_child(scene)
		current_scene = scene
	assert(backend.starts == 0 and not vr.inVR and not root.use_xr)
	assert(scene.get_node("BeepCubePool").total_count() < 100)
	for frame in range(220):
		var before: int = scene.get_node("BeepCubePool").total_count() + scene.get_node("ChainLinkPool").total_count()
		RenderingServer.emit_signal("frame_post_draw")
		var after: int = scene.get_node("BeepCubePool").total_count() + scene.get_node("ChainLinkPool").total_count()
		assert(after <= before + 4, "Pool creation must remain bounded to four objects per draw")
		if backend.starts == 1:
			break
		await process_frame
	assert(backend.starts == 1 and vr.inVR and root.use_xr)
	assert(scene.get_node("BeepCubePool").total_count() == 100)
	assert(scene.get_node("ChainLinkPool").total_count() == 100)
	var pooled_emitters: Array[Node] = scene.find_children("*", "GPUParticles3D", true, false)
	assert(not pooled_emitters.is_empty())
	for emitter: GPUParticles3D in pooled_emitters:
		assert(not emitter.emitting, "Idle pooled particles must not start GPU work")
	assert(vr.active_arvr_interface_name == "PSVR")
	assert(scene.gamestate == scene.gamestate_mapselection)
	assert(scene.menu != null and scene.left_saber != null and scene.right_saber != null)
	if OS.has_feature("ps4"):
		var uploader: Variant = scene.menu.song_uploader_ref
		assert(not uploader.active and not uploader.server.is_listening() and not uploader.is_processing())
	assert(not scene.menu._all_songs.is_empty())
	var song: Variant = scene.menu._all_songs[0]
	assert(FileAccess.file_exists(song.filepath + song.song_filename))
	var audio := AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(song.filepath + song.song_filename))
	assert(audio != null and audio.get_length() > 0)
	assert(FileAccess.file_exists(song.filepath + song.cover_image_filename))
	assert(Image.load_from_file(song.filepath + song.cover_image_filename) != null)
	assert(scene.left_controller.pose == &"default" and scene.right_controller.pose == &"default")
	assert(not scene.left_controller.show_when_tracked and not scene.right_controller.show_when_tracked)
	assert(scene.left_saber.offset_pos == Vector3.ZERO)
	assert(scene.left_saber.offset_rot == Vector3(-90, 0, 0))
	Input.action_press("ui_accept")
	scene.right_controller._update_buttons_and_sticks()
	assert(scene.right_controller.trigger_pressed())
	Input.action_release("ui_accept")
	scene.right_controller._update_buttons_and_sticks()
	assert(scene.right_controller.trigger_just_released())
	# Let the original game finish its pre-render coroutine before deterministic input tests.
	for i in range(6):
		await process_frame
	if OS.has_feature("ps4"):
		check_height_settings(scene)
	check_hud_refresh(scene)
	await check_psvr_controls(scene)
	root.use_xr = false
	backend.uninitialize()
	scene.queue_free()
	await process_frame
	XRServer.remove_interface(backend)
	print("OPENSABER_BOOT_TEST PASS: original menu, first-draw PSVR gate, native default poses, saber axis and DS4 click bridge")
	quit(0)

func check_hud_refresh(scene: Variant) -> void:
	var scoreboard: Variant = root.get_node("Scoreboard")
	var settings: Variant = root.get_node("Settings")
	for name in ["Roboto-Medium.ttf", "RobotoMono-Medium.ttf"]:
		var font := load("res://OQ_Toolkit/OQ_UI2D/theme/" + name) as FontFile
		assert(font != null and font.multichannel_signed_distance_field, "Use scalable MSDF UI fonts without lowering eye resolution")
	scoreboard.restart()
	var observed := [0, -1.0]
	var changed := func() -> void:
		observed[0] += 1
		observed[1] = scoreboard.right_notes + scoreboard.wrong_notes
	scoreboard.score_changed.connect(changed)
	var refreshes := 0
	for i in range(60):
		scene._physics_process(1.0 / 60.0)
		if is_zero_approx(scene._hud_refresh_elapsed): refreshes += 1
	assert(observed[0] == 0, "Idle physics must not broadcast score/UI refreshes every tick")
	assert(refreshes >= 3 and refreshes <= 4, "Keep the countdown live at four updates/second")
	var was_health: bool = settings.health_mode
	settings.health_mode = false
	scoreboard.add_points(Vector3.ZERO, 0.0, 0)
	assert(observed[0] == 1 and is_equal_approx(observed[1], 1.0), "Score events must include the newly updated accuracy")
	scoreboard.score_changed.disconnect(changed)
	settings.health_mode = was_health
	scoreboard.restart()
	print("PLUS_RENDER_TEST PASS: MSDF fonts, event-driven scores/accuracy and live throttled song clock")

func check_height_settings(scene: Variant) -> void:
	var settings: Variant = root.get_node("Settings")
	var original := ConfigFile.new()
	assert(original.load(settings.CONFIG_PATH) == OK)
	var legacy := ConfigFile.new()
	legacy.set_value(settings.SECTION, "player_height_offset", 0.25)
	legacy.set_value(settings.SECTION, "ui_volume", 9.0)
	assert(legacy.save(settings.CONFIG_PATH) == OK)
	settings.config = ConfigFile.new() # A new process starts with an empty in-memory config.
	settings._ready()
	assert(is_equal_approx(settings.default_values.player_height_offset, 0.0))
	assert(is_equal_approx(settings.player_height_offset, 0.25), "Never silently move an explicitly saved height")
	assert(is_equal_approx(settings.ui_volume, 9.0), "Migration must preserve other settings")
	assert(scene.version == "PS4 01.19" and scene.menu.get_node("version").text == scene.version)
	var panel: Variant = scene.settings_panel
	panel.set_controls_from_settings()
	var control: SpinBox = panel.player_height_offset_control
	assert(control.allow_greater)
	control.value = 1.25
	assert(is_equal_approx(settings.player_height_offset, 1.25), "Height control must allow values above 0.25")
	settings.save()
	settings.config = ConfigFile.new()
	settings._ready()
	assert(is_equal_approx(settings.player_height_offset, 1.25), "High offsets must survive a restart")
	control.value = 0.1
	settings.save()
	settings.config = ConfigFile.new()
	settings._ready()
	assert(is_equal_approx(settings.player_height_offset, 0.1), "Account settings must preserve later manual adjustments")
	assert(original.save(settings.CONFIG_PATH) == OK)
	settings.reload()
	panel.set_controls_from_settings()

func check_psvr_controls(scene: Variant) -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var head := XRPositionalTracker.new()
	head.type = XRServer.TRACKER_HEAD
	head.name = &"head"
	var hand := XRControllerTracker.new()
	hand.type = XRServer.TRACKER_CONTROLLER
	hand.name = &"right_hand"
	XRServer.add_tracker(head)
	XRServer.add_tracker(hand)
	var camera: XRCamera3D = scene.get_node("XROrigin3D/XRCamera3D")
	var origin: XROrigin3D = scene.get_node("XROrigin3D")
	var settings: Variant = root.get_node("Settings")
	settings.player_height_offset = 0.0
	await process_frame
	var initial_height := -0.35
	head.set_pose(&"default", Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.7, initial_height, -0.8)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	hand.set_pose(&"default", Transform3D(Basis.IDENTITY, Vector3(0.9, initial_height - 0.5, -1.2)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	# A lost hand stays visible, but cannot cut, bank swing score or sweep a reacquisition jump.
	var saber: Variant = scene.right_saber
	var controller: Variant = scene.right_controller
	controller._physics_process(0.016)
	saber.set_swingcast_enabled(true)
	saber._physics_process(0.016)
	assert(controller.visible and saber.can_cut())
	var held_hand: Transform3D = controller.transform
	var live_hand: Transform3D = hand.get_pose(&"default").transform
	hand.invalidate_pose(&"default")
	controller._physics_process(0.016)
	saber._physics_process(0.016)
	assert(controller.visible and controller.transform.is_equal_approx(held_hand))
	assert(not saber.can_cut() and not saber._swing_cast.enabled and saber.score_queue.is_empty())
	saber._handle_area_collided(null) # Must return before dereferencing an untracked collision.
	hand.set_pose(&"default", Transform3D(Basis.IDENTITY, Vector3(9, -0.8, -12)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	controller.movement_aabb = AABB(Vector3.ZERO, Vector3.ONE)
	saber._physics_process(0.016)
	assert(saber.can_cut() and saber._swing_cast.enabled)
	assert(controller.movement_aabb.size.is_zero_approx(), "Reacquisition must not inflate legacy travel-distance scoring")
	for i in saber._swing_cast._rays.size():
		assert(saber._swing_cast._prev_ray_positions[i].is_equal_approx(saber._swing_cast._rays[i].global_position))
	saber.set_swingcast_enabled(false)
	hand.set_pose(&"default", live_hand, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	var before_distance: float = camera.global_position.distance_to(scene.right_controller.global_position)
	scene._update_psvr_recenter(0.0)
	assert(camera.global_position.is_equal_approx(Vector3(0, 1.8, 1)), "Camera-relative tracking must recenter above the floor")
	assert(abs(camera.global_rotation.y) < 0.0001)
	assert(is_equal_approx(before_distance, camera.global_position.distance_to(scene.right_controller.global_position)))
	var centered := origin.transform
	for i in range(2):
		scene.recenter()
	assert(origin.transform.is_equal_approx(centered), "Repeated recenter must not drift")
	var standing_pose := head.get_pose(&"default").transform
	var crouched_pose := standing_pose
	crouched_pose.origin.y -= 0.25
	head.set_pose(&"default", crouched_pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	scene._update_psvr_recenter(0.1)
	assert(is_equal_approx(camera.global_position.y, 1.55), "Crouching must still move the camera after centering")
	head.set_pose(&"default", standing_pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	settings.player_height_offset = 0.2
	await process_frame
	assert(is_equal_approx(camera.global_position.y, 2.0), "Height setting must preserve the calibrated floor offset")
	scene.recenter()
	scene.recenter()
	assert(is_equal_approx(camera.global_position.y, 2.0), "Recenter must not compound the user's height offset")
	settings.player_height_offset = 0.0
	await process_frame
	assert(is_equal_approx(camera.global_position.y, 1.8))
	# Move trigger/button edges, analog isolation, and release on tracker removal.
	hand.set_input(&"trigger", 0.25)
	hand.set_input(&"trigger_click", false)
	scene.right_controller._update_buttons_and_sticks()
	assert(not scene.right_controller.trigger_pressed())
	hand.set_input(&"trigger_click", true)
	hand.set_input(&"ax_button", true)
	scene.right_controller._update_buttons_and_sticks()
	assert(scene.right_controller.trigger_just_pressed() and scene.right_controller.ax_just_pressed())
	scene.right_controller._update_buttons_and_sticks()
	assert(not scene.right_controller.trigger_just_pressed())
	hand.set_input(&"trigger_click", false)
	scene.right_controller._update_buttons_and_sticks()
	assert(scene.right_controller.trigger_just_released())
	# A long hold recenters once, without pausing; menu-state taps are ignored.
	var options := InputEventJoypadButton.new()
	options.button_index = JOY_BUTTON_START
	options.pressed = true
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	assert(Input.is_joy_button_pressed(0, JOY_BUTTON_START))
	origin.position += Vector3(1, -0.4, 0)
	var off_center := origin.transform
	scene._update_psvr_recenter(0.4)
	assert(origin.transform.is_equal_approx(off_center))
	scene._update_psvr_recenter(0.7)
	assert(camera.global_position.is_equal_approx(Vector3(0, 1.8, 1)), "Long hold must restore Y as well as X/Z")
	origin.position.x += 0.3
	off_center = origin.transform
	scene._update_psvr_recenter(2.0)
	assert(origin.transform.is_equal_approx(off_center))
	options.pressed = false
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.0)
	assert(scene.gamestate == scene.gamestate_mapselection)
	hand.set_input(&"menu_button", true)
	scene._update_psvr_recenter(1.1)
	assert(abs(camera.global_position.x) < 0.0001, "Move Start/Options must also recenter")
	hand.set_input(&"menu_button", false)
	scene._update_psvr_recenter(0.0)
	# Tap Options pauses, preserves playback position, and resumes via the existing countdown.
	var song: Variant = scene.menu._all_songs[0]
	var map: Variant = load("res://game/Map.gd")
	map.current_info = song
	map.current_difficulty = song.difficulty_beatmaps[0]
	scene.song_player.stream = AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(song.filepath + song.song_filename))
	scene.song_player.play(2.0)
	scene._transition_game_state(scene.gamestate_playing)
	options.pressed = true
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.1)
	assert(scene.gamestate == scene.gamestate_playing)
	options.pressed = false
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.0)
	assert(scene.gamestate == scene.gamestate_paused and scene.pause_menu.visible)
	assert(not scene.song_player.playing and root.get_node("Scoreboard").paused)
	var paused_at: float = scene.pause_position
	assert(paused_at >= 2.0)
	options.pressed = true
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(1.1)
	options.pressed = false
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.0)
	assert(scene.gamestate == scene.gamestate_paused and scene.pause_menu.visible, "Hold must not resume")
	for tap in 2:
		options.pressed = true
		Input.parse_input_event(options)
		Input.flush_buffered_events()
		scene._update_psvr_recenter(0.1)
		options.pressed = false
		Input.parse_input_event(options)
		Input.flush_buffered_events()
		scene._update_psvr_recenter(0.0)
	assert(scene.pause_countdown.visible and not scene.pause_menu.visible)
	await create_timer(2.0).timeout
	assert(scene.gamestate == scene.gamestate_playing and scene.song_player.playing)
	assert(scene.song_player.get_playback_position() >= paused_at)
	head.invalidate_pose(&"default")
	options.pressed = true
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.1)
	options.pressed = false
	Input.parse_input_event(options)
	Input.flush_buffered_events()
	scene._update_psvr_recenter(0.0)
	assert(scene.gamestate == scene.gamestate_paused, "Pause must work even with lost head tracking")
	scene.pause_menu.ui_control.mainmenu_button.emit()
	assert(scene.gamestate == scene.gamestate_mapselection and not scene.pause_menu.visible)
	hand.set_input(&"menu_button", true)
	origin.position.x += 0.3
	off_center = origin.transform
	scene._update_psvr_recenter(2.0)
	assert(origin.transform.is_equal_approx(off_center), "Lost head tracking must not recenter")
	XRServer.remove_tracker(hand)
	scene.right_controller._physics_process(0.0)
	assert(not scene.right_controller.trigger_pressed() and not scene.right_controller.ax_pressed())
	XRServer.remove_tracker(head)
	scene.process_mode = Node.PROCESS_MODE_INHERIT
