module if_id_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,  // Flush control
    input  logic        en,     // Stall control
    
    input  logic [31:0] if_pc,
    input  logic [31:0] if_instr,
    
    output logic [31:0] id_pc,
    output logic [31:0] id_instr
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc    <= 32'b0;
            id_instr <= 32'h00000013; // RISC-V NOP: addi x0, x0, 0
        end 
        else if (clear) begin
            id_pc    <= 32'b0;
            id_instr <= 32'h00000013; // Inject NOP on flush
        end 
        else if (en) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;     // Normal pipeline flow
        end
        // NOTE: If en == 0 (stall) and clear == 0, no branch is taken:
        // Registers retain their previous values automatically!
    end

endmodule