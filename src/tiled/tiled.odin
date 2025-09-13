package tiled

import "../input"
import "core:encoding/xml"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

ObjectType :: enum {
	TILE, //tilelayer
	OBJECT, // objectgroup
}
DrawOrder :: enum {
	TOPDOWN, // topdown
}
RenderOrder :: enum {
	RIGHT_DOWN,
}

EntityType :: enum {
	ENEMY, // Enemy
	TRIGGER, // Trigger
}

GridOrientation :: enum {
	UNSPECIFIED,
	ORTHOGONAL,
	ISOMETRIC,
}

Object :: struct {
	id:         int,
	gid:        int,
	name:       string,
	type:       string, // should be enum
	x:          f32,
	y:          f32,
	width:      f32,
	height:     f32,
	rotation:   f32,
	visible:    bool,
	properties: [dynamic]ObjectProperty,
}

ObjectProperty :: struct {
	name:  string, // Speed
	type:  string, // float
	value: f32, // this changes based on the above type
}

Layer :: struct {
	id:        int,
	name:      string,
	type:      string, // should be enum
	visible:   bool,
	width:     int,
	height:    int,
	x:         int,
	y:         int,
	draworder: string, // should be enum
	opacity:   f32,
	data:      [dynamic]int,
	objects:   [dynamic]Object,
}

TilesetSrc :: struct {
	firstgid: int,
	source:   string,
}

Level :: struct {
	renderorder: string, // right-down - should be enum
	height:      int,
	width:       int,
	tileheight:  int,
	tilewidth:   int,
	type:        string, // map - should be enum
	orientation: string, // orthogonal - should be enum
	tilesets:    [dynamic]TilesetSrc,
	layers:      [dynamic]Layer,
}

Tile :: struct {
	id:          int,
	image:       string,
	imageheight: int,
	imagewidth:  int,
}

Grid :: struct {
	orientation: GridOrientation,
	width:       int,
	height:      int,
}

Tileset :: struct {
	texture_id:  string,
	columns:     int,
	image:       string,
	imageheight: int,
	imagewidth:  int,
	margin:      int,
	name:        string,
	spacing:     int,
	tilecount:   int,
	tileheight:  int,
	tilewidth:   int,
	type:        string, // enum - tileset
	grid:        Grid,
	tiles:       [dynamic]Tile,
}
