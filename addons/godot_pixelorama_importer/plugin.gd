@tool
extends EditorPlugin

const GenFilesExportPlugin = preload("./export_gen.gd")

var editor_settings := get_editor_interface().get_editor_settings()
var import_plugins: Array = []
var current_file: String = ""
var export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	setup_editor_settings()
	setup_pixelorama_path()
	setup_import_plugins()
	setup_export_plugin()


func _exit_tree() -> void:
	for plugin in import_plugins:
		remove_import_plugin(plugin)
	import_plugins = []
	if export_plugin:
		remove_export_plugin(export_plugin)


func setup_export_plugin() -> void:
	export_plugin = GenFilesExportPlugin.new()
	add_export_plugin(export_plugin)


func setup_editor_settings() -> void:
	var hint_string := []
	for plugin in import_plugins:
		hint_string.append(plugin.VISIBLE_NAME)

	var property_infos = [
		{
			"default": "Single Image",
			"property_info":
			{
				"name": "pixelorama/default_import_type",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(hint_string)
			}
		},
		{
			"default": Vector2.ONE,
			"property_info":
			{
				"name": "pixelorama/default_scale",
				"type": TYPE_VECTOR2,
			}
		},
		{
			"default": false,
			"property_info":
			{
				"name": "pixelorama/default_animation_external_save",
				"type": TYPE_BOOL,
			}
		},
		{
			"default": "",
			"property_info":
			{
				"name": "pixelorama/default_animation_external_save_path",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_DIR
			}
		}
	]

	for pi in property_infos:
		if !ProjectSettings.has_setting(pi.property_info.name):
			ProjectSettings.set_setting(pi.property_info.name, pi.default)
		ProjectSettings.add_property_info(pi.property_info)


func setup_pixelorama_path() -> void:
	var property_info = {
		"name": "pixelorama/path",
		"type": TYPE_STRING,
	}

	match OS.get_name():
		"Windows":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_FILE
			property_info["hint_string"] = "*.exe"
		"OSX":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_DIR
			property_info["hint_string"] = "*.app"
		"X11":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_FILE
			property_info["hint_string"] = "*.x86_64"

	if !editor_settings.has_setting("pixelorama/path"):
		editor_settings.set_setting("pixelorama/path", "")

	editor_settings.add_property_info(property_info)


func setup_import_plugins() -> void:
	import_plugins = [
		preload("single_image_import.gd").new(),
		preload("spriteframes_import.gd").new(get_editor_interface()),
		preload("animation_player_import.gd").new(get_editor_interface())
	]

	for plugin in import_plugins:
		add_import_plugin(plugin)


func _handles(object) -> bool:
	if object is Resource and object.resource_path.ends_with(".pxo"):
		return true
	return false


func _edit(object) -> void:
	if object is Resource and object.resource_path.ends_with(".pxo"):
		if editor_settings.get_setting("pixelorama/path") == "":
			var popup = AcceptDialog.new()
			popup.title = "No Pixelorama Binary found!"
			popup.dialog_text = (
				"Specify the path to the binary in the Editor Settings"
				+ "(Editor > Editor Settings...) under Pixelorama > Path"
			)
			popup.exclusive = true
			popup.wrap_controls = true

			get_editor_interface().get_base_control().add_child(popup)
			popup.popup_centered_clamped()

			var confirmed = await popup.confirmed
			popup.queue_free()
			return

		var path = editor_settings.get_setting("pixelorama/path")
		if OS.get_name() == "OSX":
			path += "/Contents/MacOS/Pixelorama"

		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Pixelorama binary could not be found")
			return

		var output = []
		OS.execute(path, [ProjectSettings.globalize_path(object.resource_path)], output, false)


func _get_plugin_name() -> String:
	return "PXOImporter"
