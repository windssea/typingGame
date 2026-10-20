class_name WebGameProbe
extends Node

# Read-only observation for browser regression runs; never supplies gameplay commands.
# Enabled only by ?qa=1, disabled for normal player sessions.
var app: Control
var countdown := 0.0

func _process(delta: float) -> void:
	countdown -= delta
	if countdown>0 or not is_instance_valid(app):
		return
	countdown = 0.08
	var value := {"page":app.page,"lesson":app.lesson_index,"profile":{"xp":app.store.data.xp,"completed":app.store.data.completed,"records":app.store.data.records},"viewport":[app.get_viewport_rect().size.x,app.get_viewport_rect().size.y],"buttons":[],"focus":"","overlay":is_instance_valid(app.overlay)}
	var focused := app.get_viewport().gui_get_focus_owner()
	if focused is Button:
		value.focus = focused.text
		value.focus_name = str(focused.name)
	for button in app.layer.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and not button.is_queued_for_deletion():
			var rect: Rect2 = button.get_global_rect()
			value.buttons.append({"name":str(button.name),"text":button.text,"disabled":button.disabled,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	if app.run!=null:
		var run: GameRun = app.run
		value.run = {"mode":run.mode,"context":run.context,"hp":run.hp,"kills":run.kills,"score":run.score,"correct":run.correct,"attempts":run.attempts,"elapsed":run.elapsed,"done":run.done,"won":run.won,"paused":run.paused,"targets":[]}
		value.run.merge({"difficulty":run.difficulty,"rank":run.challenge_rank})
		value.run.merge({"vocabulary_topic":run.lesson.get("vocabulary_topic","basic"),"pool_size":run.lesson.words.size(),"last_word":run.last_word,"last_meaning":run.last_meaning})
		var recommended := run.recommended_target()
		value.run.recommended = recommended.get("id",-1)
		for arena in app.layer.find_children("*","Control",true,false):
			if arena is GameArena:
				value.run.merge({"particles":arena.juice.particles.size(),"motion_clock":arena.clock,"reduced_motion":arena.reduced_motion})
		for target in run.targets:
			value.run.targets.append({"id":target.id,"word":target.word,"typed":target.typed,"position":[target.position.x,target.position.y],"health":target.get("health",1),"kind":str(target.kind)})
		if run is CastleRun:
			value.run.merge({"phase":run.phase,"gold":run.gold,"wave":run.wave,"towers":run.towers.size(),"words_completed":run.words_completed})
		if run is BridgeRun:
			value.run.merge({"travel":run.travel,"lit_beacons":int(run.kills/6),"goal":18})
		if run is ArcadeRun:
			value.run.merge({"distance":run.distance,"rival":run.rival,"shield":run.shield,"enemy_hp":run.enemy_hp})
			value.run.merge({"skill_charge":run.skill_charge,"skill_time":run.skill_time,"skill_uses":run.skill_uses,"goal":run.goal})
	JavaScriptBridge.eval("window.keyboundGame = "+JSON.stringify(value)+"; document.documentElement.setAttribute('data-keybound-state',JSON.stringify(window.keyboundGame));",true)
