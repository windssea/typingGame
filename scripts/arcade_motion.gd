class_name ArcadeMotion
extends RefCounted

# Only the current arena's clips are loaded. The simulation owns hits and timing.
const LIBRARY := {
	"knight":{"idle":"knight-v18"},
	"sub":{"idle":"sub-v18"},
	"dive_scout":{"idle":"dive-scout-idle-v23","alert":"dive-scout-alert-v23","hit":"dive-scout-hit-v23"},
	"dive_armored":{"idle":"dive-armored-idle-v23","alert":"dive-armored-alert-v23","hit":"dive-armored-hit-v23"},
	"chef":{"idle":"chef-idle-v22","stir":"chef-stir-v22","toss":"chef-toss-v22","serve":"chef-serve-v22","walk":"chef-walk-v22"},
	"robot":{"idle":"robot-v18"},
	"balloon_pop":{"idle":"balloon-pop-v18"},
	"coach":{"idle":"coach-idle-hd-v11","cheer":"coach-cheer-hd-v11","run":"coach-run-hd-v11"},
	"moles":{"idle":"mole-idle-hd-v11","hit":"mole-hit-hd-v11"},
	"aliens":{"idle":"ufo-idle-hd-v11","hit":"ufo-hit-hd-v11"},
	"racing":{"idle":"rally-mint-idle-v24","boost":"rally-mint-boost-v24"},
	"racing_rival":{"idle":"rally-coral-idle-v24"},
	"castle":{"idle":"goblin-walk-hd-v11","hit":"goblin-hit-hd-v11"},
	"castle_wolf":{"idle":"wolf-walk-hd-v11","hit":"wolf-hit-hd-v11"},
	"castle_boss":{"idle":"boss-walk-hd-v11","hit":"boss-hit-hd-v11"},
	"castle_guard":{"idle":"guard-walk-hd-v11","hit":"guard-hit-hd-v11"},
	"castle_shaman":{"idle":"shaman-walk-hd-v11","hit":"shaman-hit-hd-v11"},
	"castle_bomber":{"idle":"bomber-walk-hd-v11","hit":"bomber-hit-hd-v11"}
}
var clips: Dictionary = {}

func setup(mode: String, idle_only := false) -> void:
	clips.clear()
	for state in LIBRARY.get(mode,{}):
		if idle_only and state!="idle":
			continue
		var path := "res://assets/animations/"+str(LIBRARY[mode][state])+"/idle.tres"
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource!=null: clips[state] = resource

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
