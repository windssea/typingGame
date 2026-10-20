extends SceneTree

# Bounded on-device sample; never extrapolated to mobile or all browsers.
func _initialize() -> void: sample.call_deferred()
func percentile(values: Array[float], fraction: float) -> float:
	var ordered:=values.duplicate();ordered.sort()
	return ordered[clampi(ceili(ordered.size()*fraction)-1,0,ordered.size()-1)]
func sample() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var save_path: String="user://art-profile-%d.json" % Time.get_ticks_usec()
	app.store.path=save_path;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.lesson_index=6
	var report: Dictionary={"backend":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"window":[root.size.x,root.size.y],"modes":[]}
	for definition in GameContent.modes():
		app.start_game(definition.id)
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		if app.run is CastleRun:
			app.run.wave=5;app.run.gold=1000
			for i in range(3): app.run.build_tower(i,["fire","ice","storm"][i])
			app.run.begin_wave();app.run.spawn_clock=1000;app.run.energy=20
			for kind in ["guard","shaman","bomber","wolf","goblin","guard","goblin"]:
				var t: Dictionary=app.run.spawn_enemy(kind);t.health=10000;t.max_health=10000
		elif definition.id=="rain":
			for i in range(5): app.run.spawn_target()
		# At a 144 Hz desktop, 120 frames are shorter than the monitor's update window.
		for i in range(240):
			app.run.paused=false
			if is_instance_valid(app.overlay): app.close_modal()
			await process_frame
		var frames: Array[float]=[];var cpu: Array[float]=[];var draws: Array[float]=[]
		var start:=Time.get_ticks_usec();var previous:=start
		for i in range(150):
			app.run.paused=false
			if is_instance_valid(app.overlay): app.close_modal()
			if i%15==0:
				arena.juice.burst(Vector2(520,400),PlayTheme.YELLOW,3,"confetti")
				var target: Dictionary=app.run.recommended_target()
				if not target.is_empty(): app.run.type_character(str(target.word).substr(target.typed,1))
			await process_frame
			var now:=Time.get_ticks_usec()
			frames.append((now-previous)/1000.0);previous=now
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var record: Dictionary={"mode":definition.id,"fps":150.0/((Time.get_ticks_usec()-start)/1000000.0),"frame_p50_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"engine_process_p95_ms":percentile(cpu,.95),"draw_calls_p95":percentile(draws,.95),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"particles":arena.juice.particles.size()}
		report.modes.append(record);print(JSON.stringify(record))
	var suffix: String="after" if "--after" in OS.get_cmdline_user_args() else "before"
	var version: String="v18" if "--v18" in OS.get_cmdline_user_args() else "v17"
	FileAccess.open("res://build/"+version+"-performance-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free();await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit()
