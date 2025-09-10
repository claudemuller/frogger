package game

import "../common"
import "../input"
import "../ui"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

HAS_LEVEL_DEBUG :: #config(DEBUG, false)


PLAYER_SPEED :: 5

init :: proc(win_name: cstring) -> ^common.Memory {
	rl.InitWindow(common.WINDOW_WIDTH, common.WINDOW_HEIGHT, cstring(win_name))

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	gmem := new(common.Memory)
	setup(gmem)

	gmem.is_running = true
	gmem.splash_timer = 2.0
	common.push_state(gmem, .SPLASH)

	return gmem
}

setup :: proc(gmem: ^common.Memory) {
	jsonData, ok := os.read_entire_file("data/level1.json")
	if !ok {
		fmt.println("error reading file")
		return
	}

	gmem.levels = make([]common.Level, 1)
	if err := json.unmarshal(jsonData, &gmem.levels[0]); err != nil {
		fmt.printf("error unmarshalling json data: %v\n", err)
		return
	}

	ui.setup(gmem)

	redpx := rl.GenImageColor(1, 1, rl.RED)
	redtex := rl.LoadTextureFromImage(redpx)
	rl.UnloadImage(redpx)
	gmem.textures["NO_TEXTURE"] = redtex

	common.load_tex(&gmem.textures, "semi-tractor")
	common.load_tex(&gmem.textures, "sedan-grey")
	common.load_tex(&gmem.textures, "sedan-purple")
	common.load_tex(&gmem.textures, "sedan-green")
	common.load_tex(&gmem.textures, "hatch-back-green")
	common.load_tex(&gmem.textures, "hatch-back-yellow")
	common.load_tex(&gmem.textures, "hatch-back-blue")
	common.load_tex(&gmem.textures, "tiles")

	midway_x_tile := u8(common.NUM_TILES_IN_ROW * 0.5)
	bottom_y_tile := u8(common.NUM_TILES_IN_COL)
	gmem.player = common.Entity {
		pos     = {f32(midway_x_tile) * common.TILE_SIZE, f32(bottom_y_tile) * common.TILE_SIZE},
		tilepos = {midway_x_tile, bottom_y_tile},
		size    = {20, 20},
	}
}

getCurrentLevel :: proc(gmem: ^common.Memory) -> ^common.Level {
	return &gmem.levels[gmem.currentLevel]
}


run :: proc(gmem: ^common.Memory) {
	for !rl.WindowShouldClose() {
		input.process(&gmem.input)
		update(gmem)
		render(gmem)
	}
}

update :: proc(gmem: ^common.Memory) {
	// Update UI
	if ui.update(gmem) {
		return
	}

	switch common.get_state(gmem) {
	case .SPLASH:
		if .LEFT in gmem.input.mouse.btns || .SPACE in gmem.input.kb.btns {
			common.push_state(gmem, .MAIN_MENU)
		}

		if gmem.splash_timer <= 0 {
			common.push_state(gmem, .MAIN_MENU)
		}
		gmem.splash_timer -= rl.GetFrameTime()

	case .MAIN_MENU:
		if .LEFT in gmem.input.mouse.btns || .SPACE in gmem.input.kb.btns {
			common.push_state(gmem, .PLAYING)
		}

	case .PLAYING:
		// Update player
		gmem.player.vel = 0.0

		if .UP in gmem.input.kb.btns do gmem.player.vel.y = -PLAYER_SPEED
		if .DOWN in gmem.input.kb.btns do gmem.player.vel.y = PLAYER_SPEED
		if .LEFT in gmem.input.kb.btns do gmem.player.vel.x = -PLAYER_SPEED
		if .RIGHT in gmem.input.kb.btns do gmem.player.vel.x = PLAYER_SPEED

		gmem.player.pos += gmem.player.vel

		if gmem.player.pos.x < 0 do gmem.player.pos.x = 0
		if gmem.player.pos.x > (common.WINDOW_WIDTH - common.TILE_SIZE) do gmem.player.pos.x = common.WINDOW_WIDTH - common.TILE_SIZE
		if gmem.player.pos.y < 0 do gmem.player.pos.y = 0
		if gmem.player.pos.y > (common.WINDOW_HEIGHT - common.TILE_SIZE) do gmem.player.pos.y = common.WINDOW_HEIGHT - common.TILE_SIZE

		gmem.player.tilepos.x = u8(gmem.player.pos.x / common.TILE_SIZE)
		gmem.player.tilepos.y = u8(gmem.player.pos.y / common.TILE_SIZE)

		playerRect := rl.Rectangle {
			x      = gmem.player.pos.x,
			y      = gmem.player.pos.y,
			width  = f32(gmem.player.size[0]),
			height = f32(gmem.player.size[1]),
		}

		// Update enemies
		for &e in getCurrentLevel(gmem).enemies {
			e.pos += e.vel
			if e.pos.x < -common.TILE_SIZE do e.pos.x = common.WINDOW_WIDTH
			if e.pos.x > common.WINDOW_WIDTH do e.pos.x = -common.TILE_SIZE

			eRect := rl.Rectangle {
				x      = e.pos.x,
				y      = e.pos.y,
				width  = f32(e.size[0]),
				height = f32(e.size[1]),
			}

			if rl.CheckCollisionRecs(playerRect, eRect) {
				fmt.println("collision")
			}
		}

	case .GAME_OVER:
	}
}

render :: proc(gmem: ^common.Memory) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch common.get_state(gmem) {
	case .SPLASH:
		s := f32(287 * 0.5)
		rl.DrawTexture(
			common.get_tex(&gmem.textures, "dxtrs-games"),
			i32(common.WINDOW_WIDTH * 0.5 - s),
			i32(common.WINDOW_HEIGHT * 0.5 - s),
			rl.WHITE,
		)

	case .MAIN_MENU:
		win_w := f32(600)
		win_h := f32(140)
		win_x := i32(common.WINDOW_WIDTH * 0.5 - win_w * 0.5)
		win_y := i32(common.WINDOW_HEIGHT * 0.5 - win_h * 0.5)

		ui.drawWin(gmem, win_x, win_y, i32(win_w), i32(win_h))

		header := cstring("Frogger")
		header_w := rl.MeasureText(header, ui.FONT_SIZE_HEADER)
		rl.DrawText(
			header,
			i32(common.WINDOW_WIDTH * 0.5 - f32(header_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER * 0.5 - 10,
			ui.FONT_SIZE_HEADER,
			rl.DARKGRAY,
		)

		inst := cstring("Press <space> or press <left_click> to start.")
		inst_w := rl.MeasureText(inst, ui.FONT_SIZE_BODY)
		rl.DrawText(
			inst,
			i32(common.WINDOW_WIDTH * 0.5 - f32(inst_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER + 40,
			ui.FONT_SIZE_BODY,
			rl.DARKGRAY,
		)

	case .PLAYING:
		// Render tilemap
		for t, i in getCurrentLevel(gmem).tiles {
			x := f32(i % common.NUM_TILES_IN_ROW) * common.TILE_SIZE
			y := f32(i / common.NUM_TILES_IN_ROW) * common.TILE_SIZE

			src := rl.Rectangle {
				width  = common.TILE_SIZE,
				height = common.TILE_SIZE,
			}
			dest := rl.Rectangle {
				x      = x,
				y      = y,
				width  = common.TILE_SIZE * common.SCALE,
				height = common.TILE_SIZE * common.SCALE,
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

			rl.DrawTexturePro(
				common.get_tex(&gmem.textures, "tiles"),
				src,
				dest,
				{0, 0},
				0,
				rl.WHITE,
			)
		}

		// Render player
		rl.DrawTexturePro(
			common.get_tex(&gmem.textures, "player"),
			{},
			{
				x = f32(gmem.player.pos.x),
				y = f32(gmem.player.pos.y),
				width = f32(gmem.player.size[1] * common.SCALE),
				height = f32(gmem.player.size[0] * common.SCALE),
			},
			{0, 0},
			0,
			rl.RED,
		)

		when HAS_LEVEL_DEBUG {
			rl.DrawRectangleLines(
				i32(gmem.player.pos.x),
				i32(gmem.player.pos.y),
				i32(gmem.player.size[1] * common.SCALE),
				i32(gmem.player.size[0] * common.SCALE),
				rl.RED,
			)
		}

		// Render enemies
		for e in getCurrentLevel(gmem).enemies {
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
				width  = f32(e.size[1]) * common.SCALE,
				height = f32(e.size[0]) * common.SCALE,
			}

			rl.DrawTexturePro(
				common.get_tex(&gmem.textures, e.texture_id),
				src,
				dest,
				{0, 0},
				0,
				rl.WHITE,
			)

			when HAS_LEVEL_DEBUG {
				rl.DrawRectangleLines(
					i32(e.pos.x),
					i32(e.pos.y),
					i32(e.size[1] * common.SCALE),
					i32(e.size[0] * common.SCALE),
					rl.RED,
				)
			}
		}

		// Render UI
		ui.render(gmem)

	case .GAME_OVER:
		win_w := f32(600)
		win_h := f32(140)
		win_x := i32(common.WINDOW_WIDTH * 0.5 - win_w * 0.5)
		win_y := i32(common.WINDOW_HEIGHT * 0.5 - win_h * 0.5)

		ui.drawWin(gmem, win_x, win_y, i32(win_w), i32(win_h))

		header := cstring("Game Over")
		header_w := rl.MeasureText(header, ui.FONT_SIZE_HEADER)
		rl.DrawText(
			header,
			i32(common.WINDOW_WIDTH * 0.5 - f32(header_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER * 0.5 - 10,
			ui.FONT_SIZE_HEADER,
			rl.DARKGRAY,
		)

		inst := cstring("Press <space> or press <left_click> to play again.")
		inst_w := rl.MeasureText(inst, ui.FONT_SIZE_BODY)
		rl.DrawText(
			inst,
			i32(common.WINDOW_WIDTH * 0.5 - f32(inst_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER + 40,
			ui.FONT_SIZE_BODY,
			rl.DARKGRAY,
		)
	}

	rl.EndDrawing()
}

destroy :: proc() {
	rl.CloseWindow()
}
