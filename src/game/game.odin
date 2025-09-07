package game

import "core:fmt"
import "core:math"
import "../input"
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

Player :: struct {
	pos: [2]f32,
	tilepos: [2]u8,
	vel: [2]f32,
}
Memory :: struct {
	win_name:   cstring,
	is_running: bool,
	state:      [2]State,
	tiles:      []u8,
	player:     Player,
	input:      input.Input,
}
gmem: Memory

new :: proc(win_name: cstring) -> ^Memory {
	init(win_name)
	return &gmem
}

init :: proc(win_name: cstring) {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, cstring(win_name))

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	setup()

	gmem.is_running = true
	push_state(&gmem, .START_UP)
}

setup :: proc() {
	gmem.tiles = make([]u8, NUM_TILES)

	midway_x_tile := u8(NUM_TILES_IN_ROW*0.5)
	bottom_y_tile := u8(NUM_TILES_IN_COL)
	gmem.player = Player{
		pos = {
			f32(midway_x_tile)*TILE_SIZE,
			f32(bottom_y_tile)*TILE_SIZE,
		},
		tilepos = {midway_x_tile, bottom_y_tile},
	}
}

run :: proc() {
	fmt.println(gmem.is_running)
	for !rl.WindowShouldClose() {
		input.process(&gmem.input)
		update()
		render()
	}
}

process_input :: proc() {
}

update :: proc() {
	gmem.player.vel = 0.0

	if .UP in gmem.input.kb.btns do gmem.player.vel.y = -PLAYER_SPEED
	if .DOWN in gmem.input.kb.btns do gmem.player.vel.y = PLAYER_SPEED
	if .LEFT in gmem.input.kb.btns do gmem.player.vel.x = -PLAYER_SPEED
	if .RIGHT in gmem.input.kb.btns do gmem.player.vel.x = PLAYER_SPEED

	gmem.player.pos += gmem.player.vel

    if gmem.player.pos.x < 0 do gmem.player.pos.x = 0 
    if gmem.player.pos.x > (WINDOW_WIDTH-TILE_SIZE) do gmem.player.pos.x = WINDOW_WIDTH - TILE_SIZE 
    if gmem.player.pos.y < 0 do gmem.player.pos.y = 0 
    if gmem.player.pos.y > (WINDOW_HEIGHT-TILE_SIZE) do gmem.player.pos.y = WINDOW_HEIGHT - TILE_SIZE 

    gmem.player.tilepos.x = u8(gmem.player.pos.x / TILE_SIZE)
    gmem.player.tilepos.y = u8(gmem.player.pos.y / TILE_SIZE)

	fmt.printf("%v\n", gmem.player)
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	for t, i in gmem.tiles {
		x := i32(i % NUM_TILES_IN_ROW) * TILE_SIZE
		y := i32(i / NUM_TILES_IN_ROW) * TILE_SIZE

		colour := rl.GRAY

		if t == 0 {
			colour = rl.DARKGRAY
		}

		rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, colour)
		rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.GRAY)
	}

	rl.DrawRectangle(
		i32(gmem.player.tilepos.x) * TILE_SIZE, i32(gmem.player.tilepos.y) * TILE_SIZE,
		// i32(gmem.player.pos.x), i32(gmem.player.pos.y),
		TILE_SIZE, TILE_SIZE,
		rl.GREEN,
	)

	rl.EndDrawing()
}

destroy :: proc() {
	rl.CloseWindow()
}

State :: enum {
	START_UP,
	MAIN_MENU,
	LEVEL1,
	GAME_OVER,
	EXIT,
}

get_state :: proc(game_mem: Memory) -> State {
	return gmem.state[0]
}

get_prev_state :: proc(game_mem: Memory) -> State {
	return gmem.state[1]
}

push_state :: proc(game_mem: ^Memory, state: State) {
	temp_state := gmem.state[0]
	gmem.state[0] = state
	gmem.state[1] = temp_state
}
