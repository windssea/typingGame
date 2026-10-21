extends SceneTree

# Focus and feedback must never reflow another target's readable word.
var checks := 0
var failures := 0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(description)
func exercise() -> void:
	var arena := GameArena.new()
	arena.size = Vector2(1360,630)
	arena.run = GameRun.new()
	arena.run.setup("rain",GameContent.lessons()[5],1,42)
	arena.run.targets.clear()
	var candidates: Array[Dictionary] = []
	for i in range(3):
		var target := {"id":i,"word":["information","flamingo","cat"][i],"typed":0,"position":Vector2(220+i*380,310)}
		arena.run.targets.append(target)
		candidates.append({"target":target,"center":target.position-Vector2(0,100)})
	var actors: Array[Rect2] = []
	for target in arena.run.targets: actors.append(Rect2(target.position-Vector2(35,35),Vector2(70,70)))
	arena.run.locked = 0
	arena.layout_labels(candidates,actors)
	var before := arena.label_rects.duplicate()
	for selected in [1,2,0,2,1]:
		arena.run.locked = selected
		arena.error_pulse = .24
		arena.key_pulse = .22
		arena.layout_labels(candidates,actors)
		check(arena.label_rects==before,"selection and key feedback preserve all target positions")
	var old: Rect2 = arena.label_rects[1]
	candidates[1].center += Vector2(2,1)
	arena.layout_labels(candidates,actors)
	check(arena.label_rects[1].position.is_equal_approx(old.position+Vector2(2,1)),"word follows its actor with the same relative anchor")
	var moved := arena.label_rects.duplicate()
	for i in range(10):
		arena.layout_labels(candidates,actors)
		check(arena.label_rects==moved,"repeated layout cannot alternate between left and right slots")
	# A crowded initial encounter still needs collision-free, repeatable placement.
	candidates[1].center = candidates[0].center+Vector2(20,0)
	arena.layout_labels(candidates,actors)
	check(not arena.label_rects[0].intersects(arena.label_rects[1]),"stable placement still avoids overlapping words")
	var crowded := arena.label_rects.duplicate()
	for i in range(10):
		arena.layout_labels(candidates,actors)
		check(arena.label_rects==crowded,"crowded labels retain their chosen side")
	arena.free()
	print("PROMPT STABILITY: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
