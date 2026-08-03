module control (
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [3:0] alu_control,
    output logic [2:0] imm_src,
    output logic       reg_write,
    output logic       mem_write,
    output logic       alu_src,    
    output logic [2:0] result_src,
    output logic       branch,
    output logic       jump,
    output logic       jalr
);
    logic [1:0] alu_op;
    always @(*) begin
        // 1. Set safe defaults for all signals!
        reg_write  = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        result_src = 3'b000;
        imm_src    = 3'b000;
        alu_op     = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        // 2. Main Decoder
        case (op)
            7'b0000011: begin // 'lw' instruction
                reg_write  = 1'b1;
                imm_src    = 3'b000;
                mem_write  = 1'b0;
                alu_src    = 1'b1;  
                result_src = 3'b001;  
                alu_op     = 2'b00; 
            end
            7'b0100011: begin // 'sw' instruction
                mem_write = 1'b1;
                alu_src   = 1'b1;
                imm_src   = 3'b001;
                reg_write = 1'b0;
                result_src= 3'b000;
                alu_op    = 2'b00; 
            end

            7'b1100011: begin // B-Type Instruction (beq)
                reg_write  = 1'b0;
                imm_src    = 3'b010;  
                mem_write  = 1'b0;
                alu_src    = 1'b0;   
                result_src = 3'b000;
                branch     = 1'b1;   
                alu_op     = 2'b01;  
            end
            7'b1101111: begin // J-Type Instruction (jal)
                reg_write  = 1'b1;
                imm_src    = 3'b011;
                mem_write  = 1'b0;
                alu_src    = 1'b0;
                result_src = 3'b010;  // Save PC+4 to register!
                branch     = 1'b0;
                jump       = 1'b1;
                alu_op     = 2'b00;
            end
            7'b0010011: begin // I-Type Arithmatic (addi, etc) 
                reg_write = 1'b1;
                imm_src = 3'b000;   
                mem_write = 1'b0;
                alu_src   = 1'b1;   // ALU uses the immediate, not rs2
                result_src = 3'b000;  // RegFile uses ALU output
                branch = 1'b0;
                jump = 1'b0;
                alu_op    = 2'b10;  // Stop forcing ADD and look at funct3
            end
            7'b0110111: begin // U-Type Instruction (lui) 
                reg_write = 1'b1;     // Write to register
                imm_src   = 3'b100;   // U-Type Immediate (Bits 31-12)
                mem_write = 1'b0;
                alu_src   = 1'b0;   // ALU is not used
                result_src = 3'b011;  // Write Immediate Value directly to RegFile
                branch = 1'b0;
                jump = 1'b0;
                alu_op    = 2'b00;  // ALU doesn't need to do math (or adds 0) 
            end 
            7'b0010111: begin // U-Type Instruction (auipc) 
                reg_write = 1'b1;     // Write to register
                imm_src   = 3'b100;   // U-Type Immediate (Bits 31-12)
                mem_write = 1'b0;
                alu_src   = 1'b0;   // ALU is not used
                result_src = 3'b100;  // Write Immediate Value directly to RegFile
                branch = 1'b0;
                jump = 1'b0;
                alu_op    = 2'b00;  // ALU doesn't need to do math (or adds 0) 
            end 
            7'b1100111: begin // J-Type Instruction (jalr)
                reg_write = 1'b1;
                imm_src   = 3'b000;
                mem_write = 1'b0;
                alu_src   = 1'b1;
                result_src = 3'b010;
                branch = 1'b0;
                jump = 1'b0;
                jalr = 1'b1;
                alu_op    = 2'b00;
            end
            7'b0110011: begin // R-Type Math OR Hardware Multiplication
                reg_write = 1'b1;
                imm_src   = 3'b000;
                mem_write = 1'b0;
                alu_src   = 1'b0;  
                alu_op    = 2'b10;  

                // Look at the secret 0th bit of funct7
                // If it is 1, it's a Hardware Multiply instruction
                if (funct7 == 7'b0000001) begin
                    result_src = 3'b101; // Tell the MUX to listen to the Multiplier
                end else begin
                    result_src = 3'b000; // Tell the MUX to listen to the ALU
                end
            end
        endcase
    end
    // 3. ALU Decoder
    always @(*) begin
        case (alu_op)
           2'b00: alu_control = 4'b0000; // 'lw', 'sw', 'jalr' use ADD
            2'b01: alu_control = 4'b1000; // Unused for branches now, but defaults to SUB
            2'b10: begin // R-Type and I-Type Math
                // If it's R-Type (op[5]==1) OR a Shift instruction (funct3==101)
                if (op[5] == 1'b1 || funct3 == 3'b101) 
                    alu_control = {funct7[5], funct3};
                else // Standard I-Type (addi, slti). Force the top bit to 0!
                    alu_control = {1'b0, funct3};
            end
            default: alu_control = 4'b0000;
        endcase
    end
endmodule