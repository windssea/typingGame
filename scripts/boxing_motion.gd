class_name BoxingMotion
extends RefCounted

const BLUE_IDLE = "res://assets/animations/boxing-blue-idle-v21/idle.tres"
const CORAL_IDLE = "res://assets/animations/boxing-coral-idle-v21/idle.tres"
const BLUE_PUNCH = "res://assets/animations/boxing-blue-jab-v21/idle.tres"
const CORAL_PUNCH = "res://assets/animations/boxing-coral-jab-v21/idle.tres"
const CORAL_HIT = "res://assets/animations/boxing-coral-hit-v21/idle.tres"
const BLUE_HIT = "res://assets/animations/boxing-blue-hit-v21b/idle.tres"
const BLUE_GUARD = "res://assets/animations/boxing-blue-guard-v21/idle.tres"
const RECOVERY := .28

static func load_clips() -> Array[SpriteFrames]:
	return [load(BLUE_IDLE),load(CORAL_IDLE),load(BLUE_PUNCH),load(CORAL_PUNCH),load(CORAL_HIT),load(BLUE_HIT),load(BLUE_GUARD)]

static func texture(side: int, clock: float, attack_age: float, reduced: bool, loaded: Array[SpriteFrames] = [], reaction_age := -1.0, guarding := false) -> Texture2D:
	var clips := loaded if not loaded.is_empty() else load_clips()
	var frames: SpriteFrames = clips[side]
	var animation := "idle"
	var seconds := clock
	if not reduced and reaction_age>=0 and reaction_age<.38:
		frames = clips[4 if side==1 else 5]
		animation = "hit"
		seconds = reaction_age/.38*float(frames.get_frame_count(animation)-1)/frames.get_animation_speed(animation)
	elif side==0 and guarding and not (attack_age>=0 and attack_age<ArcadeRun.PUNCH_CONTACT+RECOVERY):
		frames=clips[6];animation="guard"
	elif not reduced and attack_age>=0:
		var attack: SpriteFrames = clips[side+2]
		if attack_age<ArcadeRun.PUNCH_CONTACT+RECOVERY:
			frames = attack
			animation = "punch"
			# Native source poses are sampled on the combat timeline. No interpolated
			# images or duplicated frames are authored into either SpriteFrames clip.
			var contact_frame := 18 if side==0 else 15
			var frame := lerpf(0,contact_frame,clampf(attack_age/ArcadeRun.PUNCH_CONTACT,0,1)) if attack_age<=ArcadeRun.PUNCH_CONTACT else lerpf(contact_frame,frames.get_frame_count(animation)-1,clampf((attack_age-ArcadeRun.PUNCH_CONTACT)/RECOVERY,0,1))
			seconds = frame/frames.get_animation_speed(animation)
	var index := 0 if reduced else int(seconds*frames.get_animation_speed(animation))%frames.get_frame_count(animation)
	return frames.get_frame_texture(animation,index)
