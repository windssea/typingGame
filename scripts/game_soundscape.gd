class_name GameSoundscape
extends Node

var settings: Dictionary = {}
var run: GameRun
var music: AudioStreamPlayer
var rhythm: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var cursor := 0
var last_cue: Dictionary = {}
var rng := RandomNumberGenerator.new()
var duck := 0.0

func _exit_tree() -> void:
	for player in voices+[music,rhythm]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	voices.clear()
	streams.clear()
	run = null

func _ready() -> void:
	rng.seed = 8172
	for bus in ["Music","SFX","UI"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"Master")
	for kind in ["key","error","focus","confirm","combo","win","retry"]:
		streams[kind] = load("res://assets/audio/v10/"+kind+".wav")
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = load("res://assets/audio/v10/explore.ogg")
	music.stream.loop = true
	add_child(music)
	rhythm = AudioStreamPlayer.new()
	rhythm.bus = "Music"
	rhythm.stream = load("res://assets/audio/v10/rhythm.ogg")
	rhythm.stream.loop = true
	add_child(rhythm)
	apply_settings()
	# Simulation-only runs have no audio device; avoid pending dummy-driver playbacks.
	if DisplayServer.get_name()!="headless":
		music.play()
		rhythm.play()

func apply_settings() -> void:
	var enabled: bool = settings.get("sound",true)
	for bus in ["Music","SFX","UI"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),not enabled)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),linear_to_db(maxf(.0001,settings.get("music_volume",.45)))-12)
	for bus in ["SFX","UI"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(.0001,settings.get("sfx_volume",.7)))-3)

func cue(kind: String, volume := -18.0) -> void:
	if not settings.get("sound",true) or not streams.has(kind):
		return
	var now := Time.get_ticks_msec()
	var interval := 55 if kind=="key" else 70 if kind=="focus" else 100
	if now-int(last_cue.get(kind,-1000))<interval:
		return
	last_cue[kind] = now
	var voice := voices[cursor%voices.size()]
	cursor += 1
	voice.bus = "UI" if kind in ["focus","confirm"] else "SFX"
	voice.stream = streams[kind]
	voice.volume_db = volume
	voice.pitch_scale = rng.randf_range(.97,1.03) if kind not in ["win","retry","combo"] else 1.0
	if DisplayServer.get_name()!="headless":
		voice.play()
	if kind in ["win","retry","combo"]:
		duck = .6

func bind_run(value: GameRun) -> void:
	run = value
	run.key_feedback.connect(func(_character,accepted,_point): cue("key" if accepted else "error",-26 if accepted else -22))
	run.spell.connect(func(_a,_b,_lightning):
		if run.combo>0 and run.combo%5==0:
			cue("combo",-14))
	run.ended.connect(func(): cue("win" if run.won else "retry",-10))

func _process(delta: float) -> void:
	duck = maxf(0,duck-delta)
	var active := is_instance_valid(run) and not run.done and not run.paused
	var energy := minf(1,float(run.combo)/8) if active else 0.0
	var target := -34.0+energy*20 if active else -42.0
	rhythm.volume_db = lerpf(rhythm.volume_db,target,1-exp(-delta*3))
	music.volume_db = lerpf(music.volume_db,-5.0 if duck>0 or (is_instance_valid(run) and run.paused) else 0.0,1-exp(-delta*8))
