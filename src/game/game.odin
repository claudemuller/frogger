package game

import "../common"
import "../input"
import "../ui"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

HAS_LEVEL_DEBUG :: #config(DEBUG, false)
HAS_COLLIDERS :: #config(COLLIDERS, false)

PLAYER_SPEED :: 25

init :: proc(win_name: cstring) -> ^common.Memory {
	rl.InitWindow(common.WINDOW_WIDTH, common.WINDOW_HEIGHT, cstring(win_name))

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	gmem := new(common.Memory)
	gmem.win_name = win_name
	setup(gmem)

	gmem.is_running = true
	gmem.splash_timer = 2.0
	common.push_state(gmem, .SPLASH)

	return gmem
}

setup :: proc(gmem: ^common.Memory) {
	if ok := common.load_level(gmem, 1); !ok {
		fmt.panicf("Error loading level: %d", 1)
	}

	input.setup()
	ui.setup(gmem)
}

run :: proc(gmem: ^common.Memory) {
	for !rl.WindowShouldClose() {
		input.process(&gmem.input)
		update(gmem)
		render(gmem)
	}
	// destroy()
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

		// Jumping motion
		if .UP in gmem.input.kb.btns do gmem.player.vel.y = -PLAYER_SPEED
		if .DOWN in gmem.input.kb.btns do gmem.player.vel.y = PLAYER_SPEED
		if .LEFT in gmem.input.kb.btns do gmem.player.vel.x = -PLAYER_SPEED
		if .RIGHT in gmem.input.kb.btns do gmem.player.vel.x = PLAYER_SPEED
		if .RIGHT_FACE_UP in gmem.input.gamepad.btns do gmem.player.vel.y = -PLAYER_SPEED
		if .RIGHT_FACE_DOWN in gmem.input.gamepad.btns do gmem.player.vel.y = PLAYER_SPEED
		if .RIGHT_FACE_LEFT in gmem.input.gamepad.btns do gmem.player.vel.x = -PLAYER_SPEED
		if .RIGHT_FACE_RIGHT in gmem.input.gamepad.btns do gmem.player.vel.x = PLAYER_SPEED

		// Smooth motion
		// gmem.player.vel.x = gmem.input.kb.axis.x
		// gmem.player.vel.y = gmem.input.kb.axis.y
		// gmem.player.vel.x = gmem.input.gamepad.laxis.x
		// gmem.player.vel.y = gmem.input.gamepad.laxis.y

		gmem.player.pos += gmem.player.vel

		if gmem.player.pos.x < 0 do gmem.player.pos.x = 0
		if gmem.player.pos.x > (common.WINDOW_WIDTH - common.TILE_SIZE) do gmem.player.pos.x = common.WINDOW_WIDTH - common.TILE_SIZE
		if gmem.player.pos.y < 0 do gmem.player.pos.y = 0
		if gmem.player.pos.y > (common.WINDOW_HEIGHT - common.TILE_SIZE) do gmem.player.pos.y = common.WINDOW_HEIGHT - common.TILE_SIZE

		player_rect := rl.Rectangle {
			x      = gmem.player.pos.x * common.SCALE,
			y      = gmem.player.pos.y * common.SCALE,
			width  = f32(gmem.player.collider[0] * common.SCALE),
			height = f32(gmem.player.collider[1] * common.SCALE),
		}

		// Update enemies
		for &e, i in gmem.level.layers[.ENEMIES].entities {
			e.pos += e.vel
			if e.pos.x <= -f32(e.size[0]) {
				e.pos.x = common.WINDOW_WIDTH / 2
			} else if e.pos.x >= common.WINDOW_WIDTH / 2 {
				e.pos.x = -f32(e.size[0])
			}

			when HAS_LEVEL_DEBUG {
				if e.texture_id == "sedan-purple" {
					fmt.printf(
						"%v %v %v %v\n%v\n",
						e.size[0],
						common.SCALE,
						gmem.level.num_tiles_row,
						f32(e.size[0]) * f32(common.SCALE * gmem.level.num_tiles_row),
						e,
					)
				}
			}

			e_rect := rl.Rectangle {
				x      = e.pos.x * common.SCALE,
				y      = e.pos.y * common.SCALE,
				width  = f32(e.collider[0] * common.SCALE),
				height = f32(e.collider[1] * common.SCALE),
			}

			if rl.CheckCollisionRecs(player_rect, e_rect) {
				common.push_state(gmem, .GAME_OVER)
				fmt.println("collision")
			}

			if e.timer > 0 {
				e.timer -= rl.GetFrameTime()
			}
			if e.timer <= 0 && e.backoff {
				e.vel.x *= 2.0
				e.backoff = false
			}

			for &e_other, j in gmem.level.layers[.ENEMIES].entities {
				y_tolerance := math.abs(e.pos.y - e_other.pos.y)
				if i == j || y_tolerance <= 1 || y_tolerance >= -1 {
					continue
				}

				e_other_rect := rl.Rectangle {
					x      = e_other.pos.x * common.SCALE,
					y      = e_other.pos.y * common.SCALE,
					width  = f32(e_other.collider[0] * common.SCALE),
					height = f32(e_other.collider[1] * common.SCALE),
				}

				if rl.CheckCollisionRecs(e_other_rect, e_rect) {
					e.vel.x *= 0.5
					e.timer = e.backoff_duration
					e.backoff = true
				}
			}
		}

		for t in gmem.level.layers[.TRIGGERS].triggers {
			if t.name == "Win" {
				t_rect := rl.Rectangle {
					x      = t.pos.x * common.SCALE,
					y      = t.pos.y * common.SCALE,
					width  = f32(t.size[0] * common.SCALE),
					height = f32(t.size[1] * common.SCALE),
				}
				if rl.CheckCollisionRecs(player_rect, t_rect) {
					common.push_state(gmem, .WINNER)
				}
			}
		}

	case .WINNER:
		os.exit(0)

	case .GAME_OVER:
	}
}

render :: proc(gmem: ^common.Memory) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch common.get_state(gmem) {
	case .SPLASH:
		ui.render_splash(gmem)

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
		level := gmem.level
		for t, i in level.layers[.TERRAIN].tiles {
			w := f32(t.size[0])
			if t.fliph do w *= -1

			h := f32(t.size[1])
			if t.flipv do h *= -1

			rl.DrawTexturePro(
				common.get_texture(gmem.textures, t.texture_id),
				{f32(t.srcpos.x), f32(t.srcpos.y), w, h},
				{
					f32(t.pos.x * common.SCALE),
					f32(t.pos.y * common.SCALE),
					f32(t.size[0] * common.SCALE),
					f32(t.size[1] * common.SCALE),
				},
				{0, 0},
				0,
				rl.WHITE,
			)
		}

		for o, i in level.layers[.OBJECTS].entities {
			w := f32(o.size[0])
			if o.fliph do w *= -1

			h := f32(o.size[1])
			if o.flipv do h *= -1

			rl.DrawTexturePro(
				common.get_texture(gmem.textures, o.texture_id),
				{f32(o.srcpos.x), f32(o.srcpos.y), w, h},
				{
					f32(o.pos.x * common.SCALE),
					f32(o.pos.y * common.SCALE),
					f32(o.size[0] * common.SCALE),
					f32(o.size[1] * common.SCALE),
				},
				{0, 0},
				0,
				rl.WHITE,
			)
		}

		for e, i in level.layers[.ENEMIES].entities {
			w := f32(e.size[0])
			if e.fliph do w *= -1

			h := f32(e.size[1])
			if e.flipv do h *= -1

			rl.DrawTexturePro(
				common.get_texture(gmem.textures, e.texture_id),
				{f32(e.srcpos.x), f32(e.srcpos.y), w, h},
				{
					f32(e.pos.x * common.SCALE),
					f32(e.pos.y * common.SCALE),
					f32(e.size[0] * common.SCALE),
					f32(e.size[1] * common.SCALE),
				},
				{0, 0},
				0,
				rl.WHITE,
			)

			when HAS_COLLIDERS {
				rl.DrawRectangleLines(
					i32(e.pos.x * common.SCALE),
					i32(e.pos.y * common.SCALE),
					i32(e.collider[0] * common.SCALE),
					i32(e.collider[1] * common.SCALE),
					rl.RED,
				)
			}
		}

		// Render player
		rl.DrawTexturePro(
			common.get_texture(gmem.textures, gmem.player.texture_id),
			{0, 0, 32, 32},
			{
				x = f32(gmem.player.pos.x * common.SCALE),
				y = f32(gmem.player.pos.y * common.SCALE),
				width = f32(gmem.player.size[1] * common.SCALE),
				height = f32(gmem.player.size[0] * common.SCALE),
			},
			{0, 0},
			0,
			rl.WHITE,
		)

		when HAS_COLLIDERS {
			rl.DrawRectangleLines(
				i32(gmem.player.pos.x * common.SCALE),
				i32(gmem.player.pos.y * common.SCALE),
				i32(gmem.player.collider[1] * common.SCALE),
				i32(gmem.player.collider[0] * common.SCALE),
				rl.RED,
			)
		}

		// Render UI
		ui.render(gmem)

	case .WINNER:
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

		inst := cstring("You win! Moving to next level.")
		inst_w := rl.MeasureText(inst, ui.FONT_SIZE_BODY)
		rl.DrawText(
			inst,
			i32(common.WINDOW_WIDTH * 0.5 - f32(inst_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER + 40,
			ui.FONT_SIZE_BODY,
			rl.DARKGRAY,
		)

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

		inst := cstring("Game Over! Press <space> or press <left_click> to play again.")
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
