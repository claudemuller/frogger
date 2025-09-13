package ui

import "../common"
import "../utils"
import "core:fmt"
import rl "vendor:raylib"

WIN_DECORATION :: "window-decoration"
BUTTON_GREEN :: "button-green"

UI_TILESIZE :: 32
UI_HALF_TILESIZE :: 16
FONT_SIZE_BUTTON :: 16
FONT_SIZE_HEADER :: 48
FONT_SIZE_BODY :: 24

Window :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}

font: rl.Font

setup :: proc(gmem: ^common.Memory) {
	// Load texture not found texture
	redpx := rl.GenImageColor(1, 1, rl.RED)
	redtex := rl.LoadTextureFromImage(redpx)
	rl.UnloadImage(redpx)
	gmem.textures["NO_TEXTURE"] = redtex

	common.load_texture(&gmem.textures, "dxtrs-games", "res/dxtrs-games.png")
	common.load_texture(&gmem.textures, "dxtrs-games-gif", "res/dxtrs-games.gif")
	common.load_texture(&gmem.textures, WIN_DECORATION, "res/window-decoration.png")
	common.load_texture(&gmem.textures, BUTTON_GREEN, "res/button-green.png")

	font = rl.LoadFont("res/VT323-Regular.ttf")
}

update :: proc(gmem: ^common.Memory) -> bool {

	return false
}

render :: proc(gmem: ^common.Memory) {
	// drawWin(gmem, 100, 100, 400, 200)
	// drawButton(gmem, "testing", 400-50, 200-10)
}

memctr: f64

draw_boot_screen :: proc(gmem: ^common.Memory) {
	rl.ClearBackground(rl.BLACK)

	font_size: f32 = 22
	txt_colour := rl.Color{170, 170, 170, 255}
	top_txt := `Dxtrs T-1000 Modular BIOS v1.1, An Awesome Game Company
Copyright (C) 2020-25, Dxtrs Games, Inc.

%s


80486DX2 CPU at 66Mhz
Memory Test: %d KB`


	date_str := "15/03/2025"
	memctr = rl.GetTime() * 1000 - memctr

	WIN_PADDING :: 20

	rl.DrawTextEx(
		font,
		fmt.ctprintf(top_txt, date_str, i32(memctr)),
		{WIN_PADDING * 2, WIN_PADDING * 2},
		font_size,
		1,
		txt_colour,
	)

	bottom_txt := "Press DEL to enter SETUP\n%s-SYS-2401-A/C/2B"
	rl.DrawTextEx(
		font,
		fmt.ctprintf(bottom_txt, date_str),
		{WIN_PADDING * 2, f32(rl.GetScreenHeight()) - WIN_PADDING * 2 - font_size * 2},
		font_size,
		1,
		txt_colour,
	)

	rl.DrawTexture(
		common.get_texture(gmem.textures, "dxtrs-games"),
		rl.GetScreenWidth() - 287 - WIN_PADDING * 2,
		WIN_PADDING * 2,
		rl.WHITE,
	)
}

drawWin :: proc(gmem: ^common.Memory, x, y, width, height: i32) {
	win_tex := gmem.textures[WIN_DECORATION]
	drawUIElem(gmem, win_tex, x, y, width, height)
}

drawButton :: proc(gmem: ^common.Memory, str: cstring, x, y: i32) {
	btn_tex := gmem.textures[BUTTON_GREEN]
	width := rl.MeasureText(str, FONT_SIZE_BUTTON) + (UI_TILESIZE)
	height := i32(FONT_SIZE_BUTTON) + (UI_TILESIZE)

	drawUIElem(gmem, btn_tex, x, y, width, height)
	rl.DrawText(
		str,
		x + UI_HALF_TILESIZE,
		y + UI_HALF_TILESIZE - (FONT_SIZE_BUTTON * 0.25),
		FONT_SIZE_BUTTON,
		rl.BLACK,
	)
}

drawUIElem :: proc(gmem: ^common.Memory, tex: rl.Texture2D, x, y, width, height: i32) {
	loc := rl.Rectangle {
		x      = f32(x),
		y      = f32(y),
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}

	// Top left
	top_left_corner := rl.Rectangle {
		x      = 0,
		y      = 0,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	rl.DrawTexturePro(tex, top_left_corner, loc, {0, 0}, 0, rl.WHITE)

	// Top right
	top_right_corner := rl.Rectangle {
		x      = UI_TILESIZE,
		y      = 0,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32((x + width) - UI_TILESIZE)
	loc.y = f32(y)
	rl.DrawTexturePro(tex, top_right_corner, loc, {0, 0}, 0, rl.WHITE)

	// Bottom left
	bottom_left_corner := rl.Rectangle {
		x      = 0,
		y      = UI_TILESIZE,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32(x)
	loc.y = f32((y + height) - UI_TILESIZE)
	rl.DrawTexturePro(tex, bottom_left_corner, loc, {0, 0}, 0, rl.WHITE)

	// Bottom right
	bottom_right_corner := rl.Rectangle {
		x      = UI_TILESIZE,
		y      = UI_TILESIZE,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32((x + width) - UI_TILESIZE)
	loc.y = f32((y + height) - UI_TILESIZE)
	rl.DrawTexturePro(tex, bottom_right_corner, loc, {0, 0}, 0, rl.WHITE)

	// Left
	left_side := rl.Rectangle {
		x      = 0,
		y      = UI_HALF_TILESIZE,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32(x)
	loc.y = f32(y + UI_HALF_TILESIZE)
	loc.height = f32((height - UI_TILESIZE))
	rl.DrawTexturePro(tex, left_side, loc, {0, 0}, 0, rl.WHITE)

	// Right
	right_side := rl.Rectangle {
		x      = UI_TILESIZE,
		y      = UI_HALF_TILESIZE,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32((x + width) - UI_TILESIZE)
	loc.y = f32(y + UI_HALF_TILESIZE)
	loc.height = f32((height - UI_TILESIZE))
	rl.DrawTexturePro(tex, right_side, loc, {0, 0}, 0, rl.WHITE)

	// Top
	top_side := rl.Rectangle {
		x      = UI_HALF_TILESIZE * 0.5,
		y      = 0,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32(x + UI_HALF_TILESIZE)
	loc.y = f32(y)
	loc.width = f32((width - UI_TILESIZE))
	loc.height = f32(32)
	rl.DrawTexturePro(tex, top_side, loc, {0, 0}, 0, rl.WHITE)

	// Bottom
	bottom_side := rl.Rectangle {
		x      = UI_HALF_TILESIZE * 0.5,
		y      = UI_TILESIZE,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32(x + UI_HALF_TILESIZE)
	loc.y = f32((height + y) - UI_TILESIZE)
	loc.width = f32((width - UI_TILESIZE))
	loc.height = f32(UI_TILESIZE)
	rl.DrawTexturePro(tex, bottom_side, loc, {0, 0}, 0, rl.WHITE)

	// Inside
	inside := rl.Rectangle {
		x      = UI_HALF_TILESIZE * 0.5,
		y      = UI_HALF_TILESIZE * 0.5,
		width  = UI_TILESIZE,
		height = UI_TILESIZE,
	}
	loc.x = f32(x + UI_HALF_TILESIZE)
	loc.y = f32(y + UI_HALF_TILESIZE)
	loc.width = f32(width - (UI_TILESIZE))
	loc.height = f32(height - (UI_TILESIZE))
	rl.DrawTexturePro(tex, inside, loc, {0, 0}, 0, rl.WHITE)
}
