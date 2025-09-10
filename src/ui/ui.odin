package ui

import "../common"
import rl "vendor:raylib"

WIN_DECORATION :: "window-decoration"
BUTTON_GREEN :: "button-green"

Window :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}

setup :: proc(gmem: ^common.Memory) {
	common.load_tex(&gmem.textures, WIN_DECORATION)
	common.load_tex(&gmem.textures, BUTTON_GREEN)
}

update :: proc(gmem: ^common.Memory) -> bool {

	return false
}

render :: proc(gmem: ^common.Memory) {
	drawWin(gmem, 100, 100, 400, 200)
}

drawWin :: proc(gmem: ^common.Memory, x, y, width, height: i32) {
	win_tex := gmem.textures[WIN_DECORATION]
	loc := rl.Rectangle {
		x      = f32(x),
		y      = f32(y),
		width  = 32,
		height = 32,
	}

	// Top left
	top_left_corner := rl.Rectangle {
		x      = 0,
		y      = 0,
		width  = 32,
		height = 32,
	}
	rl.DrawTexturePro(win_tex, top_left_corner, loc, {0, 0}, 0, rl.WHITE)

	// Top right
	top_right_corner := rl.Rectangle {
		x      = 32,
		y      = 0,
		width  = 32,
		height = 32,
	}
	loc.x = f32((x + width) - 32)
	loc.y = f32(x)
	rl.DrawTexturePro(win_tex, top_right_corner, loc, {0, 0}, 0, rl.WHITE)

	// Bottom left
	bottom_left_corner := rl.Rectangle {
		x      = 0,
		y      = 32,
		width  = 32,
		height = 32,
	}
	loc.x = f32(x)
	loc.y = f32((x + height) - 32)
	rl.DrawTexturePro(win_tex, bottom_left_corner, loc, {0, 0}, 0, rl.WHITE)

	// Bottom right
	bottom_right_corner := rl.Rectangle {
		x      = 32,
		y      = 32,
		width  = 32,
		height = 32,
	}
	loc.x = f32((x + width) - 32)
	loc.y = f32((x + height) - 32)
	rl.DrawTexturePro(win_tex, bottom_right_corner, loc, {0, 0}, 0, rl.WHITE)

	// Left
	left_side := rl.Rectangle {
		x      = 0,
		y      = 16,
		width  = 32,
		height = 32,
	}
	loc.x = f32(x)
	loc.y = f32(y + 16)
	loc.height = f32((height - 32))
	rl.DrawTexturePro(win_tex, left_side, loc, {0, 0}, 0, rl.WHITE)

	// Right
	right_side := rl.Rectangle {
		x      = 32,
		y      = 16,
		width  = 32,
		height = 32,
	}
	loc.x = f32((x + width) - 32)
	loc.y = f32(y + 16)
	loc.height = f32((height - 32))
	rl.DrawTexturePro(win_tex, right_side, loc, {0, 0}, 0, rl.WHITE)

	// Top
	top_side := rl.Rectangle {
		x      = 8,
		y      = 0,
		width  = 32,
		height = 32,
	}
	loc.x = f32(x + 16)
	loc.y = f32(y)
	loc.width = f32((width - 32))
	loc.height = f32(32)
	rl.DrawTexturePro(win_tex, top_side, loc, {0, 0}, 0, rl.WHITE)

	// Bottom
	bottom_side := rl.Rectangle {
		x      = 8,
		y      = 32,
		width  = 32,
		height = 32,
	}
	loc.x = f32(x + 16)
	loc.y = f32((height + y) - 32)
	loc.width = f32((width - 32))
	loc.height = f32(32)
	rl.DrawTexturePro(win_tex, bottom_side, loc, {0, 0}, 0, rl.WHITE)

	// Inside
	inside := rl.Rectangle {
		x      = 8,
		y      = 8,
		width  = 32,
		height = 32,
	}
	loc.x = f32(x + 16)
	loc.y = f32(y + 16)
	loc.width = f32(width - (32))
	loc.height = f32(height - (32))
	rl.DrawTexturePro(win_tex, inside, loc, {0, 0}, 0, rl.WHITE)
}
