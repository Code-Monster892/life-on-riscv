# Bare-Metal RISC-V 32-Bit CPU — Conway's Game of Life

A custom 5-stage pipelined **RV32IM RISC-V Processor** implemented in SystemVerilog, running a bare-metal C implementation of **Conway's Game of Life** rendered via Memory-Mapped I/O (MMIO) and SDL2 graphics. 

(NEW!! Added Project report as a pdf consisting of necessary theoretical data for the repo)

[Read Life on RISC-V (PDF)](./life-on-riscv.pdf)

<img width="642" height="426" alt="image" src="https://github.com/user-attachments/assets/0cba3d8a-e554-45d7-9046-138b0b38803e" />
<img width="645" height="427" alt="image" src="https://github.com/user-attachments/assets/05b938b1-ced8-422d-afd5-bdf5dcd6ca98" />
<img width="642" height="426" alt="image" src="https://github.com/user-attachments/assets/c20571b1-6adf-41df-8a2f-201f2b552e2b" />



---

## ✨ Features

* **Pipelined RV32IM Core**:
  * 5-stage classic pipeline (IF, ID, EX, MEM, WB) with hazard detection and full data forwarding.
  * Hardware multiplier and divider (`M` extension support).
  * Byte Enable Decoder (`be.sv`) & Memory Reader (`reader.sv`) supporting byte (`sb`, `lb`, `lbu`), halfword (`sh`, `lh`, `lhu`), and word (`sw`, `lw`) instructions.
* **Bare-Metal C Application (`autolife.c`)**:
  * Zero-dependency C firmware compiled with `riscv64-unknown-elf-gcc` (`-march=rv32im -mabi=ilp32 -O3`).
  * Custom low-level boot assembly (`crt0.s`) for stack initialization and `.bss` section zeroing.
  * Precise RISC-V linker memory map (`link.ld`) for 16MB RAM.
* **Graphics & Hardware MMIO**:
  * 32-bit ARGB VRAM mapping (`0x02000000`) for 320x200 pixel rendering.
  * Hardware Frame Present trigger (`0x02700000`) for SDL2 GUI refresh.
  * Dynamic PRNG seeding via high-resolution host CPU performance counter (`0x02500000`), generating unique random cell patterns on every run.
  * Full 16:10 aspect ratio matching ($64 \times 40$ world grid rendered at 5px/cell) filling 100% of the screen space.

---

## 📁 Repository Structure

| File | Description |
| :--- | :--- |
| [cpu.sv](cpu.sv) | Top-level 5-stage pipelined RISC-V CPU module |
| [memory.sv](memory.sv) | Synchronous RAM module & MMIO address guard |
| [pipeline_types.sv](pipeline_types.sv) | SystemVerilog struct definitions for pipeline registers |
| [alu.sv](alu.sv) | Arithmetic Logic Unit |
| [multiplier.sv](multiplier.sv) | RV32M hardware multiplier and divider module |
| [control.sv](control.sv) | Main instruction decoder and control unit |
| [hazard_unit.sv](hazard_unit.sv) | Data forwarding and load-use stall detection unit |
| [be.sv](be.sv) | Byte enable mask decoder for stores (`sb`, `sh`, `sw`) |
| [reader.sv](reader.sv) | Memory load extractor for signed/unsigned reads |
| [regfile.sv](regfile.sv) | 32 x 32-bit RISC-V Register File |
| [signext.sv](signext.sv) | Immediate sign-extension unit |
| [if_id_reg.sv](if_id_reg.sv), [id_ex_reg.sv](id_ex_reg.sv), [ex_mem_reg.sv](ex_mem_reg.sv), [mem_wb_reg.sv](mem_wb_reg.sv) | Pipeline stage registers |
| [crt0.s](crt0.s) | Bare-metal startup assembly entry point (`_start`) |
| [link.ld](link.ld) | RISC-V linker script for 16MB RAM layout |
| [autolife.c](autolife.c) | Bare-metal Game of Life application & PRNG |
| [main.cpp](main.cpp) | Verilator C++ simulation driver with SDL2 GUI harness |
| [Makefile](Makefile) | Toolchain compilation & Verilator build automation |

---

## 🛠️ Prerequisites

* **GCC RISC-V Cross Compiler**: `riscv64-unknown-elf-gcc`
* **Verilator**: `verilator` (v5.0+)
* **SDL2 Library**: `libsdl2-dev`
* **Python 3**: `python3`

---

## 🚀 How to Build & Run

### 1. Build Software Firmware (`firmware.hex`)
Compiles `crt0.s` and `autolife.c`, extracts the raw binary, and generates big-endian `firmware.hex` for Verilog `$readmemh`:

```bash
make software
```

### 2. Build & Launch Hardware Simulation
Compiles SystemVerilog CPU files using Verilator and launches the live graphical GUI:

```bash
make sim
```

### 3. Clean Build Artifacts
```bash
make clean
```

---

## Conway's Game of Life & Architectural Assessment Overview

Conway's Game of Life is a zero-player cellular automaton devised by mathematician John Conway. The game evolves on a 2D grid of square cells, where each cell exists in one of two possible states: alive or dead. The state of the board progresses through discrete generations based on a deterministic set of mathematical rules applied to every cell simultaneously.

#### The Rules:
Every cell interacts with its eight immediate neighbors (horizontally, vertically, and diagonally). For each generation step, the following state transitions occur:
Underpopulation: Any live cell with fewer than two live neighbors dies.  
Survival: Any live cell with two or three live neighbors lives on to the next generation.  
Overpopulation: Any live cell with more than three live neighbors dies.  
Reproduction: Any dead cell with exactly three live neighbors becomes a live cell.  

## How It Stresses & Assesses the RV32IM Architecture

Running Conway's Game of Life bare-metal is an exceptionally rigorous benchmark for a custom CPU pipeline. Rather than executing isolated synthetic tests, the algorithm forces the hardware to resolve real-world software bottlenecks:
1. Calculating cell neighbors requires continuous reads and updates across 2D array buffers in memory. This constantly exercises the Memory stage, testing the Byte-Enable [be.sv](be.sv) and Reader [reader.sv](reader.sv) units during byte-level (lb, sb) load/store operations.
2. Evaluating board boundaries and neighbor thresholds creates dense nested loops. The algorithm heavily relies on conditional branch instructions (beq, bne, blt, bge), forcing the Hazard Unit [hazard_unit.sv](hazard_unit.sv) to resolve control hazards through EX-stage branch detection and 2-cycle pipeline flushes.
3. Frequent state updates between adjacent loop iterations create immediate Read-After-Write (RAW) data dependencies. This tests the EX/MEM and MEM/WB forwarding paths, verifying that data bypasses function flawlessly without stalling unnecessarily
4. Index calculations for multi-dimensional arrays (mapping 2D row/column coordinates to 1D flat memory space) natively generate explicit 32-bit integer multiplication instructions (mul). This validates the Hardware Multiplier [multiplier.sv](multiplier.sv) under continuous execution, ensuring hardware math results correctly route through the Write-Back stage via result_src.

<img width="650" height="434" alt="ezgif-7edf1143af9776b6" src="https://github.com/user-attachments/assets/39cbad67-5f51-4de5-adcb-a1ad7284f885" />

