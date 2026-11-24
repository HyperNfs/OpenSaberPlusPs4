extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var effect: Variant = (load("res://game/BeepCube/BeepCube_SliceParticles.tscn") as PackedScene).instantiate()
	root.add_child(effect)
	assert(not effect.visible and not effect.c1.emitting, "Pooled/reset slice particles must stay stopped")
	for i in range(2):
		effect.fire()
		assert(effect.visible and effect.c1.emitting, "A cut must start/restart its one-shot burst")
		effect.reset()
		assert(not effect.visible and not effect.c1.emitting, "Reset must not restart the GPU emitter")
	effect.queue_free()
	await process_frame
	print("SLICE_PARTICLES_TEST PASS: idle/reset emitters stopped; consecutive cuts restart correctly")
	quit(0)
