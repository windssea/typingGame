class_name ArcadeMotion
extends RefCounted

# Only the current arena's clips are loaded. The simulation owns hits and timing.
const LIBRARY := {
	"moles":{"idle":"mole-idle-v08","hit":"mole-hit-v08"},
	"aliens":{"idle":"ufo-idle-v08","hit":"ufo-hit-v08"},
	"racing":{"idle":"rally-drive-v08","boost":"rally-boost-v08"},
	"castle":{"idle":"goblin-walk-v08","hit":"goblin-hit-v08"}
}
var clips: Dictionary = {}

func setup(mode: String) -> void:
	clips.clear()
	for state in LIBRARY.get(mode,{}):
		var path := "res://assets/animations/"+str(LIBRARY[mode][state])+"/idle.tres"
		if ResourceLoader.exists(path):
			clips[state] = load(path)

func duration(state: String) -> float:
	if not clips.has(state):
		return 0.0
	var frames: SpriteFrames = clips[state]
	return frames.get_frame_count(state)/frames.get_animation_speed(state)

func texture(state: String, seconds: float, reduced := false) -> Texture2D:
	if reduced:
		state = "idle"
	if not clips.has(state):
		state = "idle"
	if not clips.has(state):
		return null
	var frames: SpriteFrames = clips[state]
	var count := frames.get_frame_count(state)
	var index := 0 if reduced else maxi(0,int(seconds*frames.get_animation_speed(state)))
	index = index%count if frames.get_animation_loop(state) else mini(index,count-1)
	return frames.get_frame_texture(state,index)
