class_name ArcadeMotion
extends RefCounted

# Only the current arena's clips are loaded. The simulation owns hits and timing.
const LIBRARY := {
	"moles":{"idle":"mole-idle-v10","hit":"mole-hit-v10"},
	"aliens":{"idle":"ufo-idle-v10","hit":"ufo-hit-v10"},
	"racing":{"idle":"rally-drive-v10","boost":"rally-boost-v10"},
	"castle":{"idle":"goblin-walk-v10","hit":"goblin-hit-v10"},
	"castle_wolf":{"idle":"wolf-walk-v10","hit":"wolf-hit-v10"},
	"castle_boss":{"idle":"boss-walk-v10b","hit":"boss-hit-v10b"},
	"castle_guard":{"idle":"guard-walk-v10","hit":"guard-hit-v10"},
	"castle_shaman":{"idle":"shaman-walk-v10","hit":"shaman-hit-v10"},
	"castle_bomber":{"idle":"bomber-walk-v10","hit":"bomber-hit-v10"}
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
