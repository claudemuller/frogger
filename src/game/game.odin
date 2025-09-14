package game

import "../common"
import "../input"
import "../ui"
import "../utils"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

HAS_LEVEL_DEBUG :: #config(DEBUG, false)
HAS_SHOW_COLLIDERS :: #config(SHOW_COLLIDERS, false)

PLAYER_SPEED :: 25

init :: proc(win_name: cstring) -> ^common.Memory {
	rl.InitWindow(common.WINDOW_WIDTH, common.WINDOW_HEIGHT, cstring(win_name))

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	rl.InitAudioDevice()

	gmem := new(common.Memory)
	gmem.win_name = win_name
	setup(gmem)

	return gmem
}

setup :: proc(gmem: ^common.Memory) {
	if ok := common.load_level(gmem, 1); !ok {
		fmt.panicf("Error loading level: %d", 1)
	}

	input.setup()
	ui.setup(gmem)

	gmem.sound["dxtrs"] = rl.LoadSound("res/dxtrs.mp3")
	gmem.sound["jump"] = rl.LoadSound("res/jump.mp3")
	gmem.music["traffic"] = rl.LoadMusicStream("res/traffic.mp3")

	boot_game(gmem)
}

run :: proc(gmem: ^common.Memory) {
	for !rl.WindowShouldClose() {
		if common.get_state(gmem) == .SHUTDOWN {
			break
		}
		input.process(&gmem.input)
		update(gmem)
		render(gmem)
	}
	rl.CloseWindow()
	// destroy()
}

update :: proc(gmem: ^common.Memory) {
	// Update UI
	if ui.update(gmem) {
		return
	}

	switch common.get_state(gmem) {
	case .SPLASH:
		if .LEFT in gmem.input.mouse.btns ||
		   .SPACE in gmem.input.kb.btns ||
		   utils.timer_done(gmem.splash_timer) {
			rl.StopSound(gmem.sound["dxtrs"])
			gmem.splash_timer = utils.Timer{}
			common.push_state(gmem, .MAIN_MENU)
		}

	case .MAIN_MENU:
		if .LEFT in gmem.input.mouse.btns || .SPACE in gmem.input.kb.btns {
			common.push_state(gmem, .PLAYING)
			rl.PlayMusicStream(gmem.music["traffic"])
		}

	case .PLAYING:
		// if .SPACE not_in gmem.input.kb.btns do return

		rl.UpdateMusicStream(gmem.music["traffic"])

		// Update player
		gmem.player.vel = 0.0

		// Jumping motion
		if .UP in gmem.input.kb.btns do gmem.player.vel.y = -PLAYER_SPEED
		if .DOWN in gmem.input.kb.btns do gmem.player.vel.y = PLAYER_SPEED
		if .LEFT in gmem.input.kb.btns do gmem.player.vel.x = -PLAYER_SPEED
		if .RIGHT in gmem.input.kb.btns do gmem.player.vel.x = PLAYER_SPEED
		if .LEFT_FACE_UP in gmem.input.gamepad.btns do gmem.player.vel.y = -PLAYER_SPEED
		if .LEFT_FACE_DOWN in gmem.input.gamepad.btns do gmem.player.vel.y = PLAYER_SPEED
		if .LEFT_FACE_LEFT in gmem.input.gamepad.btns do gmem.player.vel.x = -PLAYER_SPEED
		if .LEFT_FACE_RIGHT in gmem.input.gamepad.btns do gmem.player.vel.x = PLAYER_SPEED

		if gmem.player.vel.y != 0 || gmem.player.vel.x != 0 do rl.PlaySound(gmem.sound["jump"])

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
			e.pos.x += e.vel.x
			if e.pos.x <= -f32(e.size[0]) {
				e.pos.x = common.WINDOW_WIDTH / 2
			} else if e.pos.x >= common.WINDOW_WIDTH / 2 {
				e.pos.x = -f32(e.size[0])
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

			if utils.timer_done(e.timer) && e.backoff {
				fmt.println("timer expires")
				e.vel.x = e.vel.y
				e.backoff = false
				e.timer = utils.Timer{}
			}

			for &e_other, j in gmem.level.layers[.ENEMIES].entities {
				y_tolerance := math.abs(
					(e.pos.y + f32(e.size[1]) * 0.5) -
					(e_other.pos.y + f32(e_other.size[1]) * 0.5),
				)
				// Skip if the two being compared are not in the same lane
				if i == j || y_tolerance > 30 {
					continue
				}

				when HAS_LEVEL_DEBUG {
					fmt.printf(
						"[%s]e.pos: %v - [%s]e_other.pos: %v\n",
						e.name,
						e.pos,
						e_other.name,
						e_other.pos,
					)
					fmt.printf(
						"e.pos.midy: %.2f -e.other_pos.midy: %.2f  -- %.2f\n",
						e.pos.y + f32(e.size[1]) / 2,
						e_other.pos.y + f32(e_other.size[1]) / 2,
						y_tolerance,
					)
					fmt.printf(
						"e_right: %d - e_other_left: %d  -  e_other_right: %d - e_left: %d\n",
						i32(e.pos.x) + e.size[0],
						i32(e_other.pos.x),
						i32(e_other.pos.x) + e_other.size[0],
						i32(e.pos.x),
					)
					fmt.printf(
						"e.collider: %v - e_other.collider: %v\n\n",
						e.collider * common.SCALE,
						e_other.collider * common.SCALE,
					)
				}

				// TODO: only check one side collision depending on the direction of movement
				// TODO: check if entities start off screen on top of one another, fix that

				if math.abs(i32(e.pos.x) + e.size[0] - i32(e_other.pos.x)) < 2 {
					fmt.printf("%s\n", e.name)

					e_other.vel.y = e_other.vel.x
					e_other.vel.x *= 0.5
					e_other.backoff_duration = 3
					utils.start_timer(&e_other.timer, e_other.backoff_duration)
					e_other.backoff = true
				}
				if math.abs(i32(e_other.pos.x) + e_other.size[0] - i32(e.pos.x)) < 2 {
					fmt.printf("%s\n", e_other.name)

					e.vel.y = e.vel.x
					e.vel.x *= 0.5
					e.backoff_duration = 3
					utils.start_timer(&e.timer, e.backoff_duration)
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
		if .LEFT in gmem.input.mouse.btns || .SPACE in gmem.input.kb.btns {
			common.push_state(gmem, .MAIN_MENU)
		}

	case .GAME_OVER:
		if .LEFT in gmem.input.mouse.btns || .SPACE in gmem.input.kb.btns {
			common.push_state(gmem, .MAIN_MENU)
		}

	case .SHUTDOWN:
	}
}

render :: proc(gmem: ^common.Memory) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch common.get_state(gmem) {
	case .SPLASH:
		ui.draw_splash_screen(gmem)

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
			draw_entity(gmem.textures, o, false, gmem.fonts["vt323"])
		}

		for e, i in level.layers[.ENEMIES].entities {
			draw_entity(gmem.textures, e, HAS_SHOW_COLLIDERS, gmem.fonts["vt323"])
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

		when HAS_SHOW_COLLIDERS {
			rl.DrawRectangleLines(
				i32(gmem.player.pos.x * common.SCALE),
				i32(gmem.player.pos.y * common.SCALE),
				i32(gmem.player.collider[1] * common.SCALE),
				i32(gmem.player.collider[0] * common.SCALE),
				rl.RED,
			)

			font_size := f32(18)
			rl.DrawTextEx(
				gmem.fonts["vt323"],
				fmt.ctprintf("%.2f : %.2f", gmem.player.pos.x, gmem.player.pos.y),
				{gmem.player.pos.x * common.SCALE - 20, gmem.player.pos.y * common.SCALE - 20},
				font_size,
				1,
				rl.RED,
			)
			rl.DrawTextEx(
				gmem.fonts["vt323"],
				fmt.ctprintf("%.2f : %.2f", gmem.player.collider[0], gmem.player.collider[1]),
				{
					gmem.player.pos.x * common.SCALE - 20,
					gmem.player.pos.y * common.SCALE + f32(gmem.player.size[1]) + 25,
				},
				font_size,
				1,
				rl.RED,
			)
		}

		// Render UI
		ui.render(gmem)

	case .WINNER:
		rl.StopMusicStream(gmem.music["traffic"])

		win_w := f32(600)
		win_h := f32(140)
		win_x := i32(common.WINDOW_WIDTH * 0.5 - win_w * 0.5)
		win_y := i32(common.WINDOW_HEIGHT * 0.5 - win_h * 0.5)

		ui.drawWin(gmem, win_x, win_y, i32(win_w), i32(win_h))

		header := cstring("You Win!")
		header_w := rl.MeasureText(header, ui.FONT_SIZE_HEADER)
		rl.DrawText(
			header,
			i32(common.WINDOW_WIDTH * 0.5 - f32(header_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER * 0.5 - 10,
			ui.FONT_SIZE_HEADER,
			rl.DARKGRAY,
		)

		inst := cstring("Moving to next level.\nPress <space> or <left_click> when ready.")
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

		inst := cstring("Press <space> or <left_click> to play again.")
		inst_w := rl.MeasureText(inst, ui.FONT_SIZE_BODY)
		rl.DrawText(
			inst,
			i32(common.WINDOW_WIDTH * 0.5 - f32(inst_w) * 0.5),
			win_y + ui.FONT_SIZE_HEADER + 40,
			ui.FONT_SIZE_BODY,
			rl.DARKGRAY,
		)

	case .SHUTDOWN:
	}

	if HAS_LEVEL_DEBUG {
		rl.DrawFPS(10, 10)
	}

	rl.EndDrawing()
}

draw_entity :: proc(
	textures: map[string]rl.Texture2D,
	e: common.Entity,
	show_colliders: bool,
	font: rl.Font,
) {
	w := f32(e.size[0])
	if e.fliph do w *= -1

	h := f32(e.size[1])
	if e.flipv do h *= -1

	rl.DrawTexturePro(
		common.get_texture(textures, e.texture_id),
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

	if show_colliders {
		rl.DrawRectangleLines(
			i32(e.pos.x * common.SCALE),
			i32(e.pos.y * common.SCALE),
			i32(e.collider[0] * common.SCALE),
			i32(e.collider[1] * common.SCALE),
			rl.RED,
		)

		font_size := f32(18)
		rl.DrawTextEx(
			font,
			fmt.ctprintf("%.2f : %.2f", e.pos.x, e.pos.y),
			{e.pos.x * common.SCALE - 20, e.pos.y * common.SCALE - 20},
			font_size,
			1,
			rl.RED,
		)
		rl.DrawTextEx(
			font,
			fmt.ctprintf("%.2f : %.2f", e.collider[0], e.collider[1]),
			{e.pos.x * common.SCALE - 20, e.pos.y * common.SCALE + f32(e.size[1]) + 25},
			font_size,
			1,
			rl.RED,
		)
	}
}


boot_game :: proc(gmem: ^common.Memory) {
	BOOT_TIME :: 10 // Seconds

	gmem.memctr = rl.GetTime()
	rl.PlaySound(gmem.sound["dxtrs"])
	utils.start_timer(&gmem.splash_timer, BOOT_TIME)
	common.push_state(gmem, .SPLASH)
}

destroy :: proc() {
	rl.CloseWindow()
}
