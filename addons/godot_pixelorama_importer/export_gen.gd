@tool
extends EditorExportPlugin


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	var gen_files_path = "res://.godot/pixelorama"
	var dir = DirAccess.open(gen_files_path)
	if dir:
		_add_files_recursively(dir, gen_files_path)
	else:
		print("Failed to open .gen directory")


func _add_files_recursively(dir: DirAccess, current_path: String) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var file_path = current_path.path_join(file_name)

		if dir.current_is_dir():
			var subdir = DirAccess.open(file_path)
			if subdir:
				_add_files_recursively(subdir, file_path)
		else:
			print("Adding custom file: ", file_path)
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content = file.get_buffer(file.get_length())
				add_file(file_path, content, false)
			else:
				print("Failed to open file: ", file_path)

		file_name = dir.get_next()

	dir.list_dir_end()
