class_name ContentPackLoader
extends Node

signal progress(value: float, description: String)
signal finished(mode: String, success: bool, description: String)
var loaded_modes: Dictionary = {}
var active_mode := ""
var callback: JavaScriptObject
var bridge: JavaScriptObject
var last_progress := 0.0
var phase := "idle"

static func enabled() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("typeof window.keyboundPacks !== 'undefined'",true))

func _ready() -> void:
	if not enabled(): return
	bridge=JavaScriptBridge.get_interface("window").keyboundPacks
	callback=JavaScriptBridge.create_callback(_receive)
	bridge.listen(callback)

func needs(mode: String) -> bool:
	return enabled() and not loaded_modes.has(mode)

func request(mode: String) -> void:
	active_mode=mode;phase="loading";last_progress=0
	bridge.request(mode)

func cancel() -> void:
	active_mode="";phase="idle"
	if bridge!=null: bridge.cancel()

func _receive(args: Array) -> void:
	# Defer mounting out of the JavaScript callback to avoid re-entering the engine.
	_receive_deferred.call_deferred(str(args[0]),float(args[1]),str(args[2]),str(args[3]))

func _receive_deferred(mode: String, value: float, status: String, payload: String) -> void:
	if active_mode!=mode: return
	last_progress=value;phase=status
	if status=="ready":
		var paths=JSON.parse_string(payload)
		if not paths is Array:
			finished.emit(mode,false,"资源校验失败，请重试。")
			return
		for path in paths:
			if not ProjectSettings.load_resource_pack(str(path),false):
				phase="error";finished.emit(mode,false,"资源暂时无法打开，请重试。")
				return
		loaded_modes[mode]=true;phase="ready";active_mode=""
		finished.emit(mode,true,"")
	elif status=="error": finished.emit(mode,false,"连接中断，请检查网络后重试。")
	else: progress.emit(value,"正在校验资源…" if status=="verify" else "正在加载游戏…")

func _exit_tree() -> void:
	if bridge!=null: bridge.listen(null)
