package main

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:os"
import "core:strings"
import "core:time"

import "core:image/png"


import gl "vendor:OpenGL"
import SDL "vendor:sdl2"


BLOCK_COUNT_WIDTH :: 80
BLOCK_WIDTH :: 20

WINDOW_ASPECT_RATIO: f32 = 16.0 / 9.0
WINDOW_WIDTH: i32 = BLOCK_COUNT_WIDTH * BLOCK_WIDTH
WINDOW_HEIGHT: i32 = i32((f32(WINDOW_WIDTH) / WINDOW_ASPECT_RATIO))

MS_BETWEEN_WORLD_UPDATES :: 150


Game :: struct {
	// perf_frequency: f32,
	renderer: ^SDL.Renderer,
}

game := Game{}


// Colors to use
// #FFFFFF walkable
// #000000 wall
// #FF0000 fire


BLOCK_TYPES :: enum {
	ground,
	wall,
	door,
	fire,
}

COLOR_BLOCK_LOOKUP := map[BLOCK_TYPES]string {
	BLOCK_TYPES.ground = "#FFFFFF",
	BLOCK_TYPES.wall   = "#000000",
	BLOCK_TYPES.door   = "#808080",
	BLOCK_TYPES.fire   = "#FF0000",
}


WorldState :: struct {
	player_position:   [2]i32,
	world_update_tick: time.Tick,
	blocks:            [][]BLOCK_TYPES,
}

world_state := WorldState{}


KeyState :: struct {
	pressed_since_last_update: bool,
	currently_pressed:         bool,
}

KeyboardState :: struct {
	left:  KeyState,
	up:    KeyState,
	down:  KeyState,
	right: KeyState,

	//jump: KeyState
}

keyboard_state := KeyboardState{}


main :: proc() {
	assert(SDL.Init(SDL.INIT_VIDEO) == 0, SDL.GetErrorString())

	window := SDL.CreateWindow(
		"Odin SDL2 Demo",
		SDL.WINDOWPOS_UNDEFINED,
		SDL.WINDOWPOS_UNDEFINED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.OPENGL},
	)

	create_world_from_map()

	assert(window != nil, SDL.GetErrorString())

	game.renderer = SDL.CreateRenderer(window, -1, SDL.RENDERER_ACCELERATED)
	assert(game.renderer != nil, SDL.GetErrorString())


	// game.perf_frequency = f64(SDL.GetPerformanceFrequency())
	// start: f64
	// end: f64

	// defer SDL.DestroyWindow(window)

	// high precision timer
	start_tick := time.tick_now()

	event: SDL.Event
	//keyboard_state: [^]u8

	loop: for {
		// time_since_last_update := f32(time.duration_seconds(time.tick_since(start_tick)))
		// start_tick = time.tick_now()

		if SDL.PollEvent(&event) {
			if event.type == SDL.EventType.QUIT {break}

			if event.type == SDL.EventType.KEYDOWN {
				if event.key.keysym.scancode == SDL.Scancode.A {
					keyboard_state.left.pressed_since_last_update = true
					keyboard_state.left.currently_pressed = true
				}

				if event.key.keysym.scancode == SDL.Scancode.W {
					keyboard_state.up.pressed_since_last_update = true
					keyboard_state.up.currently_pressed = true
				}

				if event.key.keysym.scancode == SDL.Scancode.D {
					keyboard_state.right.pressed_since_last_update = true
					keyboard_state.right.currently_pressed = true
				}

				if event.key.keysym.scancode == SDL.Scancode.S {
					keyboard_state.down.pressed_since_last_update = true
					keyboard_state.down.currently_pressed = true
				}


				if event.key.keysym.scancode == SDL.Scancode.ESCAPE {
					break
				}

			}

			if event.type == SDL.EventType.KEYUP {
				if event.key.keysym.scancode == SDL.Scancode.A {
					keyboard_state.left.currently_pressed = false
				}

				if event.key.keysym.scancode == SDL.Scancode.W {
					keyboard_state.up.currently_pressed = false
				}

				if event.key.keysym.scancode == SDL.Scancode.D {
					keyboard_state.right.currently_pressed = false
				}

				if event.key.keysym.scancode == SDL.Scancode.S {
					keyboard_state.down.currently_pressed = false
				}
			}
		}


		time_since_last_update := f32(
			time.duration_milliseconds(time.tick_since(world_state.world_update_tick)),
		)
		if time_since_last_update > MS_BETWEEN_WORLD_UPDATES {
			world_state.world_update_tick = time.tick_now()

			// update world based on input
			if keyboard_state.left.pressed_since_last_update ||
			   keyboard_state.left.currently_pressed {
				world_state.player_position[0] -= BLOCK_WIDTH
			}
			if keyboard_state.up.pressed_since_last_update || keyboard_state.up.currently_pressed {
				world_state.player_position[1] += BLOCK_WIDTH
			}
			if keyboard_state.right.pressed_since_last_update ||
			   keyboard_state.right.currently_pressed {
				world_state.player_position[0] += BLOCK_WIDTH
			}
			if keyboard_state.down.pressed_since_last_update ||
			   keyboard_state.down.currently_pressed {
				world_state.player_position[1] -= BLOCK_WIDTH
			}

			keyboard_state.left.pressed_since_last_update = false
			keyboard_state.right.pressed_since_last_update = false
			keyboard_state.up.pressed_since_last_update = false
			keyboard_state.down.pressed_since_last_update = false
		}


		SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 255) // White color
		SDL.RenderClear(game.renderer)


		// Draw the black box at the player's coordinates
		SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 255) // Black color
		playerRect := &SDL.Rect {
			x = world_state.player_position[0],
			y = WINDOW_HEIGHT - world_state.player_position[1] - BLOCK_WIDTH,
			w = BLOCK_WIDTH,
			h = BLOCK_WIDTH,
		} // Assuming player_position is [x, y]
		SDL.RenderDrawRect(game.renderer, playerRect)

		// Present the renderer to display the changes
		SDL.RenderPresent(game.renderer)

		SDL.RenderClear(game.renderer)

	}
}

create_world_from_map :: proc() {
	fmt.println("try to create world...")

	file, success := png.load_from_file("./maps/map1.png")

	for i in 0 ..< (len(file.pixels.buf) / 4) {
		red_res: strings.Builder
		red_hex := fmt.sbprintf(&red_res, "%02X", file.pixels.buf[i * 4])
		green_res: strings.Builder
		green_hex := fmt.sbprintf(&green_res, "%02X", file.pixels.buf[i * 4 + 1])
		blue_res: strings.Builder
		blue_hex := fmt.sbprintf(&blue_res, "%02X", file.pixels.buf[i * 4 + 2])


		pixel_hex_color := strings.concatenate({"#", red_hex, green_hex, blue_hex})

		switch pixel_hex_color {
		case COLOR_BLOCK_LOOKUP[BLOCK_TYPES.fire]:

		case COLOR_BLOCK_LOOKUP[BLOCK_TYPES.ground]:

		case COLOR_BLOCK_LOOKUP[BLOCK_TYPES.wall]:

		}
	}
}
