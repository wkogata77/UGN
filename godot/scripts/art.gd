class_name FieldArt
extends RefCounted

static var textures: Dictionary = {}
const CACHE_VERSION = "registered-v1"
static var cache_hits = 0

static func cache_path(key: String, source: String) -> String:
	return "user://art-cache/" + CACHE_VERSION + "-" + (key + str(FileAccess.get_modified_time("res://assets/" + source + ".png"))).sha256_text() + ".png"

static func cached(key: String, source: String) -> Texture2D:
	var path = cache_path(key, source)
	if not FileAccess.file_exists(path): return null
	var pixels = Image.new()
	if pixels.load(path) != OK or pixels.is_empty(): return null
	pixels.generate_mipmaps()
	textures[key] = ImageTexture.create_from_image(pixels)
	cache_hits += 1
	return textures[key]

static func remember(key: String, source: String, pixels: Image) -> Texture2D:
	if DirAccess.make_dir_recursive_absolute("user://art-cache") == OK:
		pixels.save_png(cache_path(key, source))
	textures[key] = ImageTexture.create_from_image(pixels)
	return textures[key]
const INFANTRY_CELL = Vector2i(384, 512)

static func battle_cycle(type: int) -> Texture2D:
	var name = ["infantry-cycle-french-v2", "infantry-cycle-austrian-v2", "cavalry-cycle-french-v2", "cavalry-cycle-austrian-v2"][type]
	var key = name + ":cycle-v1"
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var columns = 8 if type < 2 else 6
	var cell = Vector2i(512, 320) if type < 2 else Vector2i(320, 320)
	var atlas = Image.create(cell.x * columns, cell.y * 5, false, Image.FORMAT_RGBA8)
	for row in 5:
		var frames: Array[Image] = []
		for column in columns:
			var a = Vector2i(column * source.get_width() / columns, row * source.get_height() / 5)
			var b = Vector2i((column + 1) * source.get_width() / columns, (row + 1) * source.get_height() / 5)
			frames.append(source.get_region(Rect2i(a, b - a)))
		var rest = frames[0].get_used_rect()
		var scale_value = minf(cell.y * 0.84 / maxf(1, rest.size.y), cell.x * (0.68 if type < 2 else 0.86) / maxf(1, rest.size.x))
		for column in columns:
			var pixels = frames[column]
			var bounds = pixels.get_used_rect()
			var feet = pixels.get_region(Rect2i(0, int(pixels.get_height() * 0.68), pixels.get_width(), pixels.get_height() - int(pixels.get_height() * 0.68))).get_used_rect()
			var width = roundi(pixels.get_width() * scale_value)
			var height = roundi(pixels.get_height() * scale_value)
			var origin = Vector2(cell.x * 0.5 - feet.get_center().x * scale_value, cell.y * (0.92 if type < 2 else 0.94) - bounds.end.y * scale_value)
			pixels.resize(width, height, Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, cell), Vector2i(column, row) * cell)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)

static func melee_texture(type: int) -> Texture2D:
	var name = ["infantry-melee-french-v2", "infantry-melee-austrian-v2", "cavalry-melee-french-v1", "cavalry-melee-austrian-v1"][type]
	var key = name + ":registered"
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var size = Vector2i(source.get_width() / 3, source.get_height() / 3)
	var cell = Vector2i(768, 512) if type < 2 else Vector2i(512, 512)
	var atlas = Image.create(cell.x * 3, cell.y * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		var idle = source.get_region(Rect2i(Vector2i(0, row * size.y), size))
		var body = idle.get_region(Rect2i(int(size.x * 0.32), 0, int(size.x * 0.36), size.y)).get_used_rect()
		var scale_value = cell.y * (0.74 if type < 2 else 0.85) / maxf(1, body.size.y)
		for frame in 3:
			var pixels = source.get_region(Rect2i(Vector2i(frame, row) * size, size))
			var bounds = pixels.get_used_rect()
			var feet = pixels.get_region(Rect2i(0, int(size.y * 0.62), size.x, size.y - int(size.y * 0.62))).get_used_rect()
			# Register beneath the body, leaving room for the extended bayonet.
			var origin = Vector2(cell.x * 0.5 - feet.get_center().x * scale_value, cell.y * 0.92 - bounds.end.y * scale_value)
			pixels.resize(roundi(size.x * scale_value), roundi(size.y * scale_value), Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, cell), Vector2i(frame, row) * cell)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)
const SCENERY_REGIONS = {
	"woodland-v3": [Rect2i(0, 0, 590, 523), Rect2i(590, 0, 410, 523), Rect2i(1024, 0, 512, 523), Rect2i(0, 523, 555, 501), Rect2i(560, 523, 450, 501), Rect2i(1024, 523, 512, 501)],
	"woodland-v4": [Rect2i(0, 0, 600, 520), Rect2i(600, 0, 424, 560), Rect2i(1024, 0, 512, 536), Rect2i(0, 540, 560, 484), Rect2i(560, 540, 464, 484), Rect2i(1024, 540, 512, 484)],
	"woodland-v2": [Rect2i(0, 0, 625, 512), Rect2i(640, 0, 350, 512), Rect2i(1024, 0, 512, 512), Rect2i(0, 512, 512, 512), Rect2i(512, 512, 512, 512), Rect2i(1024, 512, 512, 512)],
	"architecture-v2": [Rect2i(0, 0, 512, 512), Rect2i(512, 0, 512, 512), Rect2i(1024, 0, 512, 512), Rect2i(0, 512, 565, 512), Rect2i(585, 512, 439, 512), Rect2i(1024, 512, 512, 512)]
}

static func motion_texture(type: int) -> Texture2D:
	if type < 2: return infantry_texture(type)
	var name = {2: "cavalry-walk-french-v1", 3: "cavalry-walk-austrian-v1", 4: "artillery-motion-french-v1", 5: "artillery-motion-austrian-v1", 7: "wagon-motion-v1"}[type]
	var key: String = name + ":registered"
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var columns = 5 if type in [4, 5] else 3
	var width = source.get_width() / columns
	var rows = [0, 320, 615, source.get_height()] if type == 7 else [0, source.get_height() / 3, source.get_height() * 2 / 3, source.get_height()]
	var cell = Vector2i(384, 384)
	var atlas = Image.create(cell.x * columns, cell.y * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		var union = Rect2i()
		var frames: Array[Image] = []
		for frame in columns:
			var pixels = source.get_region(Rect2i(frame * width, rows[row], width, rows[row + 1] - rows[row]))
			frames.append(pixels)
			union = pixels.get_used_rect() if frame == 0 else union.merge(pixels.get_used_rect())
		# A common transform per direction preserves wheel centers and horse proportions.
		var scale_value = minf(cell.x * 0.9 / union.size.x, cell.y * 0.88 / union.size.y)
		var origin = Vector2(cell.x * 0.5 - union.get_center().x * scale_value, cell.y * 0.94 - union.end.y * scale_value)
		for frame in columns:
			var pixels = frames[frame]
			pixels.resize(roundi(pixels.get_width() * scale_value), roundi(pixels.get_height() * scale_value), Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, cell), Vector2i(frame, row) * cell)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)

static func gun_cycle(type: int) -> Texture2D:
	var name = "artillery-cycle-french-v2" if type == 4 else "artillery-cycle-austrian-v2"
	var key = name + ":registered-v1"
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var cell = Vector2i(384, 320)
	var atlas = Image.create(cell.x * 7, cell.y * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		var regions: Array[Image] = []
		var union = Rect2i()
		for column in 7:
			var a = Vector2i(column * source.get_width() / 7, row * source.get_height() / 3)
			var b = Vector2i((column + 1) * source.get_width() / 7, (row + 1) * source.get_height() / 3)
			var pixels = source.get_region(Rect2i(a, b - a))
			regions.append(pixels)
			union = pixels.get_used_rect() if column == 0 else union.merge(pixels.get_used_rect())
		var scale_value = minf(cell.x * 0.92 / union.size.x, cell.y * 0.88 / union.size.y)
		var origin = Vector2(cell.x * 0.5 - union.get_center().x * scale_value, cell.y * 0.94 - union.end.y * scale_value)
		for column in 7:
			var pixels = regions[column]
			pixels.resize(roundi(pixels.get_width() * scale_value), roundi(pixels.get_height() * scale_value), Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, cell), Vector2i(column, row) * cell)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)

static func infantry_texture(type: int) -> Texture2D:
	var name = "infantry-walk-french-v1" if type == 0 else "infantry-walk-austrian-v1"
	var key = name + ":registered"
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var cell = Vector2i(source.get_width() / 3, source.get_height() / 3)
	var atlas = Image.create(INFANTRY_CELL.x * 3, INFANTRY_CELL.y * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		var idle = source.get_region(Rect2i(Vector2i(0, row * cell.y), cell))
		var body = idle.get_region(Rect2i(0, 0, cell.x, int(cell.y * 0.58))).get_used_rect()
		var bounds = idle.get_used_rect()
		var scale_value = INFANTRY_CELL.y * 0.84 / bounds.size.y
		for frame in 3:
			var pixels = source.get_region(Rect2i(Vector2i(frame * cell.x, row * cell.y), cell))
			var upper = pixels.get_region(Rect2i(0, 0, cell.x, int(cell.y * 0.58))).get_used_rect()
			# Register by the unchanged upper silhouette, not the moving boots.
			var origin = Vector2(INFANTRY_CELL.x * 0.5 - upper.get_center().x * scale_value, INFANTRY_CELL.y * 0.92 - (bounds.end.y + upper.position.y - body.position.y) * scale_value)
			pixels.resize(roundi(cell.x * scale_value), roundi(cell.y * scale_value), Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(INFANTRY_CELL.x, INFANTRY_CELL.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, INFANTRY_CELL), Vector2i(frame, row) * INFANTRY_CELL)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)

static func reload_texture(type: int) -> Texture2D:
	var name = "unit-reload-v1"
	var key = name + ":registered:" + str(type)
	if textures.has(key): return textures[key]
	if cached(key, name) != null: return textures[key]
	var source = texture(name, true).get_image()
	var size = Vector2i(source.get_width() / 6, source.get_height() / 4)
	var cell = INFANTRY_CELL if type < 2 else Vector2i(384, 384)
	var atlas = Image.create(cell.x * 2, cell.y * 3, false, Image.FORMAT_RGBA8)
	for direction in 3:
		var frames: Array[Image] = []
		var bounds = Rect2i()
		for frame in 2:
			var pixels = source.get_region(Rect2i(Vector2i(direction * 2 + frame, type) * size, size))
			frames.append(pixels)
			bounds = pixels.get_used_rect() if frame == 0 else bounds.merge(pixels.get_used_rect())
		# Both loading poses share one transform, keeping planted feet and horses fixed.
		var scale_value = minf(cell.x * 0.9 / bounds.size.x, cell.y * (0.84 if type < 2 else 0.88) / bounds.size.y)
		var lower = frames[0].get_region(Rect2i(0, int(size.y * 0.6), size.x, size.y - int(size.y * 0.6))).get_used_rect()
		var origin = Vector2(cell.x * 0.5 - lower.get_center().x * scale_value, cell.y * (0.92 if type < 2 else 0.94) - bounds.end.y * scale_value)
		for frame in 2:
			var pixels = frames[frame]
			pixels.resize(roundi(size.x * scale_value), roundi(size.y * scale_value), Image.INTERPOLATE_LANCZOS)
			var registered = Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			registered.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(origin.round()))
			atlas.blit_rect(registered, Rect2i(Vector2i.ZERO, cell), Vector2i(frame, direction) * cell)
	atlas.generate_mipmaps()
	return remember(key, name, atlas)

static func casualty_texture() -> Texture2D:
	var key = "casualties-v1:registered"
	if textures.has(key): return textures[key]
	if cached(key, "casualties-v1") != null: return textures[key]
	var source = texture("casualties-v1", true).get_image()
	var atlas = Image.create(768, 512, false, Image.FORMAT_RGBA8)
	for index in 6:
		var row = index / 3
		var pixels = source.get_region(Rect2i((index % 3) * 512, 0 if row == 0 else 475, 512, 475 if row == 0 else 549))
		pixels = pixels.get_region(pixels.get_used_rect())
		var scale_value = 238.0 / maxi(pixels.get_width(), pixels.get_height())
		pixels.resize(roundi(pixels.get_width() * scale_value), roundi(pixels.get_height() * scale_value), Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(index % 3, row) * 256 + (Vector2i(256, 256) - pixels.get_size()) / 2)
	atlas.generate_mipmaps()
	return remember(key, "casualties-v1", atlas)

static func scenery_texture(name: String, index: int) -> Texture2D:
	var key = name + ":" + str(index)
	if textures.has(key):
		return textures[key]
	# Atlas regions include whole silhouettes; trim transparent margins to ground the roots and walls.
	var pixels = texture(name).get_image().get_region(SCENERY_REGIONS[name][index])
	pixels = pixels.get_region(pixels.get_used_rect())
	pixels.fix_alpha_edges()
	pixels.generate_mipmaps()
	textures[key] = ImageTexture.create_from_image(pixels)
	return textures[key]

static func texture(name: String, keyed: bool = false) -> Texture2D:
	if textures.has(name):
		return textures[name]
	if keyed and cached(name, name) != null: return textures[name]
	var source: Texture2D = load("res://assets/" + name + ".png")
	var pixels = source.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	if keyed:
		# Remove the original atlas backdrop before mip generation, as in the browser renderer.
		for y in pixels.get_height():
			for x in pixels.get_width():
				var c = pixels.get_pixel(x, y)
				if minf(c.r, c.b) - c.g > 0.035:
					pixels.set_pixel(x, y, Color(0, 0, 0, 0))
		pixels.fix_alpha_edges()
		pixels.premultiply_alpha()
	pixels.generate_mipmaps()
	if keyed: return remember(name, name, pixels)
	textures[name] = ImageTexture.create_from_image(pixels)
	return textures[name]
