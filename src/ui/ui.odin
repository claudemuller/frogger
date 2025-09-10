package ui

import "../common"
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

setup :: proc(gmem: ^common.Memory) {
	common.load_tex(&gmem.textures, "dxtrs-games")
	common.load_tex(&gmem.textures, WIN_DECORATION)
	common.load_tex(&gmem.textures, BUTTON_GREEN)
}

update :: proc(gmem: ^common.Memory) -> bool {

	return false
}

render :: proc(gmem: ^common.Memory) {
	// drawWin(gmem, 100, 100, 400, 200)
	// drawButton(gmem, "testing", 400-50, 200-10)
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
