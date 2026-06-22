//============================================================================
// snake_render.v - Snake Game VGA Renderer
//   40x30 grid, 16x16 pixels per cell = 640x480
//   Direct combinational read from game state — no double-buffer needed
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
            else if (is_food) begin
                if (sub_x < 4'd2 || sub_x > 4'd13 || sub_y < 4'd2 || sub_y > 4'd13)
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd0, 4'd0};
                else
                    {vga_r, vga_g, vga_b} <= {4'd15, 4'd3, 4'd3};
            end
            else if (is_head) begin
                // Snake head — blue
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
