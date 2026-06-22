//============================================================================
// seven_seg_display.v - 7-Segment Display Driver
//   Drives 4-digit common-anode 7-segment display
//   Displays score (0-9999) with dynamic scanning
//============================================================================
`timescale 1ns / 1ps

module seven_seg_display (
    input  wire        clk,         // 100MHz clock
    input  wire        rst,         // reset
    input  wire [15:0] score,       // score value to display (0-9999)
    output reg  [3:0]  AN,          // anode select (active low)
    output reg  [7:0]  SEGMENT      // segment outputs (active low)
);

    //----------------------------------------------------------------------
    // Scan state machine: use 2-bit counter
    //----------------------------------------------------------------------
    reg [16:0] scan_cnt;
    wire [1:0] scan = scan_cnt[16:15];

    always @(posedge clk or posedge rst) begin
        if (rst)
            scan_cnt <= 17'd0;
        else
            scan_cnt <= scan_cnt + 17'd1;
    end

    //----------------------------------------------------------------------
    // Extract BCD digits from score (simple approach: keep score as 4 BCD digits)
    // Input score[15:0] is interpreted as 4 BCD digits: score[15:12], [11:8], [7:4], [3:0]
    //----------------------------------------------------------------------
    wire [3:0] digit0 = score[3:0];    // ones
    wire [3:0] digit1 = score[7:4];    // tens
    wire [3:0] digit2 = score[11:8];   // hundreds
    wire [3:0] digit3 = score[15:12];  // thousands

    //----------------------------------------------------------------------
    // Mux: select current digit based on scan
    //----------------------------------------------------------------------
    reg [3:0] cur_digit;
    always @(*) begin
        case (scan)
            2'b00: begin
                AN = 4'b1110;   // AN[0] active
                cur_digit = digit0;
            end
            2'b01: begin
                AN = 4'b1101;   // AN[1] active
                cur_digit = digit1;
            end
            2'b10: begin
                AN = 4'b1011;   // AN[2] active
                cur_digit = digit2;
            end
            2'b11: begin
                AN = 4'b0111;   // AN[3] active
                cur_digit = digit3;
            end
            default: begin
                AN = 4'b1111;
                cur_digit = 4'd0;
            end
        endcase
    end

    //----------------------------------------------------------------------
    // 7-segment decoder: 4-bit BCD to 7-segment (active low)
    // Segment mapping: SEGMENT[7] = DP, [6]=g, [5]=f, [4]=e, [3]=d, [2]=c, [1]=b, [0]=a
    //----------------------------------------------------------------------
    always @(*) begin
        SEGMENT[7] = 1'b1;  // DP off
        case (cur_digit)
            4'd0: SEGMENT[6:0] = 7'b1000000;  // 0
            4'd1: SEGMENT[6:0] = 7'b1111001;  // 1
            4'd2: SEGMENT[6:0] = 7'b0100100;  // 2
            4'd3: SEGMENT[6:0] = 7'b0110000;  // 3
            4'd4: SEGMENT[6:0] = 7'b0011001;  // 4
            4'd5: SEGMENT[6:0] = 7'b0010010;  // 5
            4'd6: SEGMENT[6:0] = 7'b0000010;  // 6
            4'd7: SEGMENT[6:0] = 7'b1111000;  // 7
            4'd8: SEGMENT[6:0] = 7'b0000000;  // 8
            4'd9: SEGMENT[6:0] = 7'b0010000;  // 9
            default: SEGMENT[6:0] = 7'b1111111;  // blank
        endcase
    end

endmodule
