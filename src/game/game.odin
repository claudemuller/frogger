package game

import "../input"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
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

PLAYER_SPEED :: 5

Vec2 :: [2]f32
Vec2u :: [2]u32

Entity :: struct {
	pos:        Vec2,
	tilepos:    [2]u8,
	vel:        Vec2,
	texture_id: string,
	size:       Vec2u,
	direction:  string,
}

Memory :: struct {
	win_name:   cstring,
	is_running: bool,
	state:      [2]State,
	textures:   map[string]rl.Texture2D,
	levels:     []Level,
	input:      input.Input,
	player:     Entity,
}

Level :: struct {
	enemy_speed: f32,
	enemies:     []Entity,
	tiles:       [NUM_TILES]u8,
}

init :: proc(win_name: cstring) -> ^Memory {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, cstring(win_name))

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	gmem := new(Memory)
	setup(gmem)

	gmem.is_running = true
	push_state(gmem, .START_UP)

	return gmem
}

setup :: proc(gmem: ^Memory) {
	jsonData, ok := os.read_entire_file("data/level1.json")
	if !ok {
		fmt.println("error reading file")
		return
	}

	gmem.levels = make([]Level, 1)
	if err := json.unmarshal(jsonData, &gmem.levels[0]); err != nil {
		fmt.printf("error unmarshalling json data: %v\n", err)
		return
	}

	load_tex(&gmem.textures, "semi-tractor")
	load_tex(&gmem.textures, "sedan")
	load_tex(&gmem.textures, "tiles")

	midway_x_tile := u8(NUM_TILES_IN_ROW * 0.5)
	bottom_y_tile := u8(NUM_TILES_IN_COL)
	gmem.player = Entity {
		pos     = {f32(midway_x_tile) * TILE_SIZE, f32(bottom_y_tile) * TILE_SIZE},
		tilepos = {midway_x_tile, bottom_y_tile},
	}
}

load_tex :: proc(texs: ^map[string]rl.Texture2D, n: string) {
	name := strings.concatenate({"res/", n, ".png"})
	texs[n] = rl.LoadTexture(strings.clone_to_cstring(name))
	if texs[n].id == 0 {
		fmt.printf("error loading texture: %s", name)
		os.exit(1)
	}
}

run :: proc(gmem: ^Memory) {
	for !rl.WindowShouldClose() {
		input.process(&gmem.input)
		update(gmem)
		render(gmem)
	}
}

update :: proc(gmem: ^Memory) {
	// Update player
	gmem.player.vel = 0.0

	if .UP in gmem.input.kb.btns do gmem.player.vel.y = -PLAYER_SPEED
	if .DOWN in gmem.input.kb.btns do gmem.player.vel.y = PLAYER_SPEED
	if .LEFT in gmem.input.kb.btns do gmem.player.vel.x = -PLAYER_SPEED
	if .RIGHT in gmem.input.kb.btns do gmem.player.vel.x = PLAYER_SPEED

	gmem.player.pos += gmem.player.vel

	if gmem.player.pos.x < 0 do gmem.player.pos.x = 0
	if gmem.player.pos.x > (WINDOW_WIDTH - TILE_SIZE) do gmem.player.pos.x = WINDOW_WIDTH - TILE_SIZE
	if gmem.player.pos.y < 0 do gmem.player.pos.y = 0
	if gmem.player.pos.y > (WINDOW_HEIGHT - TILE_SIZE) do gmem.player.pos.y = WINDOW_HEIGHT - TILE_SIZE

	gmem.player.tilepos.x = u8(gmem.player.pos.x / TILE_SIZE)
	gmem.player.tilepos.y = u8(gmem.player.pos.y / TILE_SIZE)

	// Update enemies
	for &e in gmem.levels[0].enemies {
		e.pos += e.vel
		if e.pos.x < -TILE_SIZE do e.pos.x = WINDOW_WIDTH
		if e.pos.x > WINDOW_WIDTH do e.pos.x = -TILE_SIZE
	}
}

render :: proc(gmem: ^Memory) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	for t, i in gmem.levels[0].tiles {
		x := f32(i % NUM_TILES_IN_ROW) * TILE_SIZE
		y := f32(i / NUM_TILES_IN_ROW) * TILE_SIZE

		src := rl.Rectangle {
			width  = TILE_SIZE,
			height = TILE_SIZE,
		}
		dest := rl.Rectangle {
			x      = x,
			y      = y,
			width  = TILE_SIZE * SCALE,
			height = TILE_SIZE * SCALE,
		}

		switch t {
		// Sidewalk
		case 0:
			src.x = 32
			src.y = 0
		case 1:
			src.x = 32
			src.y = 0
			src.height *= -1

		// Grass
		case 2:
			src.x = 64
			src.y = 0
			src.height *= -1
		case 3:
			src.x = 64
			src.y = 0

		// Road
		case 4:
			src.x = 0
			src.y = 0
		case 5:
			src.x = 0
			src.y = 0
		}

		rl.DrawTexturePro(gmem.textures["tiles"], src, dest, {0, 0}, 0, rl.WHITE)
		// rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.GRAY)
	}

	rl.DrawRectangle(
		i32(gmem.player.tilepos.x) * TILE_SIZE,
		i32(gmem.player.tilepos.y) * TILE_SIZE,
		// i32(gmem.player.pos.x), i32(gmem.player.pos.y),
		TILE_SIZE,
		TILE_SIZE,
		rl.BLUE,
	)

	for e in gmem.levels[0].enemies {
		src := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = f32(e.size[1]),
			height = f32(e.size[0]),
		}
		if e.direction == "ltr" {
			src.width *= -1
		}
		dest := rl.Rectangle {
			x      = e.pos.x,
			y      = e.pos.y,
			width  = f32(e.size[1]) * SCALE,
			height = f32(e.size[0]) * SCALE,
		}

		tex, ok := gmem.textures[e.texture_id]
		if !ok {
			fmt.printf("texture not found: %s\n", e.texture_id)
		}

		rl.DrawTexturePro(tex, src, dest, {0, 0}, 0, rl.WHITE)

		when HAS_LEVEL_DEBUG {
			rl.DrawRectangleLines(
				i32(e.pos.x),
				i32(e.pos.y),
				i32(e.size[1] * 2),
				i32(e.size[0] * 2),
				rl.RED,
			)
		}
		// rl.DrawRectangle(i32(e.pos.x), i32(e.pos.y), TILE_SIZE, TILE_SIZE, rl.RED)
	}

	rl.EndDrawing()
}

destroy :: proc(gmem: ^Memory) {
	free(gmem)
	rl.CloseWindow()
}

State :: enum {
	START_UP,
	MAIN_MENU,
	LEVEL1,
	GAME_OVER,
	EXIT,
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
