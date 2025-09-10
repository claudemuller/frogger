package common

import "core:fmt"
import "core:os"
import "core:strings"
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

Level :: struct {
	enemy_speed: f32,
	enemies:     []Entity,
	tiles:       [NUM_TILES]u8,
}

Memory :: struct {
	win_name:     cstring,
	is_running:   bool,
	currentLevel: u8,
	state:        [2]State,
	textures:     map[string]rl.Texture2D,
	levels:       []Level,
	input:        input.Input,
	player:       Entity,
}

State :: enum {
	START_UP,
	MAIN_MENU,
	LEVEL1,
	GAME_OVER,
	EXIT,
}

load_tex :: proc(texs: ^map[string]rl.Texture2D, n: string) {
	name := strings.concatenate({"res/", n, ".png"})
	texs[n] = rl.LoadTexture(strings.clone_to_cstring(name))
	if texs[n].id == 0 {
		fmt.printf("error loading texture: %s", name)
		os.exit(1)
	}
}
