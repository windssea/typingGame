extends SceneTree
var checks:=0
var failures:=0
var app:Control
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:exercise.call_deferred()
func exercise()->void:
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	var profile:String="user://home-scene-v25-%d.json"%Time.get_ticks_usec()
	app.store.path=profile;app.store.data.settings.sound=false
	root.add_child(app)
	for i in range(8):await process_frame
	var training:HomeGate=app.layer.find_child("TrainingGate",true,false)
	var challenge:HomeGate=app.layer.find_child("ChallengeGate",true,false)
	check(training.training and not challenge.training,"two entrance scenes have distinct roles")
	check(training.hero.sprite_frames!=challenge.hero.sprite_frames,"training robot and challenge knight are different real animations")
	check(training.hero.sprite_frames.get_animation_speed(training.hero.animation)==24,"coach retains reviewed native24fps")
	check(challenge.hero.sprite_frames.get_animation_speed("idle")==24,"knight retains reviewed native24fps")
	check(training.hero.is_playing() and challenge.hero.is_playing(),"both real characters animate")
	check(training.hero.animation=="cheer","keyboard selection triggers a real coach gesture")
	check(training.motes.emitting and challenge.motes.emitting,"both entrance props have native particle emitters")
	check(training.lamp.range_item_cull_mask==4,"portal light excludes text and buttons")
	var launch:Button=app.layer.find_child("StartTraining",true,false)
	check(launch.has_focus(),"training retains initial keyboard focus")
	check(launch.size.x/launch.size.y<4.5,"main action has a physical proportion instead of a full-column pill")
	var old_setting:bool=app.store.data.settings.sound
	app.toggle_sound()
	check(app.sound_button.text=="声音开" and app.sound_button.size.x<=110,"sound change retains short toolbar text and width")
	app.store.data.settings.sound=old_setting
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/v25-home-motion-a.png")
	await create_timer(1.9).timeout
	check(training.hero.animation=="idle" and training.hero.is_playing(),"focus cheer returns to native idle without getting stuck")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://build/v25-home-motion-b.png")
	app.store.data.settings.reduced_motion=true;app.show_home()
	for i in range(5):await process_frame
	training=app.layer.find_child("TrainingGate",true,false)
	var before:=training.clock
	training._process(.4)
	check(is_equal_approx(before,training.clock) and not training.hero.is_playing() and not training.motes.emitting,"reduced motion freezes character and native particles")
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix):DirAccess.remove_absolute(profile+suffix)
	print("HOME SCENE: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
