class_name BridgeRun
extends GameRun

signal bridge_repaired(tile: int)
const GOAL := 18
var travel := 0.0
var arrival_time := 0.0

func allows_typing() -> bool:
	return kills<GOAL

func on_word_completed(target: Dictionary) -> void:
	defeat(target,false)
	bridge_repaired.emit(kills)
	if kills<GOAL:
		spawn_target()

func step(delta: float) -> void:
	if paused or done:
		return
	elapsed += delta
	# Repaired planks are the actual reachable path, not a decorative progress bar.
	travel = move_toward(travel,float(kills),delta*8*difficulty)
	if kills==GOAL and is_equal_approx(travel,GOAL):
		arrival_time += delta
		if arrival_time>=1.0:
			finish(true)
