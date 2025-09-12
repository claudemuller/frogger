package common

import "../input"
import "../tiled"
import "core:encoding/json"
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
}

LayerType :: enum {
	TERRAIN,
	OBJECTS,
	ENEMIES,
	TRIGGERS,
	PLAYER,
	UI,
}
Level :: struct {
	enemy_speed: f32,
	enemies:     []Entity,
	tiles:       [NUM_TILES]u8,
	layers:      map[LayerType]int,
}

Memory :: struct {
	win_name:     cstring,
	is_running:   bool,
	currentLevel: u8,
	splash_timer: f32,
	state:        [2]State,
	textures:     map[string]rl.Texture2D,
	level:        Level,
	input:        input.Input,
	player:       Entity,
}

// Tileset :: struct {
// 	columns:     int,
// 	image:       string,
// 	imageheight: int,
// 	imagewidth:  int,
// 	margin:      int,
// 	name:        string,
// 	spacing:     int,
// 	tilecount:   int,
// 	tileheight:  int,
// 	tilewidth:   int,
// 	texture_id:  string,
// 	// type:        string, // enum - tileset
// 	// grid:        Grid,
// 	// tiles:       [dynamic]Tile,
// }

load_level :: proc(gmem: ^Memory, level: u8) -> bool {
	// TODO:(lukefilewalker) check if the file for "level" exists
	fname := "data/level1.json"

	jsonData, ok := os.read_entire_file(fname)
	if !ok {
		fmt.printf("error reading file: %s\n", fname)
		return false
	}

	level: tiled.Level
	if err := json.unmarshal(jsonData, &level); err != nil {
		fmt.printf("error unmarshalling level json data: %v\n", err)
		return false
	}

	tilesets := make([dynamic]tiled.Tileset, 0, len(level.tilesets))

	for t in level.tilesets {
		fname := strings.concatenate({"data/", t.source})
		jsonData, ok := os.read_entire_file(fname)
		if !ok {
			fmt.printf("error reading file: %s\n", fname)
			return false
		}

		tileset: tiled.Tileset
		if err := json.unmarshal(jsonData, &tileset); err != nil {
			fmt.printf("error unmarshalling tileset json data for %s: %v\n", fname, err)
			return false
		}

		append(&tilesets, tileset)
	}

	fmt.printf("\n\n%v\n\n", level)
	fmt.printf("\n\n%v\n\n", tilesets)


	return tiled_to_game_state(gmem, &level, tilesets)
}

tiled_to_game_state :: proc(
	gmem: ^Memory,
	level: ^tiled.Level,
	tilesets: [dynamic]tiled.Tileset,
) -> bool {
	// Load the tilesets' textures
	for tileset in tilesets {
		if tileset.image != "" {
			fnameparts := strings.split(tileset.image, "/")
			fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
			fname := strings.join(fnameparts[1:], "/")
			id := fparts[0]

			if ok := load_texture(&gmem.textures, id, fname); !ok {
				fmt.eprint("failed to load texture: %s\n", tileset.image)
			}

			// tileset.texture_id = id
		} else {
			for t in tileset.tiles {
				fnameparts := strings.split(tileset.image, "/")
				fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
				fname := strings.join(fnameparts[1:], "/")
				id := fparts[0]

				if ok := load_texture(&gmem.textures, id, fname); !ok {
					fmt.eprint("failed to load texture: %s\n", t.image)
				}

				// tileset.texture_id = id
			}
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

load_texture :: proc(texs: ^map[string]rl.Texture2D, id, fname: string) -> bool {
	// The original id gets corrupted due to id being the header to the backing array of the string - I guess :D
	id := strings.clone(id)
	texs[id] = rl.LoadTexture(strings.clone_to_cstring(fname))
	if texs[id].id == 0 {
		fmt.printf("error loading texture: %s", fname)
		return false
	}

	return true
}

get_texture :: proc(texs: map[string]rl.Texture2D, id: string) -> rl.Texture2D {
	t, ok := texs[id]
	if !ok {
		fmt.printf("failed to get texture: %s\n%v\n", id, texs)
		return texs["NO_TEXTURE"]
	}
	return t
}
