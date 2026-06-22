//============================================================================
// vga_controller.v - VGA Timing Controller (640x480 @ 60Hz equivalent)
//   Runs at 100MHz with vga_ce (clock enable, pulses @ 25MHz equivalent)
//   All registers in 100MHz domain for clean single-clock design.
//
//   Timing (@ 25MHz effective):
//     Horizontal: 800 total (640 vis + 16 fp + 96 sync + 48 bp)
//     Vertical:   525 total (480 vis + 10 fp + 2 sync  + 33 bp)
//============================================================================
`timescale 1ns / 1ps

module vga_controller (
    input  wire        clk,           // 100MHz system clock
    input  wire        rst,           // async reset, active high
    input  wire        vga_ce,        // VGA clock enable (25MHz: pulse every 4 cycles)
    output reg         hsync,         // horizontal sync (active low)
    output reg         vsync,         // vertical sync (active low)
    output reg         video_active,  // high during visible region
    output reg  [9:0]  pixel_x,       // horizontal pixel coordinate (0-639)
    output reg  [9:0]  pixel_y        // vertical pixel coordinate (0-479)
);

    //----------------------------------------------------------------------
    // Timing parameters
    //----------------------------------------------------------------------
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;  // 800

    localparam H_SYNC_START = H_VISIBLE + H_FRONT;                   // 656
    localparam H_SYNC_END   = H_VISIBLE + H_FRONT + H_SYNC;         // 752

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;   // 525

    localparam V_SYNC_START = V_VISIBLE + V_FRONT;                   // 490
    localparam V_SYNC_END   = V_VISIBLE + V_FRONT + V_SYNC;         // 492

    //----------------------------------------------------------------------
    // Pixel counters (advance only on vga_ce)
    //----------------------------------------------------------------------
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end
        else if (vga_ce) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end
            else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    //----------------------------------------------------------------------
    // Sync signal generation (active low, registered)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end
        else if (vga_ce) begin
            hsync <= ~((h_cnt >= H_SYNC_START) && (h_cnt < H_SYNC_END));
            vsync <= ~((v_cnt >= V_SYNC_START) && (v_cnt < V_SYNC_END));
        end
    end

    //----------------------------------------------------------------------
    // Video active and pixel coordinates (registered)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            video_active <= 1'b0;
            pixel_x      <= 10'd0;
            pixel_y      <= 10'd0;
        end
        else if (vga_ce) begin
            video_active <= (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
            pixel_x      <= (h_cnt < H_VISIBLE) ? h_cnt : 10'd0;
            pixel_y      <= (v_cnt < V_VISIBLE) ? v_cnt : 10'd0;
        end
    end

endmodule
