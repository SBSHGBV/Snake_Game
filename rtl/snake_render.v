//============================================================================
// snake_render.v - Snake Game VGA Renderer
//   40x30 grid, 16x16 pixels per cell = 640x480
//   Direct combinational read from game state; no double-buffer needed
//   because game grid only changes at 5Hz (200ms intervals).
//============================================================================
`timescale 1ns / 1ps

module snake_render (
    input  wire        clk,                // 100MHz system clock
    input  wire        rst,                // active-high reset
    input  wire        vga_ce,             // VGA clock enable (~25MHz)
    input  wire        video_active,       // VGA active region
    input  wire [9:0]  pixel_x,            // VGA pixel X (0-639)
    input  wire [9:0]  pixel_y,            // VGA pixel Y (0-479)
    input  wire        game_over,          // game over flag
    input  wire        menu_active,        // start menu flag
    input  wire [1:0]  difficulty,         // selected difficulty
    input  wire [15:0] score,              // BCD score
    input  wire [15:0] high_score_easy,    // high scores per difficulty
    input  wire [15:0] high_score_normal,
    input  wire [15:0] high_score_hard,
    input  wire [1199:0] snake_grid_flat,  // 40x30 snake grid
    input  wire [5:0]  food_x,             // food X (0-39)
    input  wire [4:0]  food_y,             // food Y (0-29)
    input  wire [5:0]  head_x,             // snake head X
    input  wire [4:0]  head_y,             // snake head Y
    output reg  [3:0]  vga_r,              // VGA red
    output reg  [3:0]  vga_g,              // VGA green
    output reg  [3:0]  vga_b               // VGA blue
);

    //----------------------------------------------------------------------
    // Cell coordinates (combinational)
    //----------------------------------------------------------------------
    wire [5:0] cell_x = pixel_x[9:4];
    wire [4:0] cell_y = pixel_y[9:4];
    wire [3:0] sub_x  = pixel_x[3:0];
    wire [3:0] sub_y  = pixel_y[3:0];

    wire [10:0] grid_idx = cell_y * 40 + cell_x;
    wire        idx_valid = (cell_x < 6'd40) && (cell_y < 5'd30);

    //----------------------------------------------------------------------
    // Pixel classification (combinational, reads directly from game state)
    //----------------------------------------------------------------------
    wire is_snake     = idx_valid && snake_grid_flat[grid_idx];
    wire is_head      = idx_valid && (cell_x == head_x) && (cell_y == head_y);
    wire is_food      = idx_valid && (cell_x == food_x) && (cell_y == food_y);
    wire is_border    = (pixel_x < 2) || (pixel_x >= 638) ||
                        (pixel_y < 2) || (pixel_y >= 478);
    wire is_grid_line = (sub_x == 4'd0) || (sub_y == 4'd0);

    //----------------------------------------------------------------------
    // Animation frame counter for the menu snake
    //----------------------------------------------------------------------
    reg [25:0] anim_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst)
            anim_cnt <= 26'd0;
        else if (vga_ce)
            anim_cnt <= anim_cnt + 26'd1;
    end

    wire [1:0] orbit_phase = anim_cnt[25:24];
    wire [3:0] anim_step = anim_cnt[25:22];

    //----------------------------------------------------------------------
    // Tiny 5x7 bitmap font helpers
    //----------------------------------------------------------------------
    function [4:0] font5x7;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                "0": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10011; 3'd3: font5x7 = 5'b10101; 3'd4: font5x7 = 5'b11001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "1": case (row) 3'd0: font5x7 = 5'b00100; 3'd1: font5x7 = 5'b01100; 3'd2: font5x7 = 5'b00100; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b00100; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "2": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b00001; 3'd3: font5x7 = 5'b00010; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b01000; 3'd6: font5x7 = 5'b11111; default: font5x7 = 5'b00000; endcase
                "3": case (row) 3'd0: font5x7 = 5'b11110; 3'd1: font5x7 = 5'b00001; 3'd2: font5x7 = 5'b00001; 3'd3: font5x7 = 5'b01110; 3'd4: font5x7 = 5'b00001; 3'd5: font5x7 = 5'b00001; 3'd6: font5x7 = 5'b11110; default: font5x7 = 5'b00000; endcase
                "4": case (row) 3'd0: font5x7 = 5'b00010; 3'd1: font5x7 = 5'b00110; 3'd2: font5x7 = 5'b01010; 3'd3: font5x7 = 5'b10010; 3'd4: font5x7 = 5'b11111; 3'd5: font5x7 = 5'b00010; 3'd6: font5x7 = 5'b00010; default: font5x7 = 5'b00000; endcase
                "5": case (row) 3'd0: font5x7 = 5'b11111; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b11110; 3'd4: font5x7 = 5'b00001; 3'd5: font5x7 = 5'b00001; 3'd6: font5x7 = 5'b11110; default: font5x7 = 5'b00000; endcase
                "6": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b11110; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "7": case (row) 3'd0: font5x7 = 5'b11111; 3'd1: font5x7 = 5'b00001; 3'd2: font5x7 = 5'b00010; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b01000; 3'd5: font5x7 = 5'b01000; 3'd6: font5x7 = 5'b01000; default: font5x7 = 5'b00000; endcase
                "8": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b01110; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "9": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b01111; 3'd4: font5x7 = 5'b00001; 3'd5: font5x7 = 5'b00001; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "A": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b11111; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "C": case (row) 3'd0: font5x7 = 5'b01111; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b10000; 3'd4: font5x7 = 5'b10000; 3'd5: font5x7 = 5'b10000; 3'd6: font5x7 = 5'b01111; default: font5x7 = 5'b00000; endcase
                "D": case (row) 3'd0: font5x7 = 5'b11110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b10001; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b11110; default: font5x7 = 5'b00000; endcase
                "E": case (row) 3'd0: font5x7 = 5'b11111; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b11110; 3'd4: font5x7 = 5'b10000; 3'd5: font5x7 = 5'b10000; 3'd6: font5x7 = 5'b11111; default: font5x7 = 5'b00000; endcase
                "G": case (row) 3'd0: font5x7 = 5'b01111; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b10111; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b01111; default: font5x7 = 5'b00000; endcase
                "H": case (row) 3'd0: font5x7 = 5'b10001; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b11111; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "I": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b00100; 3'd2: font5x7 = 5'b00100; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b00100; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "K": case (row) 3'd0: font5x7 = 5'b10001; 3'd1: font5x7 = 5'b10010; 3'd2: font5x7 = 5'b10100; 3'd3: font5x7 = 5'b11000; 3'd4: font5x7 = 5'b10100; 3'd5: font5x7 = 5'b10010; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "L": case (row) 3'd0: font5x7 = 5'b10000; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b10000; 3'd4: font5x7 = 5'b10000; 3'd5: font5x7 = 5'b10000; 3'd6: font5x7 = 5'b11111; default: font5x7 = 5'b00000; endcase
                "M": case (row) 3'd0: font5x7 = 5'b10001; 3'd1: font5x7 = 5'b11011; 3'd2: font5x7 = 5'b10101; 3'd3: font5x7 = 5'b10101; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "N": case (row) 3'd0: font5x7 = 5'b10001; 3'd1: font5x7 = 5'b11001; 3'd2: font5x7 = 5'b10101; 3'd3: font5x7 = 5'b10011; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "O": case (row) 3'd0: font5x7 = 5'b01110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b10001; 3'd4: font5x7 = 5'b10001; 3'd5: font5x7 = 5'b10001; 3'd6: font5x7 = 5'b01110; default: font5x7 = 5'b00000; endcase
                "P": case (row) 3'd0: font5x7 = 5'b11110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b11110; 3'd4: font5x7 = 5'b10000; 3'd5: font5x7 = 5'b10000; 3'd6: font5x7 = 5'b10000; default: font5x7 = 5'b00000; endcase
                "R": case (row) 3'd0: font5x7 = 5'b11110; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b10001; 3'd3: font5x7 = 5'b11110; 3'd4: font5x7 = 5'b10100; 3'd5: font5x7 = 5'b10010; 3'd6: font5x7 = 5'b10001; default: font5x7 = 5'b00000; endcase
                "S": case (row) 3'd0: font5x7 = 5'b01111; 3'd1: font5x7 = 5'b10000; 3'd2: font5x7 = 5'b10000; 3'd3: font5x7 = 5'b01110; 3'd4: font5x7 = 5'b00001; 3'd5: font5x7 = 5'b00001; 3'd6: font5x7 = 5'b11110; default: font5x7 = 5'b00000; endcase
                "T": case (row) 3'd0: font5x7 = 5'b11111; 3'd1: font5x7 = 5'b00100; 3'd2: font5x7 = 5'b00100; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b00100; 3'd6: font5x7 = 5'b00100; default: font5x7 = 5'b00000; endcase
                "Y": case (row) 3'd0: font5x7 = 5'b10001; 3'd1: font5x7 = 5'b10001; 3'd2: font5x7 = 5'b01010; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b00100; 3'd6: font5x7 = 5'b00100; default: font5x7 = 5'b00000; endcase
                "!": case (row) 3'd0: font5x7 = 5'b00100; 3'd1: font5x7 = 5'b00100; 3'd2: font5x7 = 5'b00100; 3'd3: font5x7 = 5'b00100; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b00000; 3'd6: font5x7 = 5'b00100; default: font5x7 = 5'b00000; endcase
                ">": case (row) 3'd0: font5x7 = 5'b10000; 3'd1: font5x7 = 5'b01000; 3'd2: font5x7 = 5'b00100; 3'd3: font5x7 = 5'b00010; 3'd4: font5x7 = 5'b00100; 3'd5: font5x7 = 5'b01000; 3'd6: font5x7 = 5'b10000; default: font5x7 = 5'b00000; endcase
                default: font5x7 = 5'b00000;
            endcase
        end
    endfunction

    function [7:0] title_char;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: title_char = "S";
                3'd1: title_char = "N";
                3'd2: title_char = "A";
                3'd3: title_char = "K";
                3'd4: title_char = "E";
                3'd5: title_char = "!";
                default: title_char = " ";
            endcase
        end
    endfunction

    function [7:0] score_char;
        input [3:0] idx;
        input [15:0] val;
        begin
            case (idx)
                4'd0: score_char = "S";
                4'd1: score_char = "C";
                4'd2: score_char = "O";
                4'd3: score_char = "R";
                4'd4: score_char = "E";
                4'd5: score_char = 8'd48 + val[15:12];
                4'd6: score_char = 8'd48 + val[11:8];
                4'd7: score_char = 8'd48 + val[7:4];
                default: score_char = 8'd48 + val[3:0];
            endcase
        end
    endfunction

    function [7:0] bcd_digit_char;
        input [1:0] idx;
        input [15:0] val;
        begin
            case (idx)
                2'd0: bcd_digit_char = 8'd48 + val[15:12];
                2'd1: bcd_digit_char = 8'd48 + val[11:8];
                2'd2: bcd_digit_char = 8'd48 + val[7:4];
                default: bcd_digit_char = 8'd48 + val[3:0];
            endcase
        end
    endfunction

    function [7:0] diff_char;
        input [1:0] diff;
        input [2:0] idx;
        begin
            case (diff)
                2'd0: case (idx) 3'd0: diff_char = "E"; 3'd1: diff_char = "A"; 3'd2: diff_char = "S"; 3'd3: diff_char = "Y"; default: diff_char = " "; endcase
                2'd1: case (idx) 3'd0: diff_char = "N"; 3'd1: diff_char = "O"; 3'd2: diff_char = "R"; 3'd3: diff_char = "M"; default: diff_char = " "; endcase
                default: case (idx) 3'd0: diff_char = "H"; 3'd1: diff_char = "A"; 3'd2: diff_char = "R"; 3'd3: diff_char = "D"; default: diff_char = " "; endcase
            endcase
        end
    endfunction

    function [7:0] start_char;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: start_char = "S";
                3'd1: start_char = "T";
                3'd2: start_char = "A";
                3'd3: start_char = "R";
                3'd4: start_char = "T";
                default: start_char = " ";
            endcase
        end
    endfunction

    function font_pixel;
        input [7:0] ch;
        input [2:0] row;
        input [2:0] col;
        reg [4:0] bits;
        begin
            bits = font5x7(ch, row);
            case (col)
                3'd0: font_pixel = bits[4];
                3'd1: font_pixel = bits[3];
                3'd2: font_pixel = bits[2];
                3'd3: font_pixel = bits[1];
                3'd4: font_pixel = bits[0];
                default: font_pixel = 1'b0;
            endcase
        end
    endfunction

    wire [15:0] selected_high =
        (difficulty == 2'd0) ? high_score_easy :
        (difficulty == 2'd1) ? high_score_normal :
                               high_score_hard;

    // Title: SNAKE! on a 64x64 cell grid.
    wire title_area = (pixel_x >= 10'd128) && (pixel_x < 10'd512) &&
                      (pixel_y >= 10'd72)  && (pixel_y < 10'd128);
    wire [9:0] title_lx = pixel_x - 10'd128;
    wire [9:0] title_ly = pixel_y - 10'd72;
    wire [2:0] title_col = title_lx[8:6];
    wire [5:0] title_in_char_x = {3'd0, title_lx[5:3]};
    wire [2:0] title_font_y = title_ly[5:3];
    wire title_pixel = title_area && font_pixel(title_char(title_col), title_font_y, title_in_char_x[2:0]);

    // Menu difficulty line.
    wire diff_area = (pixel_x >= 10'd256) && (pixel_x < 10'd384) &&
                     (pixel_y >= 10'd206) && (pixel_y < 10'd234);
    wire [8:0] diff_lx = pixel_x - 10'd256;
    wire [7:0] diff_ly = pixel_y - 10'd206;
    wire [2:0] diff_col = {1'b0, diff_lx[6:5]};
    wire [5:0] diff_in_char_x = {3'd0, diff_lx[4:2]};
    wire [2:0] diff_font_y = diff_ly[4:2];
    wire diff_pixel = diff_area && font_pixel(diff_char(difficulty, diff_col), diff_font_y, diff_in_char_x[2:0]);
    wire selector_pixel = menu_active &&
                          (((pixel_x >= 10'd180) && (pixel_x < 10'd210)) ||
                           ((pixel_x >= 10'd430) && (pixel_x < 10'd460))) &&
                          (pixel_y >= 10'd210) && (pixel_y < 10'd230) &&
                          (((pixel_y[3:0] > 4'd3) && (pixel_y[3:0] < 4'd12)) ||
                           ((pixel_x[3:0] > 4'd5) && (pixel_x[3:0] < 4'd10)));

    // Selected high score line: SCOREdddd.
    wire high_area = (pixel_x >= 10'd176) && (pixel_x < 10'd464) &&
                     (pixel_y >= 10'd268) && (pixel_y < 10'd296);
    wire [8:0] high_lx = pixel_x - 10'd176;
    wire [7:0] high_ly = pixel_y - 10'd268;
    wire [3:0] high_col = high_lx[8:5];
    wire [5:0] high_in_char_x = {3'd0, high_lx[4:2]};
    wire [2:0] high_font_y = high_ly[4:2];
    wire high_pixel = high_area && font_pixel(score_char(high_col, selected_high), high_font_y, high_in_char_x[2:0]);

    // Per-difficulty history rows.
    wire history_area = (pixel_x >= 10'd96) && (pixel_x < 10'd544) &&
                        (pixel_y >= 10'd320) && (pixel_y < 10'd416);
    wire [9:0] hist_lx = pixel_x - 10'd96;
    wire [8:0] hist_ly = pixel_y - 10'd320;
    wire [1:0] hist_row = hist_ly[6:5];
    wire [3:0] hist_col = hist_lx[8:5];
    wire [5:0] hist_in_char_x = {3'd0, hist_lx[4:2]};
    wire [2:0] hist_font_y = hist_ly[4:2];
    wire [15:0] hist_score = (hist_row == 2'd0) ? high_score_easy :
                              (hist_row == 2'd1) ? high_score_normal :
                                                    high_score_hard;
    wire [3:0] hist_score_col = hist_col - 4'd7;
    wire [7:0] hist_ch = (hist_col < 4'd4) ? diff_char(hist_row[1:0], hist_col[2:0]) :
                         ((hist_col >= 4'd7) && (hist_col < 4'd11)) ? bcd_digit_char(hist_score_col[1:0], hist_score) :
                                                " ";
    wire history_pixel = history_area && (hist_row < 2'd3) &&
                         font_pixel(hist_ch, hist_font_y, hist_in_char_x[2:0]);

    // Start hint.
    wire start_area = (pixel_x >= 10'd240) && (pixel_x < 10'd400) &&
                      (pixel_y >= 10'd430) && (pixel_y < 10'd458);
    wire [8:0] start_lx = pixel_x - 10'd240;
    wire [7:0] start_ly = pixel_y - 10'd430;
    wire [2:0] start_col = start_lx[7:5];
    wire [5:0] start_in_char_x = {3'd0, start_lx[4:2]};
    wire [2:0] start_font_y = start_ly[4:2];
    wire start_blink = anim_cnt[24];
    wire start_pixel = start_area && start_blink &&
                       font_pixel(start_char(start_col), start_font_y, start_in_char_x[2:0]);

    // Orbiting decorative snake near the title.
    wire [9:0] snake_base_x = (orbit_phase == 2'd0) ? 10'd164 :
                              (orbit_phase == 2'd1) ? 10'd448 :
                              (orbit_phase == 2'd2) ? 10'd448 :
                                                       10'd164;
    wire [9:0] snake_base_y = (orbit_phase == 2'd0) ? 10'd44 :
                              (orbit_phase == 2'd1) ? 10'd44 :
                              (orbit_phase == 2'd2) ? 10'd154 :
                                                       10'd154;
    wire snake_horizontal = (orbit_phase == 2'd0) || (orbit_phase == 2'd2);
    wire [9:0] snake_anim_x = snake_horizontal ? (snake_base_x + {6'd0, anim_step}) : snake_base_x;
    wire [9:0] snake_anim_y = snake_horizontal ? snake_base_y : (snake_base_y + {6'd0, anim_step});
    wire orbit_snake_pixel =
        menu_active &&
        (((pixel_x >= snake_anim_x) && (pixel_x < snake_anim_x + 10'd24) &&
          (pixel_y >= snake_anim_y) && (pixel_y < snake_anim_y + 10'd8)) ||
         ((pixel_x >= snake_anim_x + 10'd20) && (pixel_x < snake_anim_x + 10'd28) &&
          (pixel_y >= snake_anim_y - 10'd4) && (pixel_y < snake_anim_y + 10'd12)));

    // In-game score in top-left corner.
    wire game_score_area = (pixel_x >= 10'd8) && (pixel_x < 10'd152) &&
                           (pixel_y >= 10'd8) && (pixel_y < 10'd24);
    wire [7:0] game_score_lx = pixel_x - 10'd8;
    wire [4:0] game_score_ly = pixel_y - 10'd8;
    wire [3:0] game_score_col = game_score_lx[7:4];
    wire [5:0] game_score_in_char_x = {3'd0, game_score_lx[3:1]};
    wire [2:0] game_score_font_y = game_score_ly[3:1];
    wire game_score_pixel = game_score_area &&
                            font_pixel(score_char(game_score_col, score), game_score_font_y, game_score_in_char_x[2:0]);

    //----------------------------------------------------------------------
    // Color generation (registered output on vga_ce)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end
        else if (vga_ce) begin
            if (!video_active) begin
                {vga_r, vga_g, vga_b} <= {4'd0, 4'd0, 4'd0};
            end
            else if (menu_active) begin
                if (title_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd15, 4'd2};
                else if (orbit_snake_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd4, 4'd15, 4'd2};
                else if (diff_pixel || selector_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd4, 4'd12, 4'd15};
                else if (high_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd10, 4'd2};
                else if (history_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd8, 4'd15, 4'd9};
                else if (start_pixel)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd15, 4'd15};
                else if (is_grid_line)
                    {vga_r, vga_g, vga_b} <= {4'd0, 4'd2, 4'd2};
                else
                    {vga_r, vga_g, vga_b} <= {4'd0, 4'd3, 4'd4};
            end
            else if (game_over) begin
                if (is_snake)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd4, 4'd0};
                else if (is_food)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd0, 4'd0};
                else
                    {vga_r, vga_g, vga_b} <= {4'd8, 4'd0, 4'd0};
            end
            else if (is_border) begin
                {vga_r, vga_g, vga_b} <= {4'd6, 4'd6, 4'd6};
            end
            else if (game_score_pixel) begin
                {vga_r, vga_g, vga_b} <= {4'd15, 4'd15, 4'd15};
            end
            else if (is_food) begin
                if (sub_x < 4'd2 || sub_x > 4'd13 || sub_y < 4'd2 || sub_y > 4'd13)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd0, 4'd0};
                else
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd3, 4'd3};
            end
            else if (is_head) begin
                // Snake head: blue
                if (is_grid_line)
                    {vga_r, vga_g, vga_b} <= {4'd0, 4'd4, 4'd15};
                else
                    {vga_r, vga_g, vga_b} <= {4'd4, 4'd8, 4'd15};
            end
            else if (is_snake) begin
                if (is_grid_line)
                    {vga_r, vga_g, vga_b} <= {4'd0, 4'd11, 4'd0};
                else
                    {vga_r, vga_g, vga_b} <= {4'd4, 4'd15, 4'd0};
            end
            else if (is_grid_line) begin
                {vga_r, vga_g, vga_b} <= {4'd0, 4'd2, 4'd0};
            end
            else begin
                {vga_r, vga_g, vga_b} <= {4'd0, 4'd4, 4'd1};
            end
        end
    end

endmodule
