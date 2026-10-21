extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void:
	var clips:=BoxingMotion.load_clips()
	var atlases: Dictionary={}
	for clip in clips:
		for animation in clip.get_animation_names():
			check(clip.get_animation_speed(animation)==24,"source frame rate remains 24fps")
			for i in range(clip.get_frame_count(animation)):
				var frame: AtlasTexture=clip.get_frame_texture(animation,i)
				check(frame.region.size==Vector2(384,384),"native HD canvas is retained")
				var path:=frame.atlas.resource_path
				if not atlases.has(path): atlases[path]=frame.atlas.get_image()
				var image: Image=atlases[path]
				var safe:=true
				var origin:=Vector2i(frame.region.position)
				for pixel in range(384):
					for inset in range(3):
						for edge in [Vector2i(pixel,inset),Vector2i(pixel,383-inset),Vector2i(inset,pixel),Vector2i(383-inset,pixel)]:
							if image.get_pixelv(origin+edge).a>.32: safe=false
				check(safe,"a referenced pose never clips the character against its canvas edge")
	var idle:=BoxingMotion.texture(0,0,-1,false,clips)
	var guard:=BoxingMotion.texture(0,0,-1,false,clips,-1,true)
	check(idle!=guard,"earned guard has its own articulated pose")
	for side in range(2):
		var early:=BoxingMotion.texture(side,0,0,false,clips)
		var contact:=BoxingMotion.texture(side,0,ArcadeRun.PUNCH_CONTACT,false,clips)
		check(early!=contact,"the contact frame contains a different native jab pose")
		check(BoxingMotion.texture(side,0,-1,false,clips,0)!=BoxingMotion.texture(side,0,-1,false,clips),"both fighters have real hit-reaction clips")
	print("FIGHTER ANIMATION: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(description)
