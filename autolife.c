#define WORLD_W       64
#define WORLD_H       40
#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 200

#define VRAM_BASE     ((volatile unsigned int *)0x02000000)
#define FRAME_PRESENT ((volatile unsigned int *)0x02700000)
#define TIMER_TICKS   ((volatile unsigned int *)0x02500000)

// Vibrant High-Contrast Palette
#define COLOR_BG          0xFF0B0F19 // Deep Midnight Navy
#define COLOR_CELL_ALIVE  0xFF00E5FF // Glowing Electric Cyan

unsigned char grid_current[WORLD_H][WORLD_W];
unsigned char grid_next[WORLD_H][WORLD_W];

// Bare-metal Pseudo-Random Number Generator (LCG)
static unsigned int rand_seed = 0xA3C59241;
unsigned int rand_num() {
    rand_seed = rand_seed * 1664525u + 1013904223u;
    return (rand_seed >> 16) & 0x7FFF;
}

// Fast bare-metal delay
void delay(volatile unsigned int count) {
    while (count--) {
        __asm__ volatile("nop");
    }
}

// Draw Filled 5x5 Block to VRAM for cell (grid_x, grid_y)
void draw_cell(int grid_x, int grid_y, unsigned int color) {
    int start_x = grid_x * 5;
    int start_y = grid_y * 5;

    for (int y = start_y; y < start_y + 4; y++) {
        int row_offset = y * SCREEN_WIDTH;
        for (int x = start_x; x < start_x + 4; x++) {
            VRAM_BASE[row_offset + x] = color;
        }
    }
}

// Direct Full-Screen Renderer (100% Screen Space Fill)
void render_frame() {
    for (int y = 0; y < WORLD_H; y++) {
        for (int x = 0; x < WORLD_W; x++) {
            unsigned int color = grid_current[y][x] ? COLOR_CELL_ALIVE : COLOR_BG;
            draw_cell(x, y, color);
        }
    }

    // Trigger Frame Present to SDL GUI window
    *FRAME_PRESENT = 1;
}

// Count neighbors with toroidal wrapping
int count_neighbors(int y, int x) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dy == 0 && dx == 0) continue;
            int ny = (y + dy + WORLD_H) % WORLD_H;
            int nx = (x + dx + WORLD_W) % WORLD_W;
            count += grid_current[ny][nx];
        }
    }
    return count;
}

// Update Conway rules
void update_grid() {
    for (int y = 0; y < WORLD_H; y++) {
        for (int x = 0; x < WORLD_W; x++) {
            int neighbors = count_neighbors(y, x);
            if (grid_current[y][x]) {
                grid_next[y][x] = (neighbors == 2 || neighbors == 3);
            } else {
                grid_next[y][x] = (neighbors == 3);
            }
        }
    }

    for (int y = 0; y < WORLD_H; y++) {
        for (int x = 0; x < WORLD_W; x++) {
            grid_current[y][x] = grid_next[y][x];
        }
    }
}

int main() {
    // Read high-precision host CPU performance counter for unique random seed every run!
    unsigned int t = *TIMER_TICKS;
    if (t != 0) {
        rand_seed = t ^ (t << 13) ^ (t >> 7);
    }

    // Seed initial pattern (~22% random density across the entire screen)
    for (int y = 0; y < WORLD_H; y++) {
        for (int x = 0; x < WORLD_W; x++) {
            grid_current[y][x] = (rand_num() % 100 < 22) ? 1 : 0;
        }
    }

    // High-speed evolution loop
    while (1) {
        render_frame();
        update_grid();
        delay(2000); // Fast animation speed
    }

    return 0;
}
