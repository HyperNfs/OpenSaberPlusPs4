extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	# Load game-typed checks after autoload singletons have been registered.
	var checks: Variant = load("/source/port/tests/custom_map_checks.gd").new()
	root.add_child(checks)
