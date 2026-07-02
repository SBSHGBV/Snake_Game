//============================================================================
// snake_tb.v - Snake Game Testbench
//   Uses defparam to accelerate game_tick for fast simulation.
//   K7 buttons: active-low (BTN=1 idle, BTN=0 pressed). RTL inverts internally.
//============================================================================
`timescale 1ns / 1ps

module snake_tb;

    //----------------------------------------------------------------------
    // Clock generation (100MHz)
    //----------------------------------------------------------------------
    reg clk;
    reg rstn;

    initial clk = 1'b0;
    always #5 clk = ~clk;  // 100MHz

    //----------------------------------------------------------------------
    // DUT signals
    //----------------------------------------------------------------------
    reg  [3:0] BTN;
    reg        BTNX4;
    reg        ps2_clk;
    reg        ps2_data;
    wire [3:0] r, g, b;
    wire       hs, vs;
    wire [3:0] AN;
    wire [7:0] SEGMENT;
    wire [7:0] LED;
    integer tb_i;

    //----------------------------------------------------------------------
    // Instantiate DUT; override game_tick for fast sim
    //   100 cycles (1us) per tick instead of 20M cycles (200ms)
    //----------------------------------------------------------------------
    snake_top u_dut (
        .clk     (clk),
        .rstn    (rstn),
        .BTN     (BTN),
        .BTNX4   (BTNX4),
        .ps2_clk (ps2_clk),
        .ps2_data(ps2_data),
        .r       (r),
        .g       (g),
        .b       (b),
        .hs      (hs),
        .vs      (vs),
        .AN      (AN),
        .SEGMENT (SEGMENT),
        .LED     (LED)
    );

    // Override the game tick divider in clk_div
    // Simulation: 100 cycles = 1us per game tick
    defparam u_dut.u_clkdiv.GAME_TICK_DIV = 25'd99;

    // Override dead timer: ~10us instead of ~2s
    defparam u_dut.u_game.DEAD_TIME = 28'd999;

    // Accelerate debounce sampling for simulation.
    defparam u_dut.u_db0.SAMPLE_MAX = 17'd9;
    defparam u_dut.u_db1.SAMPLE_MAX = 17'd9;
    defparam u_dut.u_db2.SAMPLE_MAX = 17'd9;
    defparam u_dut.u_db3.SAMPLE_MAX = 17'd9;
    defparam u_dut.u_dbs.SAMPLE_MAX = 17'd9;

    //----------------------------------------------------------------------
    // Helper task: press a button (active-low: 0 = pressed)
    //----------------------------------------------------------------------
    task btn_press;
        input [3:0] btn_idx;  // bitmask: 4'b0001=BTN[0], etc.
        begin
            BTN = BTN & ~btn_idx;       // drive low (pressed)
            #5_000;                     // hold long enough for accelerated debounce
            BTN = BTN | btn_idx;        // release (back to pull-up)
            #5_000;                     // settle
        end
    endtask

    //----------------------------------------------------------------------
    // Helper task: press start button
    //----------------------------------------------------------------------
    task start_press;
        begin
            BTNX4 = 1'b0;               // pressed (active-low)
            #5_000;                     // hold long enough for accelerated debounce
            BTNX4 = 1'b1;               // release
            #5_000;
        end
    endtask

    //----------------------------------------------------------------------
    // Helper task: send one PS/2 bit on a falling clock edge
    //----------------------------------------------------------------------
    task ps2_send_bit;
        input bit_val;
        begin
            ps2_data = bit_val;
            #20_000;
            ps2_clk = 1'b0;
            #20_000;
            ps2_clk = 1'b1;
            #20_000;
        end
    endtask

    //----------------------------------------------------------------------
    // Helper task: send one PS/2 scan-code byte (odd parity)
    //----------------------------------------------------------------------
    task ps2_send_byte;
        input [7:0] code;
        integer j;
        reg parity;
        begin
            parity = ~(^code);
            ps2_send_bit(1'b0);       // start
            for (j = 0; j < 8; j = j + 1)
                ps2_send_bit(code[j]);
            ps2_send_bit(parity);
            ps2_send_bit(1'b1);       // stop
            ps2_data = 1'b1;
            #1_000;
        end
    endtask

    //----------------------------------------------------------------------
    // Main test sequence
    //----------------------------------------------------------------------
    initial begin
        // Init: buttons idle (pull-up = 1), reset active
        rstn  = 1'b0;
        BTN   = 4'b1111;    // all released
        BTNX4 = 1'b1;       // start released
        ps2_clk  = 1'b1;    // PS/2 idle (pulled high)
        ps2_data = 1'b1;

        // Hold reset 500ns
        #500;
        rstn = 1'b1;
        #5_000;             // wait for POR (~2.5us)

        $display("=== Snake Game Testbench Start ===");
        $display("[%0t] POR done, start menu is visible", $time);
        if (u_dut.menu_active !== 1'b1) begin
            $display("[%0t] ERROR: menu was not active after reset", $time);
            $finish;
        end

        // Choose Hard from the menu with PS/2 Right, then start with Enter.
        $display("[%0t] Selecting HARD difficulty via PS/2 RIGHT...", $time);
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h74);
        #1_000;
        if (u_dut.difficulty !== 2'd2) begin
            $display("[%0t] ERROR: PS/2 RIGHT did not select HARD", $time);
            $finish;
        end

        $display("[%0t] Selecting EASY difficulty via PS/2 LEFT...", $time);
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h6B);
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h6B);
        #1_000;
        if (u_dut.difficulty !== 2'd0) begin
            $display("[%0t] ERROR: PS/2 LEFT did not select EASY", $time);
            $finish;
        end

        $display("[%0t] Pressing PS/2 ENTER to enter game...", $time);
        ps2_send_byte(8'h5A);
        #1_000;
        if (u_dut.menu_active !== 1'b0) begin
            $display("[%0t] ERROR: PS/2 ENTER did not start the game", $time);
            $finish;
        end

        // Wait a few game ticks; snake auto-moves RIGHT
        // game_tick period = 100 * 10ns = 1us
        #10_000;  // Easy difficulty: 10us = a few cells
        $display("[%0t] Snake moved right from default direction", $time);

        // Freeze movement while sending slow PS/2 scan codes. The core still
        // sees keyboard pulses, but the accelerated snake cannot hit a wall
        // before the full R/Enter sequence is received.
        force u_dut.game_tick = 1'b0;

        $display("[%0t] Pressing R to open restart confirmation...", $time);
        ps2_send_byte(8'h2D);
        #1_000;
        if (u_dut.confirm_active !== 1'b1 || u_dut.confirm_select !== 1'b0) begin
            $display("[%0t] ERROR: R did not open restart confirmation on CANCEL", $time);
            $finish;
        end

        $display("[%0t] Pressing ENTER to cancel restart...", $time);
        ps2_send_byte(8'h5A);
        #1_000;
        if (u_dut.confirm_active !== 1'b0 || u_dut.menu_active !== 1'b0) begin
            $display("[%0t] ERROR: restart cancel did not return to game", $time);
            $finish;
        end

        $display("[%0t] Pressing R and confirming restart...", $time);
        ps2_send_byte(8'h2D);
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h74);
        #1_000;
        if (u_dut.confirm_active !== 1'b1 || u_dut.confirm_select !== 1'b1) begin
            $display("[%0t] ERROR: restart confirmation did not select CONFIRM", $time);
            $finish;
        end
        ps2_send_byte(8'h5A);
        #1_000;
        if (u_dut.confirm_active !== 1'b0 || u_dut.menu_active !== 1'b0 || u_dut.score !== 16'd0) begin
            $display("[%0t] ERROR: confirmed restart did not reset into gameplay", $time);
            $finish;
        end
        release u_dut.game_tick;

        // Test 1: Press DOWN
        $display("[%0t] Pressing DOWN...", $time);
        btn_press(4'b0010);  // BTN[1] = DOWN
        #10_000;
        $display("[%0t] Snake should now be moving DOWN", $time);

        // Test 2: Press UP (should be ignored; cannot reverse from DOWN)
        $display("[%0t] Pressing UP (should be ignored; 180 turn blocked)...", $time);
        btn_press(4'b0001);  // BTN[0] = UP
        #10_000;
        $display("[%0t] Snake should STILL be moving DOWN", $time);

        // Test 3: Press RIGHT
        $display("[%0t] Pressing RIGHT...", $time);
        btn_press(4'b1000);  // BTN[3] = RIGHT
        #10_000;
        $display("[%0t] Snake should now be moving RIGHT", $time);

        // Test 4: Press UP
        $display("[%0t] Pressing UP...", $time);
        btn_press(4'b0001);  // BTN[0] = UP
        #10_000;
        $display("[%0t] Snake should now be moving UP", $time);

        // Test 5: Let snake hit top wall and die
        // Snake started at y=15, moved up for several ticks, then hits the wall.
        $display("[%0t] Waiting for snake to hit wall...", $time);
        #100_000;  // wait for wall collision
        if (u_dut.menu_active !== 1'b1) begin
            $display("[%0t] ERROR: game did not return to menu after death", $time);
            $finish;
        end
        $display("[%0t] Snake died and returned to menu", $time);

        // Test 6: Wait for auto-restart (~10us in sim, ~2s in hardware)
        // DEAD_TIME overridden to 999 cycles, about 10us.
        #50_000;
        $display("[%0t] Pressing START from menu after auto-return...", $time);
        start_press();
        #10_000;
        if (u_dut.menu_active !== 1'b0) begin
            $display("[%0t] ERROR: start button did not restart the game", $time);
            $finish;
        end
        $display("[%0t] Snake restarted, moving RIGHT", $time);

        // Regression: moving into the current tail cell must keep that cell
        // occupied after the tail pointer advances.
        $display("[%0t] Checking tail-follow grid retention...", $time);
        force u_dut.game_tick = 1'b0;
        u_dut.u_game.state = 2'd1;          // S_PLAYING
        u_dut.u_game.collision_flag = 1'b0;
        u_dut.u_game.difficulty_reg = 2'd2; // hard: move every tick
        u_dut.u_game.move_div_cnt = 3'd0;
        u_dut.u_game.next_dir = 2'd0;       // DIR_UP
        u_dut.u_game.food_valid = 1'b0;
        for (tb_i = 0; tb_i < 1200; tb_i = tb_i + 1)
            u_dut.u_game.grid_reg[tb_i] = 1'b0;
        u_dut.u_game.grid_reg[15*40 + 20] = 1'b1; // tail, also next head
        u_dut.u_game.grid_reg[15*40 + 21] = 1'b1;
        u_dut.u_game.grid_reg[16*40 + 21] = 1'b1;
        u_dut.u_game.grid_reg[16*40 + 20] = 1'b1; // current head
        u_dut.u_game.snake_x[0] = 6'd20; u_dut.u_game.snake_y[0] = 5'd15;
        u_dut.u_game.snake_x[1] = 6'd21; u_dut.u_game.snake_y[1] = 5'd15;
        u_dut.u_game.snake_x[2] = 6'd21; u_dut.u_game.snake_y[2] = 5'd16;
        u_dut.u_game.snake_x[3] = 6'd20; u_dut.u_game.snake_y[3] = 5'd16;
        u_dut.u_game.head_idx = 8'd4;
        u_dut.u_game.tail_idx = 8'd0;
        u_dut.u_game.snake_len = 9'd4;
        u_dut.u_game.head_x_reg = 6'd20;
        u_dut.u_game.head_y_reg = 5'd16;
        #100;
        force u_dut.game_tick = 1'b1;
        @(posedge clk);
        #1;
        force u_dut.game_tick = 1'b0;
        if (u_dut.u_game.grid_reg[15*40 + 20] !== 1'b1 ||
            u_dut.u_game.tail_idx !== 8'd1 ||
            u_dut.u_game.head_x !== 6'd20 ||
            u_dut.u_game.head_y !== 5'd15) begin
            $display("[%0t] ERROR: moving into tail did not retain the shared cell", $time);
            $finish;
        end
        release u_dut.game_tick;
        $display("[%0t] Tail-follow grid retention passed", $time);

        $display("=== Snake Game Testbench Complete ===");
        $display("Smoke checks passed; inspect waveform for score and direction details.");
        $finish;
    end

    //----------------------------------------------------------------------
    // Monitor game events
    //----------------------------------------------------------------------
    reg prev_game_over;
    always @(posedge clk) begin
        prev_game_over <= (LED[1] === 1'b1);
        if ((LED[1] === 1'b1) && !prev_game_over)
            $display("[%0t] *** GAME OVER! (LED[1]=1) ***", $time);
        if (LED[0] === 1'b1)
            ; // playing: LED[0] on
    end

    //----------------------------------------------------------------------
    // Waveform dump
    //----------------------------------------------------------------------
    initial begin
        $dumpfile("snake_tb.vcd");
        $dumpvars(0, snake_tb);
    end

endmodule
