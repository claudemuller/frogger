package common

import "../input"
import "../tiled"
import "../utils"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

HAS_LEVEL_DEBUG :: #config(DEBUG, false)

NUM_TILES_IN_ROW :: 28
NUM_TILES_IN_COL :: 16
NUM_TILES :: NUM_TILES_IN_COL * NUM_TILES_IN_ROW

SCALE :: 2
SRC_TILE_SIZE :: 32
TILE_SIZE :: SRC_TILE_SIZE * SCALE

WINDOW_WIDTH :: NUM_TILES_IN_ROW * TILE_SIZE
WINDOW_HEIGHT :: NUM_TILES_IN_COL * TILE_SIZE

H_FLIP :: 0x80000000
V_FLIP :: 0x40000000
D_FLIP :: 0x20000000
ID_MASK :: 0x1FFFFFFF

Vec2 :: [2]f32
Vec2u :: [2]u32
Vec2i :: [2]i32

Entity :: struct {
	pos:              Vec2,
	size:             Vec2i,
	srcpos:           Vec2i,
	vel:              Vec2,
	texture_id:       string,
	collider:         Vec2i,
	rotation:         f32,
	fliph:            bool,
	flipv:            bool,
	flipd:            bool,
	type:             string,
	name:             string,
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

ObjectType :: enum {
	TILE, //tilelayer
	OBJECT, // objectgroup
}

DrawOrder :: enum {
	TOPDOWN, // topdown
}

RenderOrder :: enum {
	RIGHT_DOWN,
}

EntityType :: enum {
	ENEMY, // Enemy
	TRIGGER, // Trigger
}

Level :: struct {
	tile_width:    int,
	tile_height:   int,
	num_tiles_row: int,
	num_tiles_col: int,
	enemy_speed:   f32,
	layers:        map[LayerType]Layer,
}

Layer :: struct {
	visible:  bool,
	tiles:    ^[dynamic]Tile,
	entities: ^[dynamic]Entity,
	triggers: ^[dynamic]Trigger,
}

Trigger :: struct {
	pos:  Vec2,
	size: Vec2i,
	name: string,
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
	currentLevel: u8,
	splash_timer: utils.Timer,
	memctr:       f64,
	state:        [2]State,
	textures:     map[string]rl.Texture2D,
	level:        Level,
	input:        input.Input,
	player:       Entity,
	sound:        map[string]rl.Sound,
	music:        map[string]rl.Music,
	fonts:        map[string]rl.Font,
}

load_level :: proc(gmem: ^Memory, level_n: u8) -> bool {
	// Load player
	// midway_x_tile := u8(common.NUM_TILES_IN_ROW * 0.5)
	// bottom_y_tile := u8(common.NUM_TILES_IN_COL)
	// gmem.player = common.Entity {
	// 	pos     = {f32(midway_x_tile) * common.TILE_SIZE, f32(bottom_y_tile) * common.TILE_SIZE},
	// 	tilepos = {midway_x_tile, bottom_y_tile},
	// 	size    = {20, 20},
	// }
	gmem.player.texture_id = "player"
	load_texture(&gmem.textures, gmem.player.texture_id, "res/frogger.png")
	gmem.player.pos = {WINDOW_WIDTH / 4, WINDOW_HEIGHT / 2 - 32}
	gmem.player.size = {32, 32}
	gmem.player.collider = {32, 32}

	strbuf := make([]byte, 5)
	n := strconv.itoa(strbuf, int(level_n))
	fname := strings.concatenate({"data/level", n, ".json"})
	delete(strbuf)

	fname = "data/debug-level.json"

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
	}

	// Load the tilesets' textures
	for firstgid, &tileset in tilesets {
		if tileset.image != "" {
			fnameparts := strings.split(tileset.image, "/")
			fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
			fname := strings.join(fnameparts[1:], "/")
			id := fparts[0]

			if ok := load_texture(&gmem.textures, id, fname); !ok {
				fmt.eprint("failed to load texture: %s\n", tileset.image)
			}

			tileset.texture_id = strings.clone(id)
		} else {
			for &t in tileset.tiles {
				fnameparts := strings.split(t.image, "/")
				fparts := strings.split(fnameparts[len(fnameparts) - 1], ".")
				fname := strings.join(fnameparts[1:], "/")
				id := fparts[0]

				if ok := load_texture(&gmem.textures, id, fname); !ok {
					fmt.eprint("failed to load texture: %s\n", t.image)
				}

				t.texture_id = strings.clone(id)
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
				gid := t & ID_MASK
				fliph := (t & H_FLIP) != 0
				flipv := (t & V_FLIP) != 0
				flipd := (t & D_FLIP) != 0

				w := i32(tilesets[l.id].tilewidth)
				h := i32(tilesets[l.id].tileheight)
				x := i32(i % l.width) * w
				y := i32(i / l.width) * h
				srcx := i32((gid - 1) % gmem.level.num_tiles_row) * w
				srcy := i32((gid - 1) / gmem.level.num_tiles_row) * h

				append(
					gmem.level.layers[.TERRAIN].tiles,
					Tile {
						pos = {x, y},
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
				visible  = l.visible,
				entities = new([dynamic]Entity),
			}

			for o, i in l.objects {
				gid := o.gid & ID_MASK
				fliph := (o.gid & H_FLIP) != 0
				flipv := (o.gid & V_FLIP) != 0
				flipd := (o.gid & D_FLIP) != 0

				texid: int
				for id in tilesets {
					if gid >= id {
						texid = id
						gid -= id
						break
					}
				}

				w := i32(o.width)
				h := i32(o.height)
				num_tiles_row := tilesets[texid].imagewidth / tilesets[texid].tilewidth
				srcx := i32((gid) % num_tiles_row) * w
				srcy := i32((gid) / num_tiles_row) * h

				texture_id := tilesets[texid].texture_id
				if texture_id == "" {
					for t in tilesets[texid].tiles {
						if t.id == gid {
							texture_id = t.texture_id
						}
					}
				}

				append(
					gmem.level.layers[.OBJECTS].entities,
					Entity {
						pos        = {o.x, o.y - f32(h)}, // Compensate on y because 0,0 is bottom left of sprite in Tiled
						size       = {w, h},
						srcpos     = {srcx, srcy},
						rotation   = o.rotation,
						name       = o.name,
						type       = o.type,
						texture_id = texture_id,
					},
				)
			}

		case "Entities":
			gmem.level.layers[.ENEMIES] = {
				visible  = l.visible,
				entities = new([dynamic]Entity),
			}
			gmem.level.layers[.TRIGGERS] = {
				triggers = new([dynamic]Trigger),
			}

			for o in l.objects {
				if o.type == "Enemy" {
					gid := o.gid & ID_MASK
					fliph := (o.gid & H_FLIP) != 0
					flipv := (o.gid & V_FLIP) != 0
					flipd := (o.gid & D_FLIP) != 0

					keys, err := slice.map_keys(tilesets)
					slice.reverse_sort(keys)
					if err != nil {
						fmt.panicf("borked")
					}

					texid: int
					for id in keys {
						if gid >= id {
							texid = id
							gid -= id
							break
						}
					}

					w := i32(o.width)
					h := i32(o.height)

					texture_id := tilesets[texid].texture_id
					if texture_id == "" {
						for t in tilesets[texid].tiles {
							if t.id == gid {
								texture_id = t.texture_id
								break
							}
						}
					}

					when HAS_LEVEL_DEBUG {
						if o.name == "Car" && texture_id == "tiles" {
							fmt.println("tilesets:")
							for k, v in tilesets {
								fmt.printf("%v: %v\n", k, v)
							}
							fmt.println("textures:")
							for k, v in tilesets {
								fmt.printf("%v: %v\n", k, v)
							}
							fmt.printf("o: %v\n", o)
							fmt.printf(
								"texid: %v\nogid: %v\ngid: %v\netxture_id: %v\n",
								texid,
								o.gid & ID_MASK,
								gid,
								texture_id,
							)
							os.exit(1)
						}
					}

					vel: Vec2
					for p in o.properties {
						if p.name == "Speed" {
							vel.x = p.value
							if !fliph {
								vel.x *= -1
							}
						}
					}

					append(
						gmem.level.layers[.ENEMIES].entities,
						Entity {
							pos        = {o.x, o.y - f32(h)}, // Compensate on y because 0,0 is bottom left of sprite in Tiled
							size       = {w, h},
							collider   = {w, h},
							srcpos     = {0, 0},
							vel        = vel,
							rotation   = o.rotation,
							fliph      = fliph,
							flipv      = flipv,
							flipd      = flipd,
							name       = o.name,
							type       = o.type,
							texture_id = texture_id,
						},
					)
				}

				if o.type == "Trigger" {
					w := i32(o.width)
					h := i32(o.height)

					append(
						gmem.level.layers[.TRIGGERS].triggers,
						Trigger {
							pos  = {o.x, o.y - f32(h)}, // Compensate on y because 0,0 is bottom left of sprite in Tiled
							size = {w, h},
							name = o.name,
						},
					)
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
	WINNER,
	GAME_OVER,
	SHUTDOWN,
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
