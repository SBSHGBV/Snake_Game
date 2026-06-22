//============================================================================
// lfsr.v - Linear Feedback Shift Register (LFSR)
//   16-bit LFSR for pseudo-random food position generation
//   Polynomial: x^16 + x^15 + x^13 + x^4 + 1
//   Output is always non-zero (avoids dead state)
//============================================================================
`timescale 1ns / 1ps

module lfsr (
    input  wire        clk,        // 100MHz clock
    input  wire        rst,        // asynchronous reset
    input  wire        seed_en,    // seed enable (load new seed)
    input  wire [15:0] seed_val,   // seed value on game start
    output wire [15:0] rand_out    // 16-bit random output
);

    reg [15:0] lfsr_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr_reg <= 16'hACE1;  // non-zero default seed
        end
        else if (seed_en) begin
            lfsr_reg <= (seed_val == 16'd0) ? 16'hACE1 : seed_val;
        end
        else begin
            // Galois LFSR: shift right, XOR feedback into tap positions
            // Polynomial: x^16 + x^15 + x^13 + x^4 + 1
            // Feedback = lfsr_reg[0]
            lfsr_reg[15] <= lfsr_reg[0];
            lfsr_reg[14] <= lfsr_reg[15] ^ lfsr_reg[0];  // tap at bit 15
            lfsr_reg[13] <= lfsr_reg[14];
            lfsr_reg[12] <= lfsr_reg[13] ^ lfsr_reg[0];  // tap at bit 13
            lfsr_reg[11] <= lfsr_reg[12];
            lfsr_reg[10] <= lfsr_reg[11];
            lfsr_reg[9]  <= lfsr_reg[10];
            lfsr_reg[8]  <= lfsr_reg[9];
            lfsr_reg[7]  <= lfsr_reg[8];
            lfsr_reg[6]  <= lfsr_reg[7];
            lfsr_reg[5]  <= lfsr_reg[6];
            lfsr_reg[4]  <= lfsr_reg[5];
            lfsr_reg[3]  <= lfsr_reg[4] ^ lfsr_reg[0];  // tap at bit 4
            lfsr_reg[2]  <= lfsr_reg[3];
            lfsr_reg[1]  <= lfsr_reg[2];
            lfsr_reg[0]  <= lfsr_reg[1];
        end
    end

    assign rand_out = lfsr_reg;

endmodule
