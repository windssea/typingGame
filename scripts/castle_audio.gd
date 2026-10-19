class_name CastleAudio
extends Node

var enabled := true
var battle: GameRun
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_played: Dictionary = {}
var cursor := 0

func _ready() -> void:
	for kind in ["fire","storm","ice","build","warning","damage"]:
		streams[kind] = load("res://assets/audio/"+kind+".wav")
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -20
		add_child(player)
		players.append(player)
	if battle is CastleRun:
		battle.effect.connect(on_effect)
	elif battle is ArcadeRun:
		battle.impact.connect(func(kind,point,power):
			var sound: String = {"balloons":"ice","aliens":"storm","moles":"build","racing":"fire","fighter":"damage","miss":"warning"}.get(kind,"fire")
			on_effect(sound,point,point,power))

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
	player.play()
