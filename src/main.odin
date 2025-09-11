package main

import "core:fmt"
import "core:mem"
import "game"

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		// TODO: enable and fix
		// for _, entry in track.allocation_map {
		// 	fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		// }
		// for entry in track.bad_free_array {
		// 	fmt.eprintf("%v bad free\n", entry.location)
		// }
		// mem.tracking_allocator_destroy(&track)
	}

	g := game.init("Frogger")
	defer game.destroy()

	game.run(g)
}
