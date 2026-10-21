class_name CastleAudio
extends Node

var enabled := true
var battle: GameRun
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_played: Dictionary = {}
var cursor := 0

func _exit_tree() -> void:
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	streams.clear()

func _ready() -> void:
	for kind in ["fire","storm","ice","build","warning","damage"]:
		streams[kind] = load("res://assets/audio/"+kind+".wav")
	for kind in ["pop","mallet","laser","engine","punch","block","skill","combo"]:
		streams[kind] = load("res://assets/audio/v10/"+kind+".wav")
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -20
		player.bus = "SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
		add_child(player)
		players.append(player)
	if battle is CastleRun:
		battle.effect.connect(on_effect)
	elif battle is AdventureRun:
		battle.action.connect(func(kind,point):
			# Delivery is a quiet launch; the guest chime belongs to plate arrival.
			if kind=="deliver": return
			on_effect({"hit":"punch","core":"damage","serve":"combo","cook":"fire","chop":"mallet","launch":"laser","deploy":"build","miss":"damage","skill":"skill"}.get(kind,"build"),point,point,1))
	elif battle is ArcadeRun:
		battle.impact.connect(func(kind,point,power):
			var sound: String = {"balloons":"pop","aliens":"laser","moles":"mallet","racing":"engine","fighter":"punch","miss":"damage","block":"block","skill":"skill"}.get(kind,"fire")
			on_effect(sound,point,point,power))
	else:
		battle.spell.connect(func(a,b,_lightning): on_effect("pop" if battle.mode=="bubbles" else "laser" if battle.mode=="rain" else "build",a,b,1))

func on_effect(kind: String,_origin: Vector2,_destination: Vector2,_amount: int) -> void:
	if not enabled or battle.paused:
		return
	if kind in ["boss","rage"]:
		kind = "warning"
	if not streams.has(kind):
		return
	var now := Time.get_ticks_msec()
	if now-int(last_played.get(kind,-1000))<100:
		return
	last_played[kind] = now
	var player := players[cursor%players.size()]
	cursor += 1
	player.stream = streams[kind]
	player.volume_db = {"punch":-13.0,"mallet":-15.0,"pop":-16.0,"laser":-17.0,"engine":-19.0,"skill":-13.0,"block":-14.0,"damage":-15.0,"warning":-18.0}.get(kind,-18.0)
	player.pitch_scale = 1.0+sin(cursor*2.399)*.025+(minf(battle.combo,10)*.012 if kind in ["punch","mallet","pop","laser","build"] else 0.0)
	if DisplayServer.get_name()!="headless":
		player.play()
