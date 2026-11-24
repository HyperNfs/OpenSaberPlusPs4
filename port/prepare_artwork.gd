extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: --script port/prepare_artwork.gd -- PROJECT OUTPUT")
		quit(1)
		return
	var icon := Image.load_from_file(args[0] + "/icon.png")
	assert(icon != null and not icon.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(args[1]) == OK)
	icon.convert(Image.FORMAT_RGBA8)
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	assert(icon.save_png(args[1] + "/icon0.png") == OK)
	icon.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var save_icon := Image.create(228, 128, false, Image.FORMAT_RGBA8)
	save_icon.fill(Color.BLACK)
	save_icon.blit_rect(icon, Rect2i(0, 0, 128, 128), Vector2i(50, 0))
	assert(save_icon.save_png(args[1] + "/save_data.png") == OK)
	# Replace old shell artwork with opaque black too, rather than retaining cached pic1.
	var background := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	background.fill(Color.BLACK)
	assert(background.save_png(args[1] + "/pic1.png") == OK)
	print("PS4_ARTWORK PASS: supplied icon retained, opaque black shell background, no splash artwork")
	quit(0)
