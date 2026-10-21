extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func border_safe(image: Image) -> bool:
	for x in range(image.get_width()):
		for edge in range(3):
			if image.get_pixel(x,edge).a>.1 or image.get_pixel(x,image.get_height()-1-edge).a>.1: return false
	for y in range(image.get_height()):
		for edge in range(3):
			if image.get_pixel(edge,y).a>.1 or image.get_pixel(image.get_width()-1-edge,y).a>.1: return false
	return true
func exercise() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var profile: String="user://dive-assets-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.set_process(false);app.lesson_index=5;app.start_game("submarine","challenge")
	var arena: AdventureArena=app.layer.find_children("*","AdventureArena",true,false)[0]
	arena.set_process(false);arena.native_vfx.set_process(false)
	for library in [arena.dive.scout,arena.dive.armored]:
		for state in ["idle","alert","hit"]:
			check(library.clips.has(state),"independent generated mechanical action is available")
			var frames: SpriteFrames=library.clips[state]
			check(frames.get_animation_speed(state)==24,"native source frame rate is retained")
			for frame in range(frames.get_frame_count(state)):
				var texture: Texture2D=frames.get_frame_texture(state,frame)
				check(texture.get_size()==Vector2(384,384),"each submarine pose has an HD canvas")
				check(border_safe(texture.get_image()),"all fins, propellers and hulls stay within transparent pose borders")
	for id in ["supply_pod","friendly_torpedo","enemy_torpedo","fish_school"]:
		var texture: Texture2D=arena.art.sprites[id]
		check(texture.get_width()>300 and texture.get_height()>300,"gameplay prop is sourced at high definition: "+id)
		check(border_safe(texture.get_image()),"manual source region does not clip a generated prop: "+id)
	var run: AdventureRun=app.run
	var vfx: EngineVfx=arena.native_vfx
	vfx._process(.01)
	check(vfx.dive_wakes.size()==4 and vfx.dive_lamps.size()==3,"wake and signal nodes have fixed bounds")
	var target: Dictionary=run.targets[0]
	target.position=Vector2(700,180);target.intent="charging"
	vfx._process(.01)
	check(vfx.dive_wakes.filter(func(s):return s.emitter.emitting).size()==2,"only player and entered enemy produce native bubble wakes")
	check(vfx.dive_lamps[0].enabled and vfx.dive_lamps[0].range_item_cull_mask==2,"charging lamp lights scenery without illuminating letters")
	var input_glow: float=arena.key_pulse
	run.launch_enemy_torpedo(target);vfx._process(.1)
	check(arena.key_pulse==input_glow,"enemy shooting cannot imitate accepted keyboard feedback")
	check(vfx.trails.any(func(s):return not s.shot.is_empty() and s.shot.kind=="enemy_torpedo" and s.emitter.emitting),"hostile projectile retains its actual native flight trail")
	run.paused=true;var clock: float=vfx.clock;vfx._process(.5)
	check(vfx.clock==clock and vfx.dive_wakes[0].emitter.speed_scale==0,"pause freezes wake simulation and lighting clock")
	arena.reduced_motion=true;vfx._process(.1)
	check(vfx.dive_wakes.all(func(s):return not s.emitter.emitting) and vfx.dive_lamps.all(func(l):return not l.enabled),"reduced motion disables moving wakes and flashing warning lamps")
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix):DirAccess.remove_absolute(profile+suffix)
	print("DIVE ASSETS AND VFX: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
