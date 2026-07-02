//============================================================================
// snake_top.v - Snake Game Top-Level Module (Kintex-7)
//   Reset opens the start menu. Esc opens the pause menu while playing.
//   Control: BTN[3:0] buttons + PS/2 keyboard (arrow keys / WASD)
//   Audio: piezo buzzer plays Korobeiniki (Tetris theme) on loop
//============================================================================
`timescale 1ns / 1ps

module snake_top (
    input  wire        clk,
    input  wire        rstn,         // external reset (active low, with PULLUP)
    input  wire [3:0]  BTN,          // direction: up/down/left/right
    input  wire        BTNX4,        // start / select
    input  wire        ps2_clk,      // PS/2 keyboard clock
    input  wire        ps2_data,     // PS/2 keyboard data
    output wire [3:0]  r, g, b,      // VGA 4:4:4
    output wire        hs, vs,       // VGA sync
    output wire [3:0]  AN,           // 7-seg anode
    output wire [7:0]  SEGMENT,      // 7-seg segments
    output wire [7:0]  LED,          // status LEDs
    output wire        buzzer        // piezo buzzer (music)
);

    //----------------------------------------------------------------------
    // Internal reset: POR counter (~1us) + external rstn button
    //----------------------------------------------------------------------
    reg [7:0] por_cnt = 8'd0;             // initial 0 for sim (synthesis: GSR=0)
    wire por_rst = (por_cnt != 8'hFF);    // active for ~2.5us after config

    always @(posedge clk) begin
        if (por_cnt != 8'hFF)
            por_cnt <= por_cnt + 8'd1;
    end

    wire rst_ext = ~rstn;                 // external reset button (active low to high)
    wire rst = por_rst || rst_ext;        // combined reset

    //----------------------------------------------------------------------
    // Clock enables
    //----------------------------------------------------------------------
    wire vga_ce;
    wire game_tick;

    clk_div #(
        .GAME_TICK_DIV(25'd19_999_999)   // ~5Hz for hardware
    ) u_clkdiv (
        .clk_100m (clk),
        .rst      (rst),
        .vga_ce   (vga_ce),
        .game_tick(game_tick)
    );

    //----------------------------------------------------------------------
    // Button debouncing: K7 buttons are active-low, invert to active-high
    //----------------------------------------------------------------------
    wire btn_up, btn_down, btn_left, btn_right, btn_start;
    wire nc_rel;

    debounce u_db0 (.clk(clk), .rst(rst), .btn_in(~BTN[0]), .btn_press(btn_up),   .btn_release(nc_rel));
    debounce u_db1 (.clk(clk), .rst(rst), .btn_in(~BTN[1]), .btn_press(btn_down), .btn_release(nc_rel));
    debounce u_db2 (.clk(clk), .rst(rst), .btn_in(~BTN[2]), .btn_press(btn_left), .btn_release(nc_rel));
    debounce u_db3 (.clk(clk), .rst(rst), .btn_in(~BTN[3]), .btn_press(btn_right),.btn_release(nc_rel));
    debounce u_dbs (.clk(clk), .rst(rst), .btn_in(~BTNX4),  .btn_press(btn_start),.btn_release(nc_rel));

    //----------------------------------------------------------------------
    // PS/2 Keyboard controller (arrow keys + WASD + Enter/Space/Esc)
    //----------------------------------------------------------------------
    wire kb_up, kb_down, kb_left, kb_right, kb_start, kb_pause;

    ps2_keyboard u_kb (
        .clk       (clk),
        .rst       (rst),
        .ps2_clk   (ps2_clk),
        .ps2_data  (ps2_data),
        .btn_up    (kb_up),
        .btn_down  (kb_down),
        .btn_left  (kb_left),
        .btn_right (kb_right),
        .btn_start (kb_start),
        .btn_pause (kb_pause)
    );

    // Merge keyboard + button inputs (either source works)
    wire dir_up    = btn_up    || kb_up;
    wire dir_down  = btn_down  || kb_down;
    wire dir_left  = btn_left  || kb_left;
    wire dir_right = btn_right || kb_right;
    wire start_sig = btn_start || kb_start;
    wire pause_sig = kb_pause;

    //----------------------------------------------------------------------
    // LFSR
    //----------------------------------------------------------------------
    wire [15:0] lfsr_val;

    lfsr u_lfsr (
        .clk      (clk),
        .rst      (rst),
        .seed_en  (start_sig),
        .seed_val (16'hABCD),
        .rand_out (lfsr_val)
    );

    //----------------------------------------------------------------------
    // Snake game core: reset enters the start menu
    //----------------------------------------------------------------------
    wire [15:0]   score;
    wire          game_over;
    wire          menu_active;
    wire          pause_active;
    wire [1:0]    pause_select;
    wire [1:0]    difficulty;
    wire [15:0]   high_score_easy;
    wire [15:0]   high_score_normal;
    wire [15:0]   high_score_hard;
    wire [1199:0] snake_grid_flat;
    wire [5:0]    food_x;
    wire [4:0]    food_y;
    wire [5:0]    head_x;
    wire [4:0]    head_y;

    snake_game u_game (
        .clk             (clk),
        .rst             (rst),
        .game_tick       (game_tick),
        .btn_up          (dir_up),
        .btn_down        (dir_down),
        .btn_left        (dir_left),
        .btn_right       (dir_right),
        .btn_start       (start_sig),
        .btn_pause       (pause_sig),
        .lfsr_val        (lfsr_val),
        .score           (score),
        .game_over       (game_over),
        .menu_active     (menu_active),
        .pause_active    (pause_active),
        .pause_select    (pause_select),
        .difficulty      (difficulty),
        .high_score_easy (high_score_easy),
        .high_score_normal(high_score_normal),
        .high_score_hard (high_score_hard),
        .snake_grid_flat (snake_grid_flat),
        .food_x          (food_x),
        .food_y          (food_y),
        .head_x          (head_x),
        .head_y          (head_y)
    );

    //----------------------------------------------------------------------
    // VGA controller
    //----------------------------------------------------------------------
    wire       video_active;
    wire [9:0] pixel_x, pixel_y;

    vga_controller u_vga (
        .clk          (clk),
        .rst          (rst),
        .vga_ce       (vga_ce),
        .hsync        (hs),
        .vsync        (vs),
        .video_active (video_active),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y)
    );

    //----------------------------------------------------------------------
    // Snake renderer
    //----------------------------------------------------------------------
    snake_render u_render (
        .clk             (clk),
        .rst             (rst),
        .vga_ce          (vga_ce),
        .video_active    (video_active),
        .pixel_x         (pixel_x),
        .pixel_y         (pixel_y),
        .game_over       (game_over),
        .menu_active     (menu_active),
        .pause_active    (pause_active),
        .pause_select    (pause_select),
        .difficulty      (difficulty),
        .score           (score),
        .high_score_easy (high_score_easy),
        .high_score_normal(high_score_normal),
        .high_score_hard (high_score_hard),
        .snake_grid_flat (snake_grid_flat),
        .food_x          (food_x),
        .food_y          (food_y),
        .head_x          (head_x),
        .head_y          (head_y),
        .vga_r           (r),
        .vga_g           (g),
        .vga_b           (b)
    );

    //----------------------------------------------------------------------
    // 7-Segment display
    //----------------------------------------------------------------------
    seven_seg_display u_seg (
        .clk     (clk),
        .rst     (rst),
        .score   (score),
        .AN      (AN),
        .SEGMENT (SEGMENT)
    );

    //----------------------------------------------------------------------
    // Buzzer — play music during menu and gameplay, mute during pause
    //----------------------------------------------------------------------
    buzzer u_buzzer (
        .clk        (clk),
        .rst        (rst),
        .enable     (~pause_active),   // mute when pause menu is open
        .buzzer_out (buzzer)
    );

    //----------------------------------------------------------------------
    // Status LEDs
    //----------------------------------------------------------------------
    reg [24:0] hb_cnt;
    always @(posedge clk) begin
        if (rst)
            hb_cnt <= 25'd0;
        else
            hb_cnt <= hb_cnt + 25'd1;
    end

    assign LED[0] = ~game_over & ~menu_active; // on while playing
    assign LED[1] = game_over;        // on when dead
    assign LED[2] = hb_cnt[24];       // ~1.5 Hz heartbeat
    assign LED[3] = menu_active;      // menu visible
    assign LED[4] = difficulty[0];    // difficulty indicator
    assign LED[5] = difficulty[1];    // difficulty indicator
    assign LED[6] = |score;           // any score
    assign LED[7] = buzzer;           // buzzer output (for debug: LED flickers if music works)

endmodule
