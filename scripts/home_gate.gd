class_name HomeGate
extends Control

var training:=true
var reduced_motion:=false
var clock:=0.0
var selected:=0.0
var target_selected:=0.0
var hero:AnimatedSprite2D
var lamp:PointLight2D
var motes:CPUParticles2D
var props:=preload("res://assets/menu-v25/entrances.png")
var contact:GradientTexture2D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	light_mask=4
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(.04,.18,.22,.28),Color(.04,.18,.22,0)])
	contact=GradientTexture2D.new();contact.gradient=gradient;contact.width=128;contact.height=64
	contact.fill=GradientTexture2D.FILL_RADIAL;contact.fill_from=Vector2(.5,.5);contact.fill_to=Vector2(.5,1)
	hero=AnimatedSprite2D.new();hero.name="TrainingCoach" if training else "ChallengeKnight"
	hero.sprite_frames=load("res://assets/menu-v25/coach.tres" if training else "res://assets/menu-v25/knight.tres")
	hero.light_mask=4;hero.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(hero)
	hero.animation_finished.connect(func():
		if training and hero.animation=="cheer":
			hero.sprite_frames=load("res://assets/menu-v25/coach.tres");hero.play("idle"))
	if not reduced_motion:hero.play("idle")
	lamp=PointLight2D.new();lamp.name="PortalLight";lamp.texture=contact
	var light_gradient:=Gradient.new();light_gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var glow:=GradientTexture2D.new();glow.gradient=light_gradient;glow.width=256;glow.height=256
	glow.fill=GradientTexture2D.FILL_RADIAL;glow.fill_from=Vector2(.5,.5);glow.fill_to=Vector2(.5,1)
	lamp.texture=glow;lamp.color=Color("9dffe0") if training else Color("7fdcff")
	lamp.range_item_cull_mask=4;lamp.energy=.18;lamp.texture_scale=1.25;add_child(lamp)
	motes=CPUParticles2D.new();motes.name="PortalMotes";motes.amount=16;motes.lifetime=3.2
	motes.direction=Vector2(0,-1);motes.spread=26;motes.gravity=Vector2.ZERO
	motes.initial_velocity_min=12;motes.initial_velocity_max=32;motes.scale_amount_min=.7;motes.scale_amount_max=1.5
	motes.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;motes.emission_rect_extents=Vector2(70,5)
	motes.texture=preload("res://assets/ui-home-spark-v25.svg")
	motes.color=Color("dcfff0") if training else Color("e7eeff")
	motes.emitting=not reduced_motion;add_child(motes)
	resized.connect(place_characters);place_characters()

func gate_rect() -> Rect2:
	var side:=minf(size.y*1.05,size.x*.86)
	return Rect2(Vector2((size.x-side)*.5,(size.y-side)*.5),Vector2.ONE*side)

func place_characters() -> void:
	if not is_instance_valid(hero):return
	var rect:=gate_rect()
	hero.position=rect.position+rect.size*Vector2(.52,.50)
	hero.scale=Vector2.ONE*(rect.size.y/256*.55)
	lamp.position=rect.position+rect.size*Vector2(.5,.47)
	motes.position=rect.position+rect.size*Vector2(.5,.64)

func set_selected(value:bool) -> void:
	if value and target_selected==0 and training and not reduced_motion and is_instance_valid(hero):
		hero.sprite_frames=load("res://assets/menu-v25/coach-cheer.tres");hero.play("cheer")
	target_selected=1.0 if value else 0.0

func _process(delta:float) -> void:
	selected=move_toward(selected,target_selected,delta*5)
	if not reduced_motion:clock+=delta
	if is_instance_valid(lamp):lamp.energy=.035+selected*.10+(0.0 if reduced_motion else sin(clock*1.6)*.008)
	queue_redraw()

func _draw() -> void:
	var rect:=gate_rect()
	if contact!=null:draw_texture_rect(contact,Rect2(rect.position+Vector2(rect.size.x*.12,rect.size.y*.88),Vector2(rect.size.x*.76,30)),false)
	var source:=Rect2(0,0,887,887) if training else Rect2(887,0,887,887)
	draw_texture_rect_region(props,rect,source)
