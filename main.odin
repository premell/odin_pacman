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
BLOCK_COUNT_HEIGHT :: 45
BLOCK_SIZE :: 20

WINDOW_WIDTH :: BLOCK_COUNT_WIDTH * BLOCK_SIZE
WINDOW_HEIGHT :: BLOCK_COUNT_HEIGHT * BLOCK_SIZE

MS_BETWEEN_WORLD_UPDATES :: 40


Game :: struct {
	// perf_frequency: f32,
	renderer: ^SDL.Renderer,
}

game := Game{}


// Colors to use
// #FFFFFF walkable
// #000000 wall
// #FF0000 fire


BLOCK_TYPE :: enum {
	ground,
	wall,
	door,
	fire,
}

 BLOCK_COlOR_LOOKUP:= map[BLOCK_TYPE]string {
	BLOCK_TYPE.ground = "#FFFFFF",
	BLOCK_TYPE.wall   = "#000000",
	BLOCK_TYPE.door   = "#808080",
	BLOCK_TYPE.fire   = "#FF0000"
}

 COLOR_BLOCK_LOOKUP:= map[string]BLOCK_TYPE {
	"#FFFFFF" = BLOCK_TYPE.ground,
	"#000000" = BLOCK_TYPE.wall,
	"#808080" = BLOCK_TYPE.door,
	"#FF0000" = BLOCK_TYPE.fire
}


WorldState :: struct {
	player_position:   [2]int,
	world_update_tick: time.Tick,
	blocks:            [BLOCK_COUNT_HEIGHT*BLOCK_COUNT_WIDTH]BLOCK_TYPE,
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

  set_world_from_map("./maps/map1.png")	

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
			if (keyboard_state.left.pressed_since_last_update ||
			   keyboard_state.left.currently_pressed) && get_block_left(world_state.player_position) != BLOCK_TYPE.wall{
				world_state.player_position[0] -= 1
			}
			if (keyboard_state.up.pressed_since_last_update || keyboard_state.up.currently_pressed) && get_block_up(world_state.player_position) != BLOCK_TYPE.wall{ 
				world_state.player_position[1] -= 1
			}
			if (keyboard_state.right.pressed_since_last_update ||
			   keyboard_state.right.currently_pressed)  && get_block_right(world_state.player_position) != BLOCK_TYPE.wall{
				world_state.player_position[0] += 1
			}
			if (keyboard_state.down.pressed_since_last_update ||
			  keyboard_state.down.currently_pressed)  && get_block_down(world_state.player_position) != BLOCK_TYPE.wall{
				world_state.player_position[1] += 1
			}

			keyboard_state.left.pressed_since_last_update = false
			keyboard_state.right.pressed_since_last_update = false
			keyboard_state.up.pressed_since_last_update = false
			keyboard_state.down.pressed_since_last_update = false
		}



    for block,index in world_state.blocks {
      switch block {
        case BLOCK_TYPE.fire:
		      SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 255)
        case BLOCK_TYPE.wall:
		      SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)
        case BLOCK_TYPE.ground:
		      SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 255)
        case BLOCK_TYPE.door:
		      SDL.SetRenderDrawColor(game.renderer, 155, 155, 155, 255)
      }

      rect := &SDL.Rect {
      x = i32(index % BLOCK_COUNT_WIDTH)*BLOCK_SIZE,
      y = i32(index / BLOCK_COUNT_WIDTH)*BLOCK_SIZE,
      w = BLOCK_SIZE,
      h = BLOCK_SIZE
    }
		SDL.RenderFillRect(game.renderer, rect)
    }

		// Draw the black box at the player's coordinates
		SDL.SetRenderDrawColor(game.renderer, 255, 255, 0, 255) // Black color
		playerRect := &SDL.Rect {
			x = i32(world_state.player_position[0])*BLOCK_SIZE,
			y = i32(world_state.player_position[1])*BLOCK_SIZE,
			w = BLOCK_SIZE,
			h = BLOCK_SIZE,
		} // Assuming player_position is [x, y]
		SDL.RenderFillRect(game.renderer, playerRect)


		// Present the renderer to display the changes
		SDL.RenderPresent(game.renderer)

		SDL.RenderClear(game.renderer)

	}
}


set_world_from_map :: proc(map_path: string) {
	file, _ := png.load_from_file(map_path)

	for i in 0 ..< (len(file.pixels.buf) / 4) {
		red_res: strings.Builder
		red_hex := fmt.sbprintf(&red_res, "%02X", file.pixels.buf[i * 4])
		green_res: strings.Builder
		green_hex := fmt.sbprintf(&green_res, "%02X", file.pixels.buf[i * 4 + 1])
		blue_res: strings.Builder
		blue_hex := fmt.sbprintf(&blue_res, "%02X", file.pixels.buf[i * 4 + 2])

		pixel_hex_color := strings.concatenate({"#", red_hex, green_hex, blue_hex})

    world_state.blocks[i] = COLOR_BLOCK_LOOKUP[pixel_hex_color] or_else BLOCK_TYPE.ground
	}
}


get_block_left::proc(current_position: [2]int) -> BLOCK_TYPE {
  return current_position[0] == 0 ? BLOCK_TYPE.wall : world_state.blocks[current_position[1]*BLOCK_COUNT_WIDTH + current_position[0] - 1]
}

get_block_right::proc(current_position: [2]int) -> BLOCK_TYPE {
  return current_position[0] == BLOCK_COUNT_WIDTH - 1 ? BLOCK_TYPE.wall : world_state.blocks[current_position[1]*BLOCK_COUNT_WIDTH + current_position[0] + 1]
}

get_block_up::proc(current_position: [2]int) -> BLOCK_TYPE {
  return current_position[1] == 0 ? BLOCK_TYPE.wall : world_state.blocks[current_position[1]*BLOCK_COUNT_WIDTH + current_position[0] - BLOCK_COUNT_WIDTH]
}

get_block_down::proc(current_position: [2]int) -> BLOCK_TYPE {
  return current_position[1] == BLOCK_COUNT_HEIGHT - 1 ? BLOCK_TYPE.wall : world_state.blocks[current_position[1]*BLOCK_COUNT_WIDTH + current_position[0] + BLOCK_COUNT_WIDTH]
}
