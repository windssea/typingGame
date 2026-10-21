class_name EngineVfx
extends Node2D

# Native, bounded presentation nodes. Simulation and input never wait for these effects.
const BURST_LIMIT := 10
const TRAIL_LIMIT := 6
const LIGHT_LIMIT := 5
const WAVE_LIMIT := 6
const PARTICLE_SHADER = preload("res://shaders/native_particles.gdshader")
const WAVE_SHADER = preload("res://shaders/impact_wave.gdshader")
var arena: GameArena
var bursts: Array[CPUParticles2D] = []
var trails: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var ambient: CPUParticles2D
var particle_material: ShaderMaterial
var dot: GradientTexture2D
var light_texture: GradientTexture2D
var cursor := 0
var wave_cursor := 0
var light_cursor := 0
var clock := 0.0
var event_count := 0
var launch_count := 0
var protected_regions: Array[Rect2] = []
var previous_mask := PackedVector4Array()
var paused := false
var reduced := false
var shake := Vector2.ZERO
var shake_tween: Tween
var auras: Array[CPUParticles2D] = []
var meteor_trails: Array[Dictionary] = []
var stoves: Array[Dictionary] = []
var dive_wakes: Array[Dictionary] = []
var dive_lamps: Array[PointLight2D] = []
var racing_exhaust: Array[CPUParticles2D] = []
var nitro_light: PointLight2D

func radial_texture(extent: int, for_light := false) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,.22,.65,1.0])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.8),Color(1,1,1,.16),Color(1,1,1,0)]) if not for_light else PackedColorArray([Color.WHITE,Color(.65,.65,.65),Color(.08,.08,.08),Color.BLACK])
	var texture := GradientTexture2D.new()
	texture.width=extent;texture.height=extent;texture.gradient=gradient
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	return texture

func _ready() -> void:
	name="EngineVfx"
	process_priority=10
	dot=radial_texture(32)
	light_texture=radial_texture(128,true)
	particle_material=ShaderMaterial.new();particle_material.shader=PARTICLE_SHADER
	for i in range(BURST_LIMIT): bursts.append(make_emitter("Impact%02d"%i))
	for i in range(TRAIL_LIMIT):
		var emitter:=make_emitter("Flight%02d"%i)
		emitter.one_shot=false;emitter.amount=20;emitter.lifetime=.32
		trails.append({"emitter":emitter,"shot":{},"tail":0.0})
	if arena.run.mode=="rain":
		for i in range(12):
			var emitter:=make_emitter("MeteorTail%02d"%i)
			emitter.one_shot=false;emitter.explosiveness=0;emitter.amount=72;emitter.lifetime=.95
			emitter.preprocess=.15
			var glow:=ShaderMaterial.new();glow.shader=preload("res://shaders/meteor_particles.gdshader")
			emitter.material=glow
			emitter.spread=11;emitter.gravity=Vector2.ZERO
			emitter.initial_velocity_min=140;emitter.initial_velocity_max=240
			emitter.scale_amount_min=.15;emitter.scale_amount_max=.55
			var ramp:=Gradient.new();ramp.offsets=PackedFloat32Array([0,.12,.45,1])
			ramp.colors=PackedColorArray([Color(1,1,.8,.95),Color(.55,.96,1,.9),Color(.12,.65,1,.5),Color(.08,.25,1,0)])
			emitter.color_ramp=ramp
			meteor_trails.append({"emitter":emitter,"target":-1,"tail":0.0})
	for i in range(LIGHT_LIMIT):
		var light:=PointLight2D.new()
		light.name="ContactLight%02d"%i;light.texture=light_texture
		light.range_item_cull_mask=2;light.energy=0;light.enabled=false
		light.shadow_enabled=false
		add_child(light)
		lights.append({"node":light,"tween":null})
	for i in range(WAVE_LIMIT):
		var sprite:=Sprite2D.new();sprite.name="ImpactWave%02d"%i
		sprite.texture=dot;sprite.visible=false
		var shader:=ShaderMaterial.new();shader.shader=WAVE_SHADER;sprite.material=shader
		add_child(sprite);waves.append({"node":sprite,"tween":null})
	ambient=make_emitter("Atmosphere")
	ambient.one_shot=false;ambient.amount=20;ambient.lifetime=3.6;ambient.explosiveness=0
	ambient.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient.emission_rect_extents=Vector2(arena.size.x*.45,20)
	ambient.position=Vector2(arena.size.x*.5,arena.size.y-20)
	ambient.direction=Vector2.UP;ambient.spread=28
	ambient.initial_velocity_min=14;ambient.initial_velocity_max=38;ambient.gravity=Vector2.ZERO
	ambient.scale_amount_min=.10;ambient.scale_amount_max=.24
	ambient.color=Color(.7,.91,1,.38) if arena.run.mode in ["submarine","bubbles","rain","aliens"] else Color(1,.9,.5,.35)
	ambient.emitting=not arena.reduced_motion
	if arena.run.mode=="racing":
		ambient.emitting=false
		for i in range(3):
			var exhaust:=make_emitter("KartExhaust%d"%i)
			exhaust.one_shot=false;exhaust.explosiveness=0;exhaust.local_coords=false
			exhaust.amount=24 if i<2 else 40;exhaust.lifetime=.42 if i<2 else .26
			exhaust.direction=Vector2.LEFT;exhaust.spread=15 if i<2 else 5
			exhaust.gravity=Vector2.ZERO;exhaust.initial_velocity_min=45 if i<2 else 180
			exhaust.initial_velocity_max=80 if i<2 else 270
			exhaust.scale_amount_min=.10 if i<2 else .18;exhaust.scale_amount_max=.22 if i<2 else .36
			exhaust.color=Color(.81,.89,.93,.30) if i<2 else Color(.25,.85,1,.8)
			racing_exhaust.append(exhaust)
		nitro_light=PointLight2D.new();nitro_light.name="NitroLight";nitro_light.texture=light_texture
		nitro_light.color=Color("7eeaff");nitro_light.range_item_cull_mask=2
		nitro_light.texture_scale=.6;nitro_light.enabled=false;add_child(nitro_light)
	if arena.run.mode in ["balloons","moles","royal","castle"]:
		ambient.position.y=24;ambient.direction=Vector2(.3,1)
		ambient.gravity=Vector2(4,8);ambient.color=Color(.96,.83,.42,.32)
	if arena.run.mode=="restaurant":
		# A quiet kitchen at rest. Steam and fire belong only to cooking orders.
		ambient.amount=6;ambient.position=Vector2(680,100)
		ambient.emission_rect_extents=Vector2(600,1);ambient.color=Color(1,.97,.88,.12)
		for lane in range(3):
			var steam:=make_emitter("StoveSteam%d"%lane)
			steam.one_shot=false;steam.explosiveness=0;steam.amount=22;steam.lifetime=.9
			steam.position=Vector2(240+lane*440,378);steam.direction=Vector2.UP
			steam.spread=22;steam.gravity=Vector2(0,-24)
			steam.initial_velocity_min=18;steam.initial_velocity_max=45
			steam.scale_amount_min=.3;steam.scale_amount_max=.75
			steam.color=Color(1,.96,.87,.33)
			var fire:=make_emitter("StoveFlame%d"%lane)
			fire.one_shot=false;fire.explosiveness=0;fire.amount=18;fire.lifetime=.32
			fire.position=Vector2(240+lane*440,416);fire.direction=Vector2.UP
			fire.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			fire.emission_rect_extents=Vector2(29,1);fire.spread=12;fire.gravity=Vector2(0,-30)
			fire.initial_velocity_min=12;fire.initial_velocity_max=35
			fire.scale_amount_min=.12;fire.scale_amount_max=.27;fire.color=Color("ffb047")
			var stove_light:=PointLight2D.new();stove_light.texture=light_texture
			stove_light.name="StoveLight%d"%lane;stove_light.position=fire.position
			stove_light.range_item_cull_mask=2;stove_light.texture_scale=1.2
			stove_light.color=Color("ffc16b");stove_light.enabled=false
			add_child(stove_light)
			stoves.append({"lane":lane,"steam":steam,"fire":fire,"light":stove_light})
	if arena.run is CastleRun:
		for i in range(CastleRun.PADS.size()):
			var aura:=make_emitter("TowerAura%02d"%i)
			aura.one_shot=false;aura.explosiveness=0;aura.amount=12;aura.lifetime=.7
			aura.direction=Vector2.UP;aura.spread=25;aura.gravity=Vector2(0,-16)
			aura.initial_velocity_min=12;aura.initial_velocity_max=30
			aura.scale_amount_min=.08;aura.scale_amount_max=.18
			aura.position=CastleRun.PADS[i]-Vector2(0,102)
			auras.append(aura)
	if arena.run.mode=="submarine":
		var rim:=Gradient.new()
		rim.offsets=PackedFloat32Array([0,.58,.78,.94,1])
		rim.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.03),Color(1,1,1,.6),Color(1,1,1,.16),Color(1,1,1,0)])
		var bubble:=radial_texture(32);bubble.gradient=rim
		for i in range(4):
			var emitter:=make_emitter("DiveWake%d"%i)
			emitter.texture=bubble;emitter.one_shot=false;emitter.explosiveness=0
			emitter.amount=18;emitter.lifetime=.85;emitter.spread=16;emitter.gravity=Vector2(0,-18)
			emitter.initial_velocity_min=12;emitter.initial_velocity_max=35
			emitter.scale_amount_min=.12;emitter.scale_amount_max=.34;emitter.color=Color(.72,.95,1,.65)
			dive_wakes.append({"emitter":emitter,"entity":-2 if i==0 else -1,"tail":0.0})
		for i in range(3):
			var lamp:=PointLight2D.new();lamp.name="DiveSignal%d"%i
			lamp.texture=light_texture;lamp.color=Color("ffba79");lamp.texture_scale=1.7
			lamp.range_item_cull_mask=2;lamp.shadow_enabled=false;lamp.enabled=false
			add_child(lamp);dive_lamps.append(lamp)
	# PointLight2D affects only scenery (mask 2), never labels, HUD or menu controls.
	arena.backdrop.light_mask=2
	arena.run.projectile_launched.connect(on_launch)
	if arena.run is CastleRun: arena.run.effect.connect(on_castle_effect)
	if arena.run is AdventureRun: arena.run.action.connect(on_action)
	if arena.run is ArcadeRun: arena.run.impact.connect(on_arcade_effect)
	if arena.run is BridgeRun: arena.run.bridge_repaired.connect(func(tile):
		if tile%6==0: emit_at(Vector2(320+tile*46,429),3,"celebrate",PlayTheme.MINT))
	apply_mask()

func make_emitter(label: String) -> CPUParticles2D:
	var emitter:=CPUParticles2D.new()
	emitter.name=label;emitter.emitting=false;emitter.one_shot=true
	emitter.amount=24;emitter.lifetime=.55;emitter.explosiveness=.95
	emitter.local_coords=false;emitter.texture=dot;emitter.material=particle_material
	emitter.direction=Vector2.UP;emitter.spread=180
	emitter.scale_amount_min=.10;emitter.scale_amount_max=.30
	var ramp:=Gradient.new()
	ramp.offsets=PackedFloat32Array([0,.15,.7,1])
	ramp.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,.65),Color(1,1,1,0)])
	emitter.color_ramp=ramp
	var curve:=Curve.new();curve.add_point(Vector2(0,.6));curve.add_point(Vector2(.18,1));curve.add_point(Vector2(1,0))
	emitter.scale_amount_curve=curve
	add_child(emitter)
	return emitter

func impact(point: Vector2, tier: int, tint: Color) -> void:
	var mode:=arena.run.mode
	if mode=="restaurant" and point.y>200: point.y=395
	var kind: String={"balloons":"confetti","moles":"soil","bubbles":"water","submarine":"water","fighter":"slash","royal":"slash","restaurant":"steam","sprint":"speed","dojo":"magic"}.get(mode,"magic")
	emit_at(point,tier,kind,tint)

func emit_at(point: Vector2, tier: int, kind: String, tint: Color) -> void:
	if arena.run.paused: return
	event_count+=1
	tier=clampi(tier,1,3)
	if arena.reduced_motion:
		# A short local confirmation, no moving particles, light flash or shake.
		wave_at(point,1,tint,2,true)
		return
	var emitter:=bursts[cursor%BURST_LIMIT];cursor+=1
	emitter.position=point;emitter.amount=12+tier*6;emitter.lifetime=.4+tier*.08
	emitter.color=tint;emitter.spread=180;emitter.direction=Vector2.UP
	emitter.gravity=Vector2(0,95);emitter.initial_velocity_min=65;emitter.initial_velocity_max=145+tier*35
	emitter.scale_amount_min=.10;emitter.scale_amount_max=.28
	if kind in ["confetti","soil","celebrate"]:
		emitter.spread=75;emitter.gravity=Vector2(0,280)
		emitter.initial_velocity_min=100;emitter.initial_velocity_max=210+tier*25
		emitter.angular_velocity_min=-160;emitter.angular_velocity_max=160
	else:
		emitter.angular_velocity_min=0;emitter.angular_velocity_max=0
	if kind in ["steam","water"]:
		emitter.gravity=Vector2(0,-70);emitter.spread=55
		emitter.initial_velocity_min=25;emitter.initial_velocity_max=90
		emitter.scale_amount_min=.18;emitter.scale_amount_max=.48
	if kind=="ice": emitter.gravity=Vector2(0,110)
	emitter.restart();emitter.emitting=true
	light_at(point,tint,.24 if tier==1 else .42,1.1+tier*.35)
	wave_at(point,tier,tint,1 if kind=="slash" else 2 if kind=="water" else 0)
	if tier>=2: shake_backdrop(tier)

func wave_at(point: Vector2, tier: int, tint: Color, shape: int, quiet := false) -> void:
	var slot:=waves[wave_cursor%WAVE_LIMIT];wave_cursor+=1
	if slot.tween!=null: slot.tween.kill()
	var sprite: Sprite2D=slot.node
	sprite.position=point;sprite.visible=true;sprite.rotation=0
	sprite.scale=Vector2.ONE*(1.5 if quiet else 4+tier*1.2)
	sprite.material.set_shader_parameter("tint",Color(tint,.22 if quiet else .65))
	sprite.material.set_shader_parameter("shape",3 if quiet else shape)
	sprite.material.set_shader_parameter("progress",.7 if quiet else 0.0)
	var tween:=create_tween();tween.pause()
	tween.tween_method(func(value): sprite.material.set_shader_parameter("progress",value),.7 if quiet else 0.0,1.0,.18 if quiet else .32+tier*.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): sprite.visible=false)
	slot.tween=tween

func light_at(point: Vector2, tint: Color, energy: float, extent: float) -> void:
	if arena.reduced_motion: return
	var slot:=lights[light_cursor%LIGHT_LIMIT];light_cursor+=1
	if slot.tween!=null: slot.tween.kill()
	var light: PointLight2D=slot.node
	light.position=point;light.color=tint;light.energy=energy
	light.texture_scale=extent;light.enabled=true
	var tween:=create_tween();tween.pause()
	tween.tween_property(light,"energy",0.0,.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): light.enabled=false)
	slot.tween=tween

func shake_backdrop(tier: int) -> void:
	if shake_tween!=null: shake_tween.kill()
	var strength:=1.7 if tier==2 else 3.0
	shake_tween=create_tween();shake_tween.pause()
	shake_tween.tween_property(self,"shake",Vector2(-strength,strength*.45),.025)
	shake_tween.tween_property(self,"shake",Vector2(strength*.55,-strength*.3),.035)
	shake_tween.tween_property(self,"shake",Vector2.ZERO,.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func on_launch(shot: Dictionary) -> void:
	launch_count+=1
	if arena.reduced_motion: return
	var tint:=Color("92e8ff") if shot.kind in ["ice","torpedo","rescue","interceptor"] else Color("ffac88") if shot.kind=="enemy_torpedo" else Color("ffc178")
	light_at(shot.origin,tint,.3,1.2)
	for slot in trails:
		if slot.shot.is_empty() and slot.tail<=0:
			slot.shot=shot
			var emitter: CPUParticles2D=slot.emitter
			emitter.position=shot.position;emitter.color=tint
			emitter.explosiveness=0;emitter.spread=24;emitter.gravity=Vector2.ZERO
			emitter.initial_velocity_min=24;emitter.initial_velocity_max=65
			emitter.scale_amount_min=.13;emitter.scale_amount_max=.28
			emitter.restart();emitter.emitting=true
			break

func on_castle_effect(kind: String, origin: Vector2, destination: Vector2, _amount: int) -> void:
	if kind in ["fire","ember","ice","storm","build","heal"]:
		var tint: Color={"ice":Color("8feaff"),"storm":Color("c5a3ff"),"heal":Color("91f2bf"),"build":Color("ffe3a0")}.get(kind,Color("ffbd77"))
		emit_at(destination,2 if kind=="storm" else 1,kind,tint)
		if kind=="storm": light_at(origin,tint,.35,1.5)

func on_action(kind: String, point: Vector2) -> void:
	# Impact events already pass through GameArena.record_impact.
	if kind=="skill":
		if arena.run.mode=="restaurant":
			for target in arena.run.targets: emit_at(Vector2(target.position.x,170),1,"celebrate",Color("ffe7a1"))
		elif arena.run.mode=="submarine": emit_at(DiveTactics.PLAYER,2,"water",PlayTheme.SKY)
		else: emit_at(point,3,"celebrate",PlayTheme.SKY)

func on_arcade_effect(kind: String, point: Vector2, _power: int) -> void:
	if kind=="aliens": light_at(Vector2(520,540),PlayTheme.SKY,.35,1.5)
	if kind=="racing": emit_at(arena.track_point(arena.run.distance,0)-Vector2(55,0),1,"speed",PlayTheme.SKY)

func apply_mask() -> void:
	protected_regions=arena.juice.protected_regions.duplicate()
	# Internal game HUD stays steady and readable too.
	if arena.run.mode=="sprint": protected_regions.append(Rect2(540,25,280,105))
	if arena.run.mode=="royal": protected_regions.append(Rect2(0,15,1360,75))
	var packed:=PackedVector4Array()
	var transform:=arena.get_global_transform()
	for rect in protected_regions.slice(0,32):
		var start: Vector2=transform*rect.position
		var end: Vector2=transform*rect.end
		packed.append(Vector4(start.x,start.y,end.x,end.y))
	if packed==previous_mask: return
	previous_mask=packed
	var count:=packed.size()
	packed.resize(32)
	particle_material.set_shader_parameter("protected_rects",packed)
	particle_material.set_shader_parameter("protected_count",count)
	for slot in meteor_trails:
		slot.emitter.material.set_shader_parameter("protected_rects",packed)
		slot.emitter.material.set_shader_parameter("protected_count",count)
	for slot in waves:
		slot.node.material.set_shader_parameter("protected_rects",packed)
		slot.node.material.set_shader_parameter("protected_count",count)

func _process(delta: float) -> void:
	paused=arena.run.paused
	reduced=arena.reduced_motion
	apply_mask()
	for emitter in bursts: emitter.speed_scale=0.0 if paused else 1.0
	ambient.speed_scale=0.0 if paused else 1.0
	ambient.visible=not reduced;ambient.emitting=not reduced and arena.run.mode!="racing"
	if not racing_exhaust.is_empty():
		var moving: bool=arena.run.boost>0
		var nitro: bool=moving and (arena.run.combo>=3 or arena.run.skill_time>0)
		for i in range(racing_exhaust.size()):
			var exhaust:=racing_exhaust[i]
			exhaust.speed_scale=0.0 if paused else 1.0;exhaust.visible=not reduced
			exhaust.position=arena.track_point(arena.visual_rival if i==1 else arena.visual_distance,1 if i==1 else 0)-Vector2(65,0)
			exhaust.emitting=not reduced and not arena.run.done and (nitro if i==2 else moving if i==0 else arena.run.rival<1)
		nitro_light.position=racing_exhaust[2].position
		nitro_light.enabled=nitro and not reduced and not arena.run.done
		nitro_light.energy=.22+.04*sin(clock*18)
	for slot in trails: slot.emitter.speed_scale=0.0 if paused else 1.0
	for slot in meteor_trails:
		slot.emitter.speed_scale=0.0 if paused else 1.0
		slot.emitter.visible=not reduced
		if reduced: slot.emitter.emitting=false
	for slot in dive_wakes:
		slot.emitter.speed_scale=0.0 if paused else 1.0
		slot.emitter.visible=not reduced
		if reduced: slot.emitter.emitting=false
	if not dive_lamps.is_empty():
		var charging: Array=arena.run.targets.filter(func(t):return t.intent=="charging")
		for i in range(dive_lamps.size()):
			dive_lamps[i].enabled=not reduced and i<charging.size()
			if i<charging.size():
				dive_lamps[i].position=charging[i].position-Vector2(68,0)
				dive_lamps[i].energy=.22+.05*sin(clock*6)
	for i in range(auras.size()):
		var emitter:=auras[i]
		emitter.speed_scale=0.0 if paused else 1.0
		emitter.visible=not reduced
		var towers: Array=arena.run.towers.filter(func(t): return t.pad==i)
		emitter.emitting=not reduced and not towers.is_empty()
		if not towers.is_empty():
			emitter.color={"fire":Color("ffb05c"),"ice":Color("92eaff"),"storm":Color("c6a1ff")}[towers[0].kind]
	for stove in stoves:
		var cooking: bool=arena.run.targets.any(func(t): return t.lane==stove.lane and t.cook_left>0)
		for emitter in [stove.steam,stove.fire]:
			emitter.speed_scale=0.0 if paused else 1.0
			emitter.visible=not reduced;emitter.emitting=cooking and not reduced
		stove.light.enabled=cooking and not reduced
		stove.light.energy=.28+sin(clock*23+stove.lane)*.035
	if paused: return
	clock+=delta
	update_meteor_trails(delta)
	update_dive_wakes(delta)
	for slot in waves+lights:
		if slot.tween!=null and slot.tween.is_valid(): slot.tween.custom_step(delta)
	if reduced:
		shake=Vector2.ZERO
		if shake_tween!=null: shake_tween.kill()
		for emitter in bursts: emitter.visible=false;emitter.emitting=false
		for slot in lights: slot.node.enabled=false
	else:
		for emitter in bursts: emitter.visible=true
		if shake_tween!=null and shake_tween.is_valid(): shake_tween.custom_step(delta)
	# Scenery moves at most three reference pixels; words and HUD never move.
	if is_instance_valid(arena.backdrop):
		arena.backdrop.material.set_shader_parameter("impact_offset",-shake/arena.backdrop.size.max(Vector2.ONE))
	for slot in trails:
		var emitter: CPUParticles2D=slot.emitter
		emitter.visible=not reduced
		if not slot.shot.is_empty():
			if (arena.run.projectiles.has(slot.shot) or (arena.run is AdventureRun and arena.run.enemy_shots.has(slot.shot))) and not reduced:
				emitter.position=slot.shot.position
				emitter.direction=(slot.shot.previous-slot.shot.position).normalized()
			else:
				slot.shot={};emitter.emitting=false;slot.tail=emitter.lifetime
		else: slot.tail=maxf(0,slot.tail-delta)

func update_dive_wakes(delta: float) -> void:
	if dive_wakes.is_empty(): return
	for slot in dive_wakes:
		var target:=arena.run.target_by_id(slot.entity)
		var hero: bool=slot.entity==-2
		if not hero and target.is_empty():
			if slot.entity!=-1: slot.entity=-1;slot.tail=.85;slot.emitter.emitting=false
			slot.tail=maxf(0,slot.tail-delta)
			continue
		slot.emitter.position=DiveTactics.PLAYER-Vector2(78,0) if hero else target.position+Vector2(76,8)
		slot.emitter.direction=Vector2.LEFT if hero else Vector2.RIGHT
		slot.emitter.emitting=not reduced
	if reduced: return
	for target in arena.run.targets:
		if target.position.x>1450 or target.intent=="returning" or target.kind=="supply" or dive_wakes.any(func(s): return s.entity==target.id): continue
		for slot in dive_wakes:
			if slot.entity==-1 and slot.tail<=0:
				slot.entity=target.id;slot.emitter.position=target.position+Vector2(76,8)
				slot.emitter.direction=Vector2.RIGHT;slot.emitter.restart();slot.emitter.emitting=true
				break

func update_meteor_trails(delta: float) -> void:
	for slot in meteor_trails:
		var target:=arena.run.target_by_id(slot.target)
		if target.is_empty() or reduced:
			if slot.target!=-1: slot.target=-1;slot.tail=.95;slot.emitter.emitting=false
			slot.tail=maxf(0,slot.tail-delta)
		else:
			slot.emitter.position=target.position
			slot.emitter.direction=-Vector2(target.velocity).normalized()
			slot.emitter.emitting=true
	if reduced: return
	for target in arena.run.targets:
		if arena.run.mode!="rain" or meteor_trails.any(func(slot): return slot.target==target.id): continue
		for slot in meteor_trails:
			if slot.target==-1 and slot.tail<=0:
				slot.target=target.id;slot.emitter.position=target.position
				slot.emitter.direction=-Vector2(target.velocity).normalized()
				slot.emitter.restart();slot.emitter.emitting=true
				break

func snapshot() -> Dictionary:
	return {"backend":"CPUParticles2D + PointLight2D + Tween + canvas shaders","events":event_count,"launches":launch_count,"burst_pool":bursts.size(),"trail_pool":trails.size(),"meteor_trails":meteor_trails.filter(func(slot): return slot.emitter.emitting).size(),"light_pool":lights.size(),"wave_pool":waves.size(),"tower_auras":auras.filter(func(p): return p.emitting).size(),"dive_wake_pool":dive_wakes.size(),"active_dive_wakes":dive_wakes.filter(func(s): return s.emitter.emitting).size(),"racing_exhaust_pool":racing_exhaust.size(),"active_racing_exhaust":racing_exhaust.filter(func(p):return p.emitting).size(),"cooking_stoves":stoves.filter(func(s): return s.fire.emitting).size(),"active_bursts":bursts.filter(func(p): return p.emitting).size(),"active_lights":lights.filter(func(p): return p.node.enabled).size(),"protected_regions":protected_regions.size(),"clock":clock,"paused":paused,"reduced":reduced,"shake":[shake.x,shake.y]}
