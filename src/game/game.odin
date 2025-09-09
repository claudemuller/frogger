package game

import "../input"
import "core:encoding/json"
import "core:fmt"
import "core:math"
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

PLAYER_SPEED :: 5

Vec2 :: [2]f32

Entity :: struct {
	pos:     Vec2,
	tilepos: [2]u8,
	vel:     Vec2,
}

Memory :: struct {
	win_name:   cstring,
	is_running: bool,
	state:      [2]State,
	levels:     []Level,
	input:      input.Input,
	player:     Entity,
	enemies:    []Entity,
}

Level :: struct {
	tiles: [NUM_TILES]u8,
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

	RawEntity :: struct {
		pos: []string,
		vel: []f32,
	}
	Data :: struct {
		enemies: []RawEntity,
		tiles:   [NUM_TILES]u8,
	}

	d: Data
	err := json.unmarshal(jsonData, &d)
	if err != nil {
		fmt.printf("%v\n", err)
		return
	}
	gmem.levels = make([]Level, 1)
	gmem.levels[0].tiles = d.tiles

	gmem.enemies = make([]Entity, 6)
	gmem.enemies[0] = Entity {
		pos = {8 * TILE_SIZE, 3 * TILE_SIZE},
		vel = {1.23, 0},
	}
	gmem.enemies[1] = Entity {
		pos = {(NUM_TILES_IN_ROW - 3) * TILE_SIZE, 4 * TILE_SIZE},
		vel = {-1.3, 0},
	}
	gmem.enemies[2] = Entity {
		pos = {2 * TILE_SIZE, 7 * TILE_SIZE},
		vel = {1.1, 0},
	}
	gmem.enemies[3] = Entity {
		pos = {(NUM_TILES_IN_ROW - 10) * TILE_SIZE, 8 * TILE_SIZE},
		vel = {-1.1, 0},
	}
	gmem.enemies[4] = Entity {
		pos = {16 * TILE_SIZE, 11 * TILE_SIZE},
		vel = {1.3, 0},
	}
	gmem.enemies[5] = Entity {
		pos = {(NUM_TILES_IN_ROW - 2) * TILE_SIZE, 12 * TILE_SIZE},
		vel = {-1.23, 0},
	}


	midway_x_tile := u8(NUM_TILES_IN_ROW * 0.5)
	bottom_y_tile := u8(NUM_TILES_IN_COL)
	gmem.player = Entity {
		pos     = {f32(midway_x_tile) * TILE_SIZE, f32(bottom_y_tile) * TILE_SIZE},
		tilepos = {midway_x_tile, bottom_y_tile},
	}

	// os.exit(0)
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
	for &e in gmem.enemies {
		e.pos += e.vel
		if e.pos.x < -TILE_SIZE do e.pos.x = WINDOW_WIDTH
		if e.pos.x > WINDOW_WIDTH do e.pos.x = -TILE_SIZE
	}
}

render :: proc(gmem: ^Memory) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	for t, i in gmem.levels[0].tiles {
		x := i32(i % NUM_TILES_IN_ROW) * TILE_SIZE
		y := i32(i / NUM_TILES_IN_ROW) * TILE_SIZE

		colour := rl.GRAY

		if t == 0 {
			colour = rl.GREEN
		}
		if t == 1 {
			colour = rl.LIGHTGRAY
		}
		if t == 2 {
			colour = rl.BLACK
		}

		rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, colour)
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.GRAY)
	}

	rl.DrawRectangle(
		i32(gmem.player.tilepos.x) * TILE_SIZE,
		i32(gmem.player.tilepos.y) * TILE_SIZE,
		// i32(gmem.player.pos.x), i32(gmem.player.pos.y),
		TILE_SIZE,
		TILE_SIZE,
		rl.BLUE,
	)

	for e in gmem.enemies {
		rl.DrawRectangle(i32(e.pos.x), i32(e.pos.y), TILE_SIZE, TILE_SIZE, rl.RED)
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
