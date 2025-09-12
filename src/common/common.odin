package common

import "../input"
import "core:encoding/xml"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

NUM_TILES_IN_ROW :: 28
NUM_TILES_IN_COL :: 16
NUM_TILES :: NUM_TILES_IN_COL * NUM_TILES_IN_ROW

SCALE :: 2
SRC_TILE_SIZE :: 32
TILE_SIZE :: SRC_TILE_SIZE * SCALE

WINDOW_WIDTH :: NUM_TILES_IN_ROW * TILE_SIZE
WINDOW_HEIGHT :: NUM_TILES_IN_COL * TILE_SIZE

Vec2 :: [2]f32
Vec2u :: [2]u32

Entity :: struct {
	pos:              Vec2,
	size:             Vec2u,
	tilepos:          [2]u8,
	vel:              Vec2,
	texture_id:       string,
	collider:         Vec2u,
	direction:        string,
	timer:            f32,
	backoff:          bool,
	backoff_duration: f32,
	// Tiled data
	id:               int,
	gid:              int,
	name:             string,
	type:             string, // should be enum
	x:                f32,
	y:                f32,
	width:            f32,
	height:           f32,
	rotation:         f32,
	visible:          bool,
	properties:       [dynamic]EntityProperty,
}

EntityType :: enum {
	ENEMY, // Enemy
	TRIGGER, // Trigger
}

EntityProperty :: struct {
	name:  string, // Speed
	type:  string, // float
	value: f32, // this changes based on the above type
}

ObjectType :: enum {
	TILE, //tilelayer
	OBJECT, // objectgroup
}
DrawOrder :: enum {
	TopDown, // topdown
}
RenderOrder :: enum {
	RIGHT_DOWN,
}

// Tiled data
Layer :: struct {
	id:        int,
	name:      string,
	type:      string, // should be enum
	visible:   bool,
	width:     int,
	x:         int,
	y:         int,
	draworder: string, // should be enum
	opacity:   f32,
	data:      [dynamic]int,
	objects:   [dynamic]Entity,
}

TileSet :: struct {
	firstgid: int,
	source:   string,
}

Level :: struct {
	enemy_speed: f32,
	enemies:     []Entity,
	tiles:       [NUM_TILES]u8,
	// Tiled data
	renderorder: string, // right-down - should be enum
	height:      int,
	width:       int,
	tile_height: int,
	tile_width:  int,
	type:        string, // map - should be enum
	orientation: string, // orthogonal - should be enum
	tilesets:    [dynamic]TileSet,
	layers:      [dynamic]Layer,
}

Memory :: struct {
	win_name:     cstring,
	is_running:   bool,
	currentLevel: u8,
	splash_timer: f32,
	state:        [2]State,
	textures:     map[string]rl.Texture2D,
	levels:       [dynamic]Level,
	input:        input.Input,
	player:       Entity,
}

Image :: struct {
	source: string,
	width:  int,
	height: int,
}

Tile :: struct {
	id:    int,
	image: Image,
}

GridOrientation :: enum {
	UNSPECIFIED,
	ORTHOGONAL,
	ISOMETRIC,
}

Grid :: struct {
	orientation: GridOrientation,
	width:       int,
	height:      int,
}

Tileset :: struct {
	name:        string,
	tile_width:  int,
	tile_height: int,
	tile_count:  int,
	columns:     int,
	grid:        Grid,
	image:       Image,
	tiles:       [dynamic]Tile,
}

load_tilesets :: proc(texs: ^map[string]rl.Texture2D, tilsets: []TileSet) -> bool {
	for t in tilsets {
		fmt.printf("-------------\nTilset: %v\n", t)

		if strings.contains(t.source, "tiles") do continue

		fname := strings.concatenate({"data/", t.source})
		doc, err := xml.load_from_file(fname)
		if err != xml.Error.None {
			fmt.panicf("Error loading XML:", err)
		}
		defer xml.destroy(doc)

		// tileset, ok := parseTileset(doc)
		// if !ok {
		tileset, ok := parseTiles(doc)
		if !ok {
			fmt.printf("failed to parse tileset: %s\n", t)
			return false
		}
		// }
		fmt.printf("%#v\n", tileset)

		// load_tex(texs, "tiles", strings.join(parts[1:], "/"))
	}

	return true
}

parseTilesetElem :: proc(doc: ^xml.Document) -> Tileset {
	name, tile_width, tile_height, tile_count, columns: string
	ok: bool

	tileset_id := u32(0)

	name, ok = xml.find_attribute_val_by_key(doc, tileset_id, "name")
	if !ok {
		fmt.println("<tileset> has no 'name' attribute")
	}
	tile_width, ok = xml.find_attribute_val_by_key(doc, tileset_id, "tilewidth")
	if !ok {
		fmt.println("<tileset> has no 'tilewidth' attribute")
	}
	tile_height, ok = xml.find_attribute_val_by_key(doc, tileset_id, "tileheight")
	if !ok {
		fmt.println("<tileset> has no 'tileheight' attribute")
	}
	tile_count, ok = xml.find_attribute_val_by_key(doc, tileset_id, "tilecount")
	if !ok {
		fmt.println("<tileset> has no 'tilecount' attribute")
	}
	columns, ok = xml.find_attribute_val_by_key(doc, tileset_id, "columns")
	if !ok {
		fmt.println("<tileset> has no 'columns' attribute")
	}

	return Tileset {
		name = name,
		tile_width = strconv.atoi(tile_width),
		tile_height = strconv.atoi(tile_height),
		tile_count = strconv.atoi(tile_count),
		columns = strconv.atoi(columns),
	}
}

parseImageElem :: proc(doc: ^xml.Document, parent_id: u32) -> (Image, bool) {
	image_id: u32
	ok: bool

	image_id, ok = xml.find_child_by_ident(doc, parent_id, "image")
	if !ok {
		fmt.println("No <image> element found")
		return Image{}, false
	}

	source, width, height: string

	source, ok = xml.find_attribute_val_by_key(doc, image_id, "source")
	if !ok {
		fmt.println("<image> has no 'source' attribute")
	}
	width, ok = xml.find_attribute_val_by_key(doc, image_id, "width")
	if !ok {
		fmt.println("<image> has no 'width' attribute")
	}
	height, ok = xml.find_attribute_val_by_key(doc, image_id, "height")
	if !ok {
		fmt.println("<image> has no 'height' attribute")
	}

	return Image{source = source, width = strconv.atoi(width), height = strconv.atoi(height)}, true
}

parseTileset :: proc(doc: ^xml.Document) -> (Tileset, bool) {
	tileset := parseTilesetElem(doc)

	// The root element
	tileset_id := u32(0)
	image, ok := parseImageElem(doc, tileset_id)
	if !ok {
		return Tileset{}, false
	}

	tileset.image = image

	return tileset, true
}

parseTiles :: proc(doc: ^xml.Document) -> (Tileset, bool) {
	tileset := parseTilesetElem(doc)

	tiles: [dynamic]Tile
	image_id, tile_id: u32
	ok: bool

	// The root element
	tileset_id := u32(0)

	i: int
	for {
		tile_id, ok = xml.find_child_by_ident(doc, tileset_id, "tile", i)
		if !ok {
			fmt.printf("no <tile> found at %d\n", i)
			break
		}

		id: string
		id, ok = xml.find_attribute_val_by_key(doc, tile_id, "id")
		if !ok {
			fmt.println("<tile> has no 'id' attribute")
		}

		image, ok := parseImageElem(doc, tile_id)
		if !ok {
			fmt.printf("no <image> found at tile %d\n", i)
			break
		}

		append(&tileset.tiles, Tile{id = strconv.atoi(id), image = image})
		i += 1
	}

	return tileset, true
}

State :: enum {
	SPLASH,
	MAIN_MENU,
	PLAYING,
	GAME_OVER,
}

get_state :: proc(gmem: ^Memory) -> State {
	return gmem.state[0]
}

get_prev_state :: proc(gmem: ^Memory) -> State {
	return gmem.state[1]
}

push_state :: proc(gmem: ^Memory, state: State) {
	temp_state := gmem.state[0]
	gmem.state[0] = state
	gmem.state[1] = temp_state
}

load_tex :: proc(texs: ^map[string]rl.Texture2D, id, fname: string) {
	texs[id] = rl.LoadTexture(strings.clone_to_cstring(fname))
	if texs[id].id == 0 {
		fmt.printf("error loading texture: %s", fname)
		os.exit(1)
	}
}

get_tex :: proc(texs: map[string]rl.Texture2D, n: string) -> rl.Texture2D {
	t, ok := texs[n]
	if !ok {
		fmt.printf("failed to get texture: %s\n", n)
		return texs["NO_TEXTURE"]
	}
	return t
}
