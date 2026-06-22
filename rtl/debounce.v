//============================================================================
// debounce.v - Push Button Debounce Module
//   Debounces a single push button input (active-high: pressed = 1)
//   - Samples input at ~1kHz, requires 16 consecutive stable samples
//   - Outputs a single-cycle pulse on press and release
//   - Parameter ACTIVE_LOW for K7 board buttons (pressed = 0)
//============================================================================
`timescale 1ns / 1ps

module debounce (
    input  wire clk,         // 100MHz system clock
    input  wire rst,         // asynchronous reset
    input  wire btn_in,      // raw button input
    output wire btn_press,   // single-cycle pulse on press
    output wire btn_release  // single-cycle pulse on release
);

    //----------------------------------------------------------------------
    // Slow sample enable (~1kHz): 100MHz / 100,000 = 1kHz
    //----------------------------------------------------------------------
    reg [16:0] sample_cnt;
    wire sample_tick = (sample_cnt == 17'd99_999);

    always @(posedge clk or posedge rst) begin
        if (rst)
            sample_cnt <= 17'd0;
        else if (sample_tick)
            sample_cnt <= 17'd0;
        else
            sample_cnt <= sample_cnt + 17'd1;
    end

    //----------------------------------------------------------------------
    // Synchronizer (2-stage) to avoid metastability
    //----------------------------------------------------------------------
    reg sync1, sync2;
    always @(posedge clk) begin
        sync1 <= btn_in;
        sync2 <= sync1;
    end

    //----------------------------------------------------------------------
    // Debounce: 16-bit shift register
    //----------------------------------------------------------------------
    reg [15:0] debounce_shift;
    always @(posedge clk or posedge rst) begin
        if (rst)
            // Init to all-1s: assumes button is NOT pressed at power-up.
            // For K7 active-low buttons with inverter, ~btn = 0 when idle,
            // so shift register will fill with 0s naturally after reset.
            // Init'ing to FFFF prevents spurious btn_press at startup.
            debounce_shift <= 16'hFFFF;
        else if (sample_tick)
            debounce_shift <= {debounce_shift[14:0], sync2};
    end

    // Stable when all 16 samples agree
    wire stable_high = (debounce_shift == 16'hFFFF);
    wire stable_low  = (debounce_shift == 16'h0000);

    //----------------------------------------------------------------------
    // Edge detection (registered for clean timing)
    //----------------------------------------------------------------------
    reg prev_stable;
    always @(posedge clk or posedge rst) begin
        if (rst)
            prev_stable <= 1'b1;  // matches FFFF init (stable_high = 1)
        else if (sample_tick)
            prev_stable <= stable_high;
    end

    // btn_press: fires when button transitions from released to pressed
    // (stable_high goes from 0 to 1, meaning button signal is now stable high)
    assign btn_press   = sample_tick & stable_high & ~prev_stable;

    // btn_release: fires when button transitions from pressed to released
    assign btn_release = sample_tick & stable_low  & prev_stable;

endmodule
