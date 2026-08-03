module cpu (
    input logic clk,
    input logic rst_n,
    
    // MMIO Interface
    output logic        mmio_we,
    output logic        mmio_read_en,
    output logic [31:0] mmio_address,
    output logic [31:0] mmio_write_data,
    input  logic [31:0] mmio_read_data,

    // Debug
    output logic [31:0] pc_out
);

    import pipeline_types::*;

    `ifdef COCOTB_SIM
    initial begin
        $dumpfile("sim_build/waveform.vcd");
        $dumpvars(0, cpu);
    end
    `endif

    
    // PIPELINE REGISTERS (STRUCTS)
    
    id_ex_reg_t  id_ex_in, id_ex_out;
    ex_mem_reg_t ex_mem_in, ex_mem_out;
    mem_wb_reg_t mem_wb_in, mem_wb_out;
    logic stall_f, stall_d, flush_e, flush_d;

    
    // STAGE 1: INSTRUCTION FETCH (IF)
    
    logic [31:0] if_pc, next_pc;
    assign pc_out = if_pc;
    logic [31:0] if_instr;
    
    // EX Stage Branch Target and Redirect Control Wires
    logic        pc_src_e;
    logic [31:0] pc_target_e;

    // Next PC: Target if Branch/Jump taken in EX, else PC+4
    assign next_pc = pc_src_e ? pc_target_e : (if_pc + 32'd4);

    // ID stage wires from if_id_reg
    logic [31:0] id_pc;
    logic [31:0] id_instr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       if_pc <= 32'b0;
        else if (!stall_f) if_pc <= next_pc;    // Freeze PC on stall
    end

    // Instruction & Data Memory
    logic [31:0] ram_read_data;

    memory mem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .we(ex_mem_out.mem_write & (ex_mem_out.alu_result < 32'h01000000)), // Write to RAM only if address < 0x01000000
        .mask(mem_mask),                       // Mask from MEM stage
        .address(ex_mem_out.alu_result),       // Address from MEM stage
        .write_data(shifted_write_data),       // Write data from MEM stage
        .read_data(ram_read_data),             // Read data output from RAM
        .pc_address(if_pc),                    // Fetch address = if_pc
        .instruction(if_instr)                 // Fetch output  = if_instr
    );

    // IF/ID Pipeline Register: Passes if_pc and if_instr to the ID stage
    if_id_reg if_id_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(flush_d), // Flushes wrong-path instruction on Branch Taken in EX
        .en(~stall_d),   // Freeze IF/ID register on stall
        .if_pc(if_pc),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_instr(id_instr)
    );

    
    // STAGE 2: INSTRUCTION DECODE (ID)
    
    
    // Register File Wires
    logic [31:0] reg_data1, reg_data2;
    logic [31:0] writeback_data; // From WB stage
    logic [31:0] imm_ext;
    
    // Control Wires
    logic       reg_write, mem_write, alu_src;
    logic [2:0] result_src;
    logic [2:0] imm_src;
    logic [3:0] alu_control;
    logic       branch, jump, jalr;

    control ctrl_inst (
        .op(id_instr[6:0]),          
        .funct3(id_instr[14:12]),
        .funct7(id_instr[31:25]),
        .alu_control(alu_control),
        .imm_src(imm_src),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .result_src(result_src),
        .branch(branch),
        .jump(jump),
        .jalr(jalr)
    );

    // Register file reads in ID, writes in WB
    regfile regf_inst (
        .clk(clk),
        .rst_n(rst_n),
        .address1(id_instr[19:15]),  // rs1
        .address2(id_instr[24:20]),  // rs2
        .address3(mem_wb_out.rd),    // rd comes from WB stage
        .write_data(writeback_data), // data comes from WB stage
        .write_enable(mem_wb_out.reg_write), // WE comes from WB stage
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    signext sext_inst (
        .instr(id_instr),            
        .imm_src(imm_src),
        .imm_ext(imm_ext)
    );

    // Pack ID data into ID/EX struct
    assign id_ex_in.pc          = id_pc;
    assign id_ex_in.reg_data1   = reg_data1;
    assign id_ex_in.reg_data2   = reg_data2;
    assign id_ex_in.imm_ext     = imm_ext;
    assign id_ex_in.rs1         = id_instr[19:15];
    assign id_ex_in.rs2         = id_instr[24:20];
    assign id_ex_in.rd          = id_instr[11:7];
    assign id_ex_in.funct3      = id_instr[14:12];
    assign id_ex_in.reg_write   = reg_write;
    assign id_ex_in.mem_write   = mem_write;
    assign id_ex_in.alu_src     = alu_src;
    assign id_ex_in.result_src  = result_src;
    assign id_ex_in.alu_control = alu_control;
    assign id_ex_in.branch      = branch;
    assign id_ex_in.jump        = jump;
    assign id_ex_in.jalr        = jalr;

    id_ex_reg id_ex_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(flush_e), // Injects NOP bubble on stall or Branch Taken in EX
        .en(1'b1),
        .in(id_ex_in),
        .out(id_ex_out)
    );

   
    // STAGE 3: EXECUTE (EX)
   
    
    // Forwarding Wires
    logic [1:0]  forward_a_e, forward_b_e;
    logic [31:0] src_a_fw, src_b_fw;
    logic [31:0] mem_fwd_data;
    always_comb begin
        case (ex_mem_out.result_src)
            3'b000: mem_fwd_data = ex_mem_out.alu_result;  // ALU math
            3'b010: mem_fwd_data = ex_mem_out.pc_plus4;   // JAL / JALR return address
            3'b011: mem_fwd_data = ex_mem_out.imm_ext;    // LUI upper immediate
            3'b100: mem_fwd_data = ex_mem_out.pc_target;   // AUIPC target address
            3'b101: mem_fwd_data = ex_mem_out.mul_result;  // Hardware multiplier
            default: mem_fwd_data = 32'b0;                 // Loads forward from WB stage only
        endcase
    end

    logic [31:0] alu_src_b, alu_result, mul_result;

    // Forwarding Mux A (Operand 1)
    always_comb begin
        case(forward_a_e)
            2'b00:   src_a_fw = id_ex_out.reg_data1;    // No forwarding
            2'b01:   src_a_fw = writeback_data;         // Forward from WB stage
            2'b10:   src_a_fw = mem_fwd_data;          // Forward from MEM stage
            default: src_a_fw = id_ex_out.reg_data1;
        endcase
    end

    // Forwarding Mux B (Operand 2)
    always_comb begin
        case(forward_b_e)
            2'b00:   src_b_fw = id_ex_out.reg_data2;    // No forwarding
            2'b01:   src_b_fw = writeback_data;         // Forward from WB stage
            2'b10:   src_b_fw = mem_fwd_data;          // Forward from MEM stage
            default: src_b_fw = id_ex_out.reg_data2;
        endcase
    end

    // ALU input B selection
    assign alu_src_b = (id_ex_out.alu_src) ? id_ex_out.imm_ext : src_b_fw;

    alu alu_inst (
        .src1(src_a_fw),
        .src2(alu_src_b),
        .alu_control(id_ex_out.alu_control),
        .alu_result(alu_result)
    );

    multiplier mul_inst (
        .src1(src_a_fw),
        .src2(alu_src_b),
        .funct3(id_ex_out.funct3),    
        .mul_result(mul_result)
    );

    // EX-Stage Branch Comparator (Evaluates fully forwarded src_a_fw & src_b_fw!)
    logic take_branch;
    always_comb begin
        case(id_ex_out.funct3)       
            3'b000: take_branch = (src_a_fw == src_b_fw);                 // beq
            3'b001: take_branch = (src_a_fw != src_b_fw);                 // bne
            3'b100: take_branch = ($signed(src_a_fw) < $signed(src_b_fw)); // blt
            3'b101: take_branch = ($signed(src_a_fw) >= $signed(src_b_fw));// bge
            3'b110: take_branch = (src_a_fw < src_b_fw);                  // bltu
            3'b111: take_branch = (src_a_fw >= src_b_fw);                 // bgeu
            default: take_branch = 1'b0;
        endcase
    end

    // EX-Stage Redirect Control & Target Calculation
    assign pc_src_e = (id_ex_out.branch & take_branch) | id_ex_out.jump | id_ex_out.jalr;
    assign pc_target_e = id_ex_out.jalr ? ((src_a_fw + id_ex_out.imm_ext) & 32'hFFFFFFFE)
                                        : (id_ex_out.pc + id_ex_out.imm_ext);

    hazard_unit hazard_inst (
        // ID Stage Inputs (for Load-Use Stall detection)
        .rs1_d(id_instr[19:15]),
        .rs2_d(id_instr[24:20]),
        
        // EX Stage Inputs (for Forwarding & Load-Use Stall detection)
        .rs1_e(id_ex_out.rs1),
        .rs2_e(id_ex_out.rs2),
        .rd_e(id_ex_out.rd),
        .result_src_e(id_ex_out.result_src),
        .pc_src_e(pc_src_e),
        
        // MEM Stage Inputs
        .reg_write_m(ex_mem_out.reg_write),
        .rd_m(ex_mem_out.rd),
        
        // WB Stage Inputs
        .reg_write_w(mem_wb_out.reg_write),
        .rd_w(mem_wb_out.rd),
        
        // Outputs
        .forward_a_e(forward_a_e),
        .forward_b_e(forward_b_e),
        .stall_f(stall_f),
        .stall_d(stall_d),
        .flush_d(flush_d),
        .flush_e(flush_e)
    );

    // Pack EX data into EX/MEM struct
    assign ex_mem_in.alu_result = alu_result;
    assign ex_mem_in.mul_result = mul_result;
    assign ex_mem_in.write_data = src_b_fw;
    assign ex_mem_in.pc_target  = pc_target_e;
    assign ex_mem_in.pc_plus4   = id_ex_out.pc + 32'd4;
    assign ex_mem_in.imm_ext    = id_ex_out.imm_ext;
    assign ex_mem_in.rd         = id_ex_out.rd;
    assign ex_mem_in.funct3     = id_ex_out.funct3;
    assign ex_mem_in.reg_write  = id_ex_out.reg_write;
    assign ex_mem_in.mem_write  = id_ex_out.mem_write;
    assign ex_mem_in.result_src = id_ex_out.result_src;

    ex_mem_reg ex_mem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(1'b0),
        .en(1'b1),
        .in(ex_mem_in),
        .out(ex_mem_out)
    );


    // STAGE 4: MEMORY (MEM)

    logic [3:0] mem_mask;
    logic [31:0] shifted_write_data;
    logic [31:0] mem_read_data;
    logic [31:0] final_read_data;

    // --- MMIO Routing ---
    assign mmio_we          = ex_mem_out.mem_write & (ex_mem_out.alu_result >= 32'h01000000);
    assign mmio_read_en     = (ex_mem_out.result_src == 3'b001) & (ex_mem_out.alu_result >= 32'h01000000);
    assign mmio_address     = ex_mem_out.alu_result;
    assign mmio_write_data  = ex_mem_out.write_data;

    // Multiplex read data between RAM and MMIO
    assign mem_read_data    = (ex_mem_out.alu_result >= 32'h01000000) ? mmio_read_data : ram_read_data;

    be be_inst (
        .funct3(ex_mem_out.funct3),   
        .offset(ex_mem_out.alu_result[1:0]),
        .write_data(ex_mem_out.write_data),
        .mask(mem_mask),
        .shifted_data(shifted_write_data)
    );

    reader reader_inst (
        .funct3(ex_mem_out.funct3),   
        .offset(ex_mem_out.alu_result[1:0]),
        .raw_read_data(mem_read_data),
        .final_read_data(final_read_data)
    );

    // Pack MEM data into MEM/WB struct
    assign mem_wb_in.alu_result      = ex_mem_out.alu_result;
    assign mem_wb_in.mul_result      = ex_mem_out.mul_result;
    assign mem_wb_in.final_read_data = final_read_data;
    assign mem_wb_in.pc_target       = ex_mem_out.pc_target;
    assign mem_wb_in.pc_plus4        = ex_mem_out.pc_plus4;
    assign mem_wb_in.imm_ext         = ex_mem_out.imm_ext;
    assign mem_wb_in.rd              = ex_mem_out.rd;
    assign mem_wb_in.reg_write       = ex_mem_out.reg_write;
    assign mem_wb_in.result_src      = ex_mem_out.result_src;

    mem_wb_reg mem_wb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(1'b0),
        .en(1'b1),
        .in(mem_wb_in),
        .out(mem_wb_out)
    );



    // STAGE 5: WRITE-BACK (WB)
  
    
    always_comb begin
        case(mem_wb_out.result_src)
            3'b000: writeback_data = mem_wb_out.alu_result;       // Track 0: ALU math
            3'b001: writeback_data = mem_wb_out.final_read_data;  // Track 1: Extracted Memory load
            3'b010: writeback_data = mem_wb_out.pc_plus4;         // Track 2: Return address for JAL
            3'b011: writeback_data = mem_wb_out.imm_ext;          // Track 3: Immediate value
            3'b100: writeback_data = mem_wb_out.pc_target;        // Track 4: for auipc
            3'b101: writeback_data = mem_wb_out.mul_result;       // Track 5: Hardware Multiplier
            default: writeback_data = 32'b0;
        endcase
    end

endmodule