package common

import "../input"
import "core:encoding/xml"
import "core:fmt"
import "core:os"
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
	Source: string `xml:"source,attr"`,
	Width:  int `xml:"width,attr"`,
	Height: int `xml:"height,attr"`,
}

Tileset :: struct {
	Image: Image `xml:"image"`,
}

load_tilesets :: proc(texs: ^map[string]rl.Texture2D, tilsets: []TileSet) -> bool {
	for t in tilsets {
		fname := strings.concatenate({"data/", t.source})
		doc, err := xml.load_from_file(fname)
		if err != xml.Error.None {
			fmt.panicf("Error loading XML:", err)
		}
		defer xml.destroy(doc)

		// Root element id is 0
		image_id, found := xml.find_child_by_ident(doc, 0, "image")
		if !found {
			fmt.println("No <image> element found")
			continue
		}

		src, ok := xml.find_attribute_val_by_key(doc, image_id, "source")
		if !ok {
			fmt.println("<image> has no 'source' attribute")
			continue
		}

		if src != "" {
			parts := strings.split(src, "/")
			fnameparts := strings.split(parts[len(parts) - 1], ".")
			load_tex(texs, "tiles", strings.join(parts[1:], "/"))

			fmt.printf("Image source: [%s] %s", fnameparts[0], strings.join(parts[1:], "/"))
		}
	}

	return true
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
