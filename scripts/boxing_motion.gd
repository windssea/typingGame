class_name BoxingMotion
extends RefCounted

const BLUE_IDLE = preload("res://assets/animations/boxing-blue-idle-v002/idle.tres")
const CORAL_IDLE = preload("res://assets/animations/boxing-coral-idle-v001/idle.tres")
const BLUE_PUNCH = preload("res://assets/animations/boxing-blue-punch-v003/idle.tres")
const CORAL_PUNCH = preload("res://assets/animations/boxing-coral-punch-v001/idle.tres")

static func texture(side: int, clock: float, attack_age: float, reduced: bool) -> Texture2D:
	var frames: SpriteFrames = BLUE_IDLE if side==0 else CORAL_IDLE
	var animation := "idle"
	var seconds := clock
	if not reduced and attack_age>=0:
		var attack: SpriteFrames = BLUE_PUNCH if side==0 else CORAL_PUNCH
		if attack_age<float(attack.get_frame_count("punch"))/attack.get_animation_speed("punch"):
			frames = attack
			animation = "punch"
			seconds = attack_age
	var index := 0 if reduced else int(seconds*frames.get_animation_speed(animation))%frames.get_frame_count(animation)
	return frames.get_frame_texture(animation,index)
