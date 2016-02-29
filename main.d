/*
* DGBA: a Gameboy Advance emulator
* DGBA is licensed under the AGPL v3
* Copyright (c) 2016, Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
*/

import std.stdio;
import std.conv;
import core.thread;
import std.string;
import sdl;
import types;
import helper;


string file_name = null;

public class Screen {
	static immutable int x = 240;
	static immutable int y = 160;
	static immutable int width = 240;
	static immutable int height = 160;
}


enum ProcessorMode : u8 {
	Undefined = 0b11011,
	User = 0b10000,
	FIQ = 0b10001,
	IRQ = 0b10010,
	Supervisor = 0b10011,
	Abort = 0b10111,
	System = 0b11111,
}

class CPU {
	static immutable string make = "ARM7";
	static immutable string model = "ARM7tdmi";
	static immutable u8 bits = 32;
	static immutable u32 clock_speed = 1_678_000;

	u32 _r0;
	u32 _r1;
	u32 _r2;
	u32 _r3;
	u32 _r4;
	u32 _r5;
	u32 _r6;
	u32 _r7;
	u32 _r8;
	u32 _r9;
	u32 _r10;
	u32 _r11;
	u32 _r12;

	u32 _sp; // Stack Pointer
	u32 _lr; // Link Register
	u32 _pc; // Program Counter
	u32 _ps; // Current Program Status Register

	u32 _ticks;
	u32 _opcode;
	bool _is_running;
	//u8 _value;
	u8[0x4000] _system_rom;

	u8 get_processor_mode() {
		u8 mode = _ps & 0b11111;
		switch (mode) {
			case ProcessorMode.Undefined: return ProcessorMode.Undefined;
			case ProcessorMode.User: return ProcessorMode.User;
			case ProcessorMode.FIQ: return ProcessorMode.FIQ;
			case ProcessorMode.IRQ: return ProcessorMode.IRQ;
			case ProcessorMode.Supervisor: return ProcessorMode.Supervisor;
			case ProcessorMode.Abort: return ProcessorMode.Abort;
			case ProcessorMode.System: return ProcessorMode.System;
			default: throw new Exception("Unknown Processor Mode");
		}
	}

	bool is_thumb_state() {
		return (_ps & (1 << 5)) > 0;
	}

	bool FIQ_interrupt_disabled() {
		return (_ps & (1 << 6)) > 0;
	}

	bool IRQ_interrupt_disabled() {
		return (_ps & (1 << 7)) > 0;
	}

	bool is_overflow() {
		return (_ps & (1 << 28)) > 0;
	}

	bool is_carry() {
		return (_ps & (1 << 29)) > 0;
	}

	bool is_zero() {
		return (_ps & (1 << 30)) > 0;
	}

	bool is_negative() {
		return (_ps & (1 << 31)) > 0;
	}

	public this() {
		_sp = 0x03007F00;

		_is_running = true;
	}

	void reset() {
	}

	void run_next_operation() {
	}
}

immutable u32 HEADER_SIZE = 16;

public void load_cart() {
	// Read the file into an array
	auto f = std.stdio.File(file_name, "r");
	char[HEADER_SIZE] header;
	f.rawRead(header);
	writefln("header size: %dB", header.length);

	f.close();
}

int main(string[] args) {
/*
	// Make backtraces work in Linux
	version(linux) {
		import backtrace;
		PrintOptions options;
		options.detailedForN = 2;        //number of frames to show code for
		options.numberOfLinesBefore = 3; //number of lines of code to show before the specific line
		options.numberOfLinesAfter = 3;  //number of lines of code to show after the specific line
		options.colored = false;         //enable colored output for the backtrace
		options.stopAtDMain = true;      //show stack traces after the entry point of the D code
		backtrace.install(stderr, options);
	}
*/
	// Make sure a file name was passed
	if (args.length < 2) {
		stderr.writeln("Usage: ./main example.gba");
		return -1;
	}
	file_name = args[1];

	// Initialize SDL, exit if there is an error
	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		stderr.writefln("Could not initialize SDL: %s", SDL_GetError());
		return -1;
	}
	
	// Grab a surface on the screen
	SDL_Surface* sdl_screen = SDL_SetVideoMode(Screen.width+Screen.x, Screen.height+Screen.y, 32, SDL_SWSURFACE|SDL_ANYFORMAT);
	if (!sdl_screen) {
		stderr.writefln("Couldn't create a surface: %s", SDL_GetError());
		return -1;
	}

	auto cpu = new CPU();
	cpu.reset();

	bool is_draw_time = false;
	while (cpu._is_running) {
		// Run the next operation
		try {
			cpu.run_next_operation();
		} catch(Exception err) {
			writefln("Unhandled Exception: %s", err);
			Thread.sleep(dur!("msecs")(5000));
			return -1;
		}

		// https://www.cs.rit.edu/~tjh8300/CowBite/CowBiteSpec.htm#Graphics%20Hardware%20Overview
		// Each scanline

		if(is_draw_time) {
			// Check for quit events
			SDL_Event sdl_event;
			while(SDL_PollEvent(&sdl_event) == 1) {
				if(sdl_event.type == SDL_QUIT)
					cpu._is_running = false;
			}

			// Lock the screen if needed
			if(SDL_MUSTLOCK(sdl_screen)) {
				if(SDL_LockSurface(sdl_screen) < 0)
					return -1;
			}

			// Actually draw the screen


			// Unlock the screen if needed
			if(SDL_MUSTLOCK(sdl_screen)) {
				SDL_UnlockSurface(sdl_screen);
			}

			// Show the newly drawn screen
			SDL_Flip(sdl_screen);
			is_draw_time = false;
		}

//		Thread.sleep(dur!("msecs")(100));
	}

	SDL_Quit();

	return 0;
}



