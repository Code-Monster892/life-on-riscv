# Bare-Metal RISC-V Toolchain Configuration
CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
CFLAGS = -march=rv32im -mabi=ilp32 -O3 -T link.ld -nostartfiles -nostdlib

.PHONY: all clean software sim

all: software sim

# 1. Compile C + Assembly, extract binary, and convert to firmware.hex
software:
	@echo "--- Compiling Bare-Metal Game of Life (Auto Mode) ---"
	$(CC) $(CFLAGS) crt0.s autolife.c -o game.elf
	@echo "--- Extracting Raw Machine Binary ---"
	$(OBJCOPY) -O binary game.elf game.bin
	@echo "--- Converting Binary to Verilog firmware.hex ---"
	python3 -c "import sys; b=sys.stdin.buffer.read(); b += b'\x00' * ((4 - len(b) % 4) % 4); print('\n'.join(b[i:i+4][::-1].hex() for i in range(0,len(b),4)))" < game.bin > firmware.hex
	@echo "firmware.hex successfully generated!"

# 2. Build and run Verilator simulation
sim: software
	@echo "--- Compiling CPU with Verilator ---"
	verilator -Wall -Wno-DECLFILENAME -Wno-UNOPTFLAT -Wno-EOFNEWLINE -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-CASEINCOMPLETE -Wno-SYNCASYNCNET -Wno-PINMISSING -Wno-MODDUP -Wno-IMPORTSTAR -LDFLAGS "-lSDL2" --cc pipeline_types.sv alu.sv be.sv control.sv cpu.sv ex_mem_reg.sv hazard_unit.sv id_ex_reg.sv if_id_reg.sv mem_wb_reg.sv memory.sv multiplier.sv reader.sv regfile.sv signext.sv --exe main.cpp --top-module cpu --build -j 0
	@echo "--- Running Bare-Metal Simulation ---"
	./obj_dir/Vcpu

clean:
	rm -rf obj_dir waveform.vcd game.elf game.bin firmware.hex
