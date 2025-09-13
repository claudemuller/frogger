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
Vec2i :: [2]i32

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
	tile_width:    int,
	tile_height:   int,
	num_tiles_row: int,
	num_tiles_col: int,
	enemy_speed:   f32,
	enemies:       []Entity,
	layers:        map[LayerType]Layer,
}

Layer :: struct {
	visible: bool,
	tiles:   ^[dynamic]Tile,
}

Tile :: struct {
	pos:        Vec2i,
	size:       Vec2i,
	srcpos:     Vec2i,
	fliph:      bool,
	flipv:      bool,
	flipd:      bool,
	texture_id: string,
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

load_level :: proc(gmem: ^Memory, level: u8) -> bool {
	// TODO:(lukefilewalker) check if the file for "level" exists
	fname := "data/level1.json"

	// Load level data
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

	// Load tileset data
	tilesets := make(map[int]tiled.Tileset, len(level.tilesets))

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

		tilesets[t.firstgid] = tileset

		// append(&tilesets, tileset)
	}

	// Load the tilesets' textures
	for firstgid, &tileset in tilesets {
		if tileset.image != "" {
			fnameparts := strings.split(tileset.image, "/")
			fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
			fname := strings.join(fnameparts[1:], "/")
			id := fparts[0]
			fmt.printf("%v\n", id)

			if ok := load_texture(&gmem.textures, id, fname); !ok {
				fmt.eprint("failed to load texture: %s\n", tileset.image)
			}

			tileset.texture_id = strings.clone(id)
		} else {
			for t in tileset.tiles {
				fnameparts := strings.split(t.image, "/")
				fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
				fname := strings.join(fnameparts[1:], "/")
				id := fparts[0]
				fmt.printf("%v\n", id)

				if ok := load_texture(&gmem.textures, id, fname); !ok {
					fmt.eprint("failed to load texture: %s\n", t.image)
				}

				tileset.texture_id = strings.clone(id)
			}
		}
	}

	return tiled_to_game_state(gmem, &level, tilesets)
}

tiled_to_game_state :: proc(
	gmem: ^Memory,
	level: ^tiled.Level,
	tilesets: map[int]tiled.Tileset,
) -> bool {
	gmem.level.tile_width = level.tilewidth
	gmem.level.tile_height = level.tileheight
	gmem.level.num_tiles_row = level.width
	gmem.level.num_tiles_col = level.height

	for l in level.layers {
		switch l.name {
		case "Terrain":
			num_tiles := l.width * l.height
			gmem.level.layers[.TERRAIN] = {
				visible = l.visible,
				tiles   = new([dynamic]Tile),
			}

			for t, i in l.data {
				H_FLIP := 0x80000000
				V_FLIP := 0x40000000
				D_FLIP := 0x20000000
				ID_MASK := 0x1FFFFFFF

				gid := t & ID_MASK
				fliph := (t & H_FLIP) != 0
				flipv := (t & V_FLIP) != 0
				flipd := (t & D_FLIP) != 0

				w := i32(tilesets[l.id].tilewidth)
				h := i32(tilesets[l.id].tileheight)
				x := i32(i % l.width) * w
				y := i32(i / l.width) * h
				srcx := i32((gid - 1) % l.width) * w
				srcy := i32((gid - 1) / l.width) * h

				a := tilesets[l.id]
				b := a.texture_id

				append(
					gmem.level.layers[.TERRAIN].tiles,
					Tile {
						pos = {x * SCALE, y * SCALE},
						size = {w, h},
						srcpos = {srcx, srcy},
						fliph = fliph,
						flipv = flipv,
						flipd = flipd,
						texture_id = tilesets[l.id].texture_id,
					},
				)
			}

		case "Obstacles":
			gmem.level.layers[.OBJECTS] = {
				visible = l.visible,
			}

		case "Entities":
			for e in l.objects {
				if e.type == "Enemy" {
					gmem.level.layers[.ENEMIES] = {
						visible = l.visible,
					}
				}

				if e.type == "Trigger" {
					gmem.level.layers[.TRIGGERS] = {
						visible = l.visible,
					}
				}
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
	if id == "" {
		fmt.printf("failed to get texture: '%s'\n%v\n", id, texs)
		return texs["NO_TEXTURE"]
	}

	t, ok := texs[id]
	if !ok {
		fmt.printf("failed to get texture: '%s'\n%v\n", id, texs)
		return texs["NO_TEXTURE"]
	}

	return t
}
