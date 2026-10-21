extends SceneTree

func _initialize() -> void:
	var arguments:=OS.get_cmdline_user_args()
	if arguments.is_empty(): quit(2);return
	var plan=JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	for group in plan.groups:
		var packer:=PCKPacker.new()
		if packer.pck_start(plan.groups[group].output)!=OK: quit(2);return
		for entry in plan.groups[group].files:
			if packer.add_file("res://"+entry.path,entry.file)!=OK:
				push_error("Cannot pack "+entry.path);quit(2);return
		if packer.flush()!=OK: quit(2);return
	print("Built %d independent content packs"%plan.groups.size())
	quit()
