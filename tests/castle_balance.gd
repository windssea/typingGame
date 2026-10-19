extends SceneTree

# Deterministic automated pilots provide tuning evidence, not human usability results.
func _initialize() -> void:
	for rate in [30.0,45.0]:
		var run := CastleRun.new()
		run.setup("castle",GameContent.lessons()[6],1.0,123)
		run.build_tower(0,"ice")
		var input_timer := 0.0
		var ticks := 0
		while not run.done and ticks<20000:
			ticks+=1
			if run.phase=="build":
				if run.hp < run.max_hp-30:
					run.repair()
				run.purchase_upgrade("power")
				if run.wave>=3:
					run.build_tower(1,"fire")
				run.begin_wave()
			run.step(0.1)
			input_timer-=0.1
			if input_timer<=0 and not run.targets.is_empty():
				input_timer+=60.0/(rate*5)
				var target := run.target_by_id(run.locked)
				if target.is_empty():
					var ordered := run.targets.duplicate()
					ordered.sort_custom(func(a,b): return run.priority(a)<run.priority(b))
					target=ordered[0]
				run.type_character(str(target.word).substr(target.typed,1))
			elif run.targets.is_empty():
				input_timer=0
		print("PILOT %.0f WPM: won=%s wave=%d hp=%d kills=%d bosses=%d duration=%.1fs" % [rate,run.won,run.wave,run.hp,run.kills,run.bosses_defeated,run.elapsed])
	quit()
