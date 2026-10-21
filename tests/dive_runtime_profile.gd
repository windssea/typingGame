extends SceneTree

func _initialize() -> void: sample.call_deferred()
func percentile(values: Array[float], fraction: float) -> float:
	var sorted_values:=values.duplicate();sorted_values.sort()
	return sorted_values[clampi(ceili(sorted_values.size()*fraction)-1,0,sorted_values.size()-1)]
func sample() -> void:
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.ends_with(".pck"): assert(ProjectSettings.load_resource_pack(arg,false))
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var path: String="user://dive-profile-%d.json"%Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.lesson_index=5;app.start_game("submarine","challenge")
	var run: AdventureRun=app.run
	var arena: AdventureArena=app.layer.find_children("*","AdventureArena",true,false)[0]
	run.spawn_clock=999
	for i in range(3):
		var target: Dictionary=run.targets[i];target.id=[0,5,3][i]
		target.position=Vector2(700+i*200,180+i*165);target.speed=0
		DiveTactics.configure(target,0)
	for i in range(240):
		run.hp=100
		if is_instance_valid(app.overlay):app.close_modal()
		run.paused=false
		await process_frame
	var elapsed: Array[float]=[];var cpu: Array[float]=[];var draws: Array[float]=[]
	var start:=Time.get_ticks_usec();var previous:=start;var simulation_start: float=run.elapsed
	for i in range(180):
		run.hp=100
		if is_instance_valid(app.overlay):app.close_modal()
		run.paused=false
		if i in [0,60,120]:
			run.launch_enemy_torpedo(run.targets[0]);arena.record_impact(Vector2(950,345),2,PlayTheme.SKY)
		await process_frame
		var now:=Time.get_ticks_usec();elapsed.append((now-previous)/1000.0);previous=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var report: Dictionary={"backend":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"samples":180,"fps":180.0/((Time.get_ticks_usec()-start)/1000000.0),"frame_p50_ms":percentile(elapsed,.5),"frame_p95_ms":percentile(elapsed,.95),"process_p95_ms":percentile(cpu,.95),"draw_calls_p95":percentile(draws,.95),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"native_vfx":arena.native_vfx.snapshot(),"scope":"local native desktop, three entered targets, hostile torpedoes and contact effects; no claim for mobile/browser or all hardware"}
	var destination: String="res://build/v23-performance.json"
	for arg in args:
		if arg.ends_with(".json"): destination=arg
	if not args.is_empty(): report.scope="exported release resources, local native desktop; not a browser/mobile or all-hardware benchmark"
	report.active_seconds=run.elapsed-simulation_start
	assert(not run.paused and not run.done and report.active_seconds>2.0,"profile must sample a running game, not a focus-loss pause")
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	quit()
