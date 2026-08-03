// SystemVerilog Package for Pipelined Processor Structs
package pipeline_types;

    // 1. IF/ID Pipeline Struct
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
    } if_id_reg_t;

    // 2. ID/EX Pipeline Struct
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] reg_data1;
        logic [31:0] reg_data2;
        logic [31:0] imm_ext;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rd;
        logic [2:0]  funct3;
        
        // Control Signals
        logic        reg_write;
        logic        mem_write;
        logic        alu_src;
        logic [2:0]  result_src;
        logic [3:0]  alu_control;
        logic        branch;
        logic        jump;
        logic        jalr;
    } id_ex_reg_t;

    // 3. EX/MEM Pipeline Struct
    typedef struct packed {
        logic [31:0] alu_result;
        logic [31:0] mul_result;
        logic [31:0] write_data;
        logic [31:0] pc_target;
        logic [31:0] pc_plus4;
        logic [31:0] imm_ext;
        logic [4:0]  rd;
        logic [2:0]  funct3;
        
        // Control Signals
        logic        reg_write;
        logic        mem_write;
        logic [2:0]  result_src;
    } ex_mem_reg_t;

    // 4. MEM/WB Pipeline Struct
    typedef struct packed {
        logic [31:0] alu_result;
        logic [31:0] mul_result;
        logic [31:0] final_read_data;
        logic [31:0] pc_target;
        logic [31:0] pc_plus4;
        logic [31:0] imm_ext;
        logic [4:0]  rd;
        
        // Control Signals
        logic        reg_write;
        logic [2:0]  result_src;
    } mem_wb_reg_t;

endpackage
