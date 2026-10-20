extends SceneTree

# Requires a real renderer: checks the pixels, not just shader property values.
var checks:=0
var failures:=0
func _initialize() -> void: exercise.call_deferred()
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error("FAIL: "+message)
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a: Image,b: Image,rect: Rect2i) -> int:
	var changed:=0
	var clipped:=rect.intersection(Rect2i(Vector2i.ZERO,a.get_size()))
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): changed+=1
	return changed
func exercise() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate()
	var path: String="user://vfx-pixels-%d.json"%Time.get_ticks_usec()
	app.store.path=path;app.store.data.settings.sound=false
	root.add_child(app);await process_frame
	app.lesson_index=6
	var records:=[]
	for mode in ["balloons","castle","submarine"]:
		app.start_game(mode)
		if app.run is CastleRun: app.run.begin_wave();app.run.spawn_enemy("guard")
		var arena: GameArena=app.layer.find_children("*","GameArena",true,false)[0]
		app.run.paused=true;app.close_modal()
		arena.set_process(false)
		var fx: EngineVfx=arena.native_vfx
		fx.set_process(false);fx.ambient.visible=false
		for p in fx.bursts: p.visible=false
		for p in fx.auras: p.visible=false
		await process_frame
		fx.apply_mask()
		var label: Rect2=arena.label_rects.values()[0]
		var transform:=root.get_final_transform()*arena.get_global_transform()
		var inside:=Rect2i(transform*label.grow(-5))
		var around:=Rect2i(transform*label.grow(100))
		var before: Image=await capture()
		fx.wave_at(label.get_center(),3,Color(1,.1,.1),0)
		fx.waves[0].node.material.set_shader_parameter("progress",.3)
		var after: Image=await capture()
		var protected_changes:=difference(before,after,inside)
		var visible_changes:=difference(before,after,around)
		check(protected_changes==0,"rendered wave leaves word pixels untouched: "+mode)
		check(visible_changes>20,"native shader actually draws outside the mask: "+mode)
		for slot in fx.waves: slot.node.visible=false
		before=await capture()
		var light_point:=Vector2(arena.size.x*.5,arena.size.y*.6)
		fx.light_at(light_point,Color(1,.15,.05),1.0,3.0)
		after=await capture()
		var lit_changes:=difference(before,after,Rect2i(transform*Rect2(light_point-Vector2(90,90),Vector2(180,180))))
		check(lit_changes>100,"PointLight2D really illuminates the scenery: "+mode)
		check(difference(before,after,inside)==0,"lighting leaves opaque target text unchanged: "+mode)
		records.append({"mode":mode,"word_pixels_changed":protected_changes,"wave_pixels_changed":visible_changes,"lit_pixels_changed":lit_changes})
	FileAccess.open("res://build/v19-render-validation.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("VFX RENDER: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
