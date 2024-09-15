extends Node

const Result = preload("./Result.gd")


static func read_pxo_file(source_file: String, image_save_path: String):
	var result = Result.new()

	# Open the Pixelorama project file as a ZIP
	var zip_reader := ZIPReader.new()
	var err := zip_reader.open(source_file)
	if err != OK:
		printerr("Failed to open file as ZIP. Error code: ", err)
		result.error = err
		return result

	# Read and parse the data.json file
	var data_json := zip_reader.read_file("data.json")
	if data_json.is_empty():
		printerr("data.json not found or empty")
		result.error = ERR_FILE_CORRUPT
		zip_reader.close()
		return result

	var test_json_conv = JSON.new()
	var json_error = test_json_conv.parse(data_json.get_string_from_utf8())

	if json_error != OK:
		printerr("JSON Parse Error")
		result.error = json_error
		zip_reader.close()
		return result

	var project = test_json_conv.get_data()

	# Make sure it's a JSON Object
	if typeof(project) != TYPE_DICTIONARY:
		printerr("Invalid Pixelorama project file")
		result.error = ERR_FILE_UNRECOGNIZED
		zip_reader.close()
		return result

	# Load the cel dimensions and frame count
	var size = Vector2(project.size_x, project.size_y)
	var frame_count = project.frames.size()
	var layer_count = project.layers.size()

	# Prepare the spritesheet image
	var spritesheet = Image.create(size.x * frame_count, size.y, false, Image.FORMAT_RGBA8)

	for frame_index in range(frame_count):
		var frame = project.frames[frame_index]
		
		# Prepare the frame image
		var frame_img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		
		for layer_index in range(layer_count):
			var layer = project.layers[layer_index]
			var cel = frame.cels[layer_index]
			var opacity: float = cel.opacity

			if layer.visible and opacity > 0.0:
				var cel_path = "image_data/frames/%d/layer_%d" % [frame_index + 1, layer_index + 1]
				var cel_data = zip_reader.read_file(cel_path)
				if cel_data.is_empty():
					printerr("Failed to read cel data for frame %d, layer %d" % [frame_index + 1, layer_index + 1])
					continue

				var cel_img = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, cel_data)

				if opacity < 1.0:
					for x in range(size.x):
						for y in range(size.y):
							var color := cel_img.get_pixel(x, y)
							color.a *= opacity
							cel_img.set_pixel(x, y, color)

				if layer.blend_mode == 0:
					frame_img.blend_rect(cel_img, Rect2(Vector2.ZERO, size), Vector2.ZERO)

		spritesheet.blit_rect(frame_img, Rect2(Vector2.ZERO, size), Vector2(size.x * frame_index, 0))

	zip_reader.close()

	save_ctex(spritesheet, image_save_path)
	result.value = project
	result.error = OK

	return result


# Based on CompressedTexture2D::_load_data from
# https://github.com/godotengine/godot/blob/master/scene/resources/texture.cpp
static func save_ctex(image, save_path: String):
	var tmpwebp = "%s-tmp.webp" % [save_path]
	image.save_webp(tmpwebp) # not quite sure, but the png import that I tested was in webp

	var webpf = FileAccess.open(tmpwebp, FileAccess.READ)
	var webplen = webpf.get_length()
	var webpdata = webpf.get_buffer(webplen)
	webpf = null # setting null will close the file

	var dir := DirAccess.open(tmpwebp.get_base_dir())
	dir.remove(tmpwebp.get_file())

	var ctexf = FileAccess.open("%s.ctex" % [save_path], FileAccess.WRITE)
	ctexf.store_8(0x47) # G
	ctexf.store_8(0x53) # S
	ctexf.store_8(0x54) # T
	ctexf.store_8(0x32) # 2
	ctexf.store_32(0x01) # FORMAT_VERSION
	ctexf.store_32(image.get_width())
	ctexf.store_32(image.get_height())
	ctexf.store_32(0xD000000) # data format (?)
	ctexf.store_32(0xFFFFFFFF) # mipmap_limit
	ctexf.store_32(0x0) # reserved
	ctexf.store_32(0x0) # reserved
	ctexf.store_32(0x0) # reserved
	ctexf.store_32(0x02) # data format (WEBP, it's DataFormat enum but not available in gdscript)
	ctexf.store_16(image.get_width()) # w
	ctexf.store_16(image.get_height()) # h
	ctexf.store_32(0x00) # mipmaps
	ctexf.store_32(Image.FORMAT_RGBA8) # format
	ctexf.store_32(webplen) # webp length
	ctexf.store_buffer(webpdata)
	ctexf = null # setting null will close the file

	print("ctex saved")

	return OK
