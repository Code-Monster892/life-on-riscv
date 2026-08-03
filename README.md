# Bare-Metal RISC-V 32-Bit CPU — Conway's Game of Life

A custom 5-stage pipelined **RV32IM RISC-V Processor** implemented in SystemVerilog, running a bare-metal C implementation of **Conway's Game of Life** rendered via Memory-Mapped I/O (MMIO) and SDL2 graphics.

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

## 📜 License
MIT License. Created for bare-metal RISC-V processor architecture exploration.
