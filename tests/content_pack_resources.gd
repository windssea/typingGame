extends SceneTree

# Run against the exported bootstrap, in an empty project directory. No source assets
# are available, so a missing dependency cannot be hidden by another game's pack.
var checks:=0
func _initialize() -> void: exercise.call_deferred()
func require(value: bool, description: String) -> void:
	checks+=1
	if not value: push_error(description);quit(2)

func exercise() -> void:
	var args:=OS.get_cmdline_user_args()
	var mode: String=args[0]
	for path in args.slice(1):require(ProjectSettings.load_resource_pack(path,false),"mount "+path)
	var run: GameRun=BridgeRun.new() if mode=="dojo" else CastleRun.new() if mode=="castle" else AdventureRun.new() if mode in AdventureRun.MODES else ArcadeRun.new() if mode in ArcadeRun.MODES else GameRun.new()
	run.setup(mode,GameContent.lessons()[0],1)
	var arena: GameArena=BridgeArena.new() if mode=="dojo" else CastleArena.new() if mode=="castle" else AdventureArena.new() if mode in AdventureRun.MODES else ArcadeArena.new() if mode in ArcadeRun.MODES else GameArena.new()
	arena.run=run;arena.size=Vector2(1360,640)
	root.add_child(arena)
	await process_frame
	require(arena.art.background!=null,"background: "+mode)
	require(not arena.art.sprites.is_empty(),"sprites: "+mode)
	if mode=="restaurant":
		for state in ["idle","stir","toss","serve","walk"]:
			require(arena.kitchen.clips.texture(state,.25)!=null,"exported kitchen action: "+state)
		require(arena.art.sprites.has("dessert"),"exported comfort dessert")
	if mode=="submarine":
		for library in [arena.dive.scout,arena.dive.armored]:
			for state in ["idle","alert","hit"]: require(library.texture(state,.2)!=null,"exported submarine native action: "+state)
		for prop in ["supply_pod","friendly_torpedo","enemy_torpedo","fish_school"]: require(arena.art.sprites.has(prop),"exported underwater prop: "+prop)
	if mode=="racing":
		for state in ["idle","boost"]: require(arena.motion.texture(state,.2)!=null,"exported player kart action: "+state)
		require(arena.rival_motion.texture("idle",.2)!=null,"exported rival driver action")
	if run is CastleRun:
		run.wave=6
		arena.prepare_creatures()
		require(arena.creature_clips.size()==5,"all late-wave castle creatures")
	for i in range(3):await process_frame
	arena.queue_free();await process_frame
	print("PACK ",mode,": ",checks," checks; 0 failures")
	quit()
