class_name BoxingMotion
extends RefCounted

const BLUE_IDLE = "res://assets/animations/boxing-blue-idle-hd-v11/idle.tres"
const CORAL_IDLE = "res://assets/animations/boxing-coral-idle-hd-v11/idle.tres"
const BLUE_PUNCH = "res://assets/animations/boxing-blue-punch-hd-v11/idle.tres"
const CORAL_PUNCH = "res://assets/animations/boxing-coral-punch-hd-v11/idle.tres"

static func load_clips() -> Array[SpriteFrames]:
	return [load(BLUE_IDLE),load(CORAL_IDLE),load(BLUE_PUNCH),load(CORAL_PUNCH)]

static func texture(side: int, clock: float, attack_age: float, reduced: bool, loaded: Array[SpriteFrames] = []) -> Texture2D:
	var clips := loaded if not loaded.is_empty() else load_clips()
	var frames: SpriteFrames = clips[side]
	var animation := "idle"
	var seconds := clock
	if not reduced and attack_age>=0:
		var attack: SpriteFrames = clips[side+2]
		if attack_age<float(attack.get_frame_count("punch"))/attack.get_animation_speed("punch"):
			frames = attack
			animation = "punch"
			seconds = attack_age
	var index := 0 if reduced else int(seconds*frames.get_animation_speed(animation))%frames.get_frame_count(animation)
	return frames.get_frame_texture(animation,index)
