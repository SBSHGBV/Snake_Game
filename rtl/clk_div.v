//============================================================================
// clk_div.v - Clock Divider / Clock Enable Generator
//   Generates clock enable pulses from 100MHz for:
//   - vga_ce:     25MHz equivalent (pulse every 4 cycles)
//   - game_tick:  ~5Hz (pulse every 20M cycles)
//
//   Design note: Using clock enables instead of gated clocks keeps
//   everything in the 100MHz domain, avoiding CDC issues.
//   Note: 7-segment scan timing is managed locally in seven_seg_display.v
//============================================================================
`timescale 1ns / 1ps

module clk_div #(
    parameter GAME_TICK_DIV = 25'd19_999_999  // default 200ms@100MHz; override for sim
) (
    input  wire       clk_100m,    // 100MHz system clock
    input  wire       rst,         // async reset, active high
    output reg        vga_ce,      // 25MHz clock enable (pulse every 4 cycles)
    output reg        game_tick    // game tick pulse (~5Hz), single cycle
);

    //----------------------------------------------------------------------
    // VGA clock enable: 100MHz / 4 = 25MHz
    //----------------------------------------------------------------------
    reg [1:0] vga_cnt;
    always @(posedge clk_100m or posedge rst) begin
        if (rst)
            vga_cnt <= 2'd0;
        else
            vga_cnt <= vga_cnt + 2'd1;
    end

    always @(posedge clk_100m) begin
        vga_ce <= (vga_cnt == 2'd3);  // pulse on count 3
    end

    //----------------------------------------------------------------------
    // Game tick: ~5 Hz (100MHz / (GAME_TICK_DIV+1)), param override for sim
    //----------------------------------------------------------------------
    reg [24:0] game_cnt;  // 25 bits
    wire game_cnt_max = (game_cnt == GAME_TICK_DIV);

    always @(posedge clk_100m or posedge rst) begin
        if (rst)
            game_cnt <= 25'd0;
        else if (game_cnt_max)
            game_cnt <= 25'd0;
        else
            game_cnt <= game_cnt + 25'd1;
    end

    always @(posedge clk_100m or posedge rst) begin
        if (rst)
            game_tick <= 1'b0;
        else
            game_tick <= game_cnt_max;  // single-cycle pulse
    end

endmodule
