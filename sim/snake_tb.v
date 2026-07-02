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

    //----------------------------------------------------------------------
    // Instantiate DUT — override game_tick for fast sim
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
    defparam u_dut.u_game.DEAD_TIME = 25'd999;

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
            #500_000;                   // settle
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
            #500_000;
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
        #2_000;             // wait for POR (~2.5us)

        $display("=== Snake Game Testbench Start ===");
        $display("[%0t] POR done, start menu is visible", $time);

        // Choose Hard from the menu, then start.
        $display("[%0t] Selecting HARD difficulty...", $time);
        btn_press(4'b1000);  // RIGHT: Normal -> Hard
        $display("[%0t] Pressing START to enter game...", $time);
        start_press();

        // Wait a few game ticks — snake auto-moves RIGHT
        // game_tick period = 100 * 10ns = 1us
        #10_000;  // Hard difficulty: 10us = ~10 cells
        $display("[%0t] Snake moved right from default direction", $time);

        // Test 1: Press DOWN
        $display("[%0t] Pressing DOWN...", $time);
        btn_press(4'b0010);  // BTN[1] = DOWN
        #50_000;
        $display("[%0t] Snake should now be moving DOWN", $time);

        // Test 2: Press RIGHT (should be IGNORED — can't reverse from DOWN)
        $display("[%0t] Pressing RIGHT (should be IGNORED — 180 turn blocked)...", $time);
        btn_press(4'b1000);  // BTN[3] = RIGHT
        #50_000;
        $display("[%0t] Snake should STILL be moving DOWN", $time);

        // Test 3: Press LEFT
        $display("[%0t] Pressing LEFT...", $time);
        btn_press(4'b0100);  // BTN[2] = LEFT
        #50_000;
        $display("[%0t] Snake should now be moving LEFT", $time);

        // Test 4: Press UP
        $display("[%0t] Pressing UP...", $time);
        btn_press(4'b0001);  // BTN[0] = UP
        #50_000;
        $display("[%0t] Snake should now be moving UP", $time);

        // Test 5: Let snake hit top wall and die
        // Snake started at y=15, moved up for ~8 ticks → at y~7
        // Need ~7 more ticks to hit y=0 → wall collision
        $display("[%0t] Waiting for snake to hit wall...", $time);
        #100_000;  // wait for wall collision
        $display("[%0t] Snake should have hit wall. GAME OVER = %b", $time, LED[1]);

        // Test 6: Wait for auto-restart (~10us in sim, ~2s in hardware)
        // DEAD_TIME overridden to 999 cycles ≈ 10us
        #50_000;
        $display("[%0t] Pressing START from menu after auto-return...", $time);
        start_press();
        #50_000;
        $display("[%0t] Snake restarted, moving RIGHT", $time);

        $display("=== Snake Game Testbench Complete ===");
        $display("Verify in waveform: score increments, direction changes, game_over toggles");
        $finish;
    end

    //----------------------------------------------------------------------
    // Monitor game events
    //----------------------------------------------------------------------
    always @(posedge clk) begin
        if (LED[1] && !$isunknown(LED[1]))
            $display("[%0t] *** GAME OVER! (LED[1]=1) ***", $time);
        if (LED[0] && !$isunknown(LED[0]))
            ; // playing — LED[0] on
    end

    //----------------------------------------------------------------------
    // Waveform dump
    //----------------------------------------------------------------------
    initial begin
        $dumpfile("snake_tb.vcd");
        $dumpvars(0, snake_tb);
    end

endmodule
