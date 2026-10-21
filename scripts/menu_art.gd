class_name MenuArt
extends RefCounted

static func background(mode: String) -> String:
	return "res://assets/menu-v20/bg-"+mode+".png" if ContentPackLoader.enabled() else GeneratedArt.background_path(mode)

static func icon(mode: String) -> Texture2D:
	return load("res://assets/menu-v20/icon-"+mode+".png")
