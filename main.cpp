#include "Vcpu.h"
#include "verilated.h"
#include <SDL2/SDL.h>
#include <iostream>

#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 200

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcpu* dut = new Vcpu;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
        std::cerr << "SDL could not initialize! SDL_Error: " << SDL_GetError() << std::endl;
        return -1;
    }

    SDL_Window* window = SDL_CreateWindow("RISC-V Game of Life - Auto Simulation",
                                          SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                          SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2,
                                          SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_RenderSetLogicalSize(renderer, SCREEN_WIDTH, SCREEN_HEIGHT);
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
                                             SDL_TEXTUREACCESS_STREAMING, 
                                             SCREEN_WIDTH, SCREEN_HEIGHT);

    uint32_t* pixels = new uint32_t[SCREEN_WIDTH * SCREEN_HEIGHT];
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) pixels[i] = 0xFF000000;

    dut->clk = 0;
    dut->rst_n = 0;

    bool quit = false;
    SDL_Event e;
    
    std::cout << "==========================================================" << std::endl;
    std::cout << " Starting Bare-Metal RISC-V Game of Life (Auto Mode)     " << std::endl;
    std::cout << " Random pattern generated. Simulation running on hardware " << std::endl;
    std::cout << "==========================================================" << std::endl;

    int cycles = 0;

    while (!quit) {
        while (SDL_PollEvent(&e) != 0) {
            if (e.type == SDL_QUIT) quit = true;
        }

        // Release reset on clock tick 4
        if (cycles == 4) dut->rst_n = 1;

        // PHASE 1: Combinational logic evaluation (clk = 0)
        dut->clk = 0;
        dut->eval();

        // Feed MMIO Read Data and RE-EVALUATE combinational logic
        dut->mmio_read_data = 0;
        if (dut->mmio_read_en) {
            if (dut->mmio_address == 0x02500000) {
                // Return high-resolution host CPU counter for unique entropy every run!
                dut->mmio_read_data = (uint32_t)SDL_GetPerformanceCounter();
            } else if (dut->mmio_address == 0x02600000) {
                dut->mmio_read_data = 0;
            }
            dut->eval(); // Propagate mmio_read_data before clk posedge
        }

        // Handle MMIO Writes from CPU
        if (dut->mmio_we) {
            if (dut->mmio_address >= 0x02000000 && dut->mmio_address < 0x02000000 + (SCREEN_WIDTH * SCREEN_HEIGHT * 4)) {
                // VRAM Pixel Write
                uint32_t offset = (dut->mmio_address - 0x02000000) / 4;
                pixels[offset] = dut->mmio_write_data;
            } else if (dut->mmio_address == 0x02700000) {
                // Frame Present Trigger (update SDL GUI window)
                SDL_UpdateTexture(texture, NULL, pixels, SCREEN_WIDTH * sizeof(uint32_t));
                SDL_RenderClear(renderer);
                SDL_RenderCopy(renderer, texture, NULL, NULL);
                SDL_RenderPresent(renderer);
            } else if (dut->mmio_address == 0x10000000) {
                // Console ASCII output
                std::putchar((char)dut->mmio_write_data);
                std::fflush(stdout);
            }
        }

        // PHASE 2: Clock Rising Edge (clk = 1)
        dut->clk = 1;
        dut->eval();

        cycles++;
    }

    delete[] pixels;
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    delete dut;

    return 0;
}
