//============================================================================
// ps2_keyboard.v - PS/2 Keyboard Controller
//   Receives PS/2 scan codes, outputs direction + start press pulses.
//
//   Arrow keys (E0 prefix):          WASD alternative:
//     Up:    E0 75                     W: 1D
//     Down:  E0 72                     A: 1C
//     Left:  E0 6B                     S: 1B
//     Right: E0 74                     D: 23
//   Start / restart: Enter(5A) or Space(29) or R(2D)
//============================================================================
`timescale 1ns / 1ps

module ps2_keyboard (
    input  wire       clk,           // 100MHz system clock
    input  wire       rst,           // async reset
    input  wire       ps2_clk,       // PS/2 clock (~10-16kHz)
    input  wire       ps2_data,      // PS/2 data
    output reg        btn_up,        // single-cycle pulse
    output reg        btn_down,
    output reg        btn_left,
    output reg        btn_right,
    output reg        btn_start
);

    //----------------------------------------------------------------------
    // Synchronizers (2-stage) for external PS/2 signals
    //----------------------------------------------------------------------
    reg [1:0] clk_sync;
    reg [1:0] dat_sync;

    always @(posedge clk) begin
        clk_sync <= {clk_sync[0], ps2_clk};
        dat_sync <= {dat_sync[0], ps2_data};
    end

    wire ps2_clk_s = clk_sync[1];
    wire ps2_dat_s = dat_sync[1];

    //----------------------------------------------------------------------
    // Falling edge detection on ps2_clk
    //----------------------------------------------------------------------
    reg clk_prev;
    always @(posedge clk) begin
        clk_prev <= ps2_clk_s;
    end
    wire clk_fall = clk_prev && !ps2_clk_s;   // falling edge

    //----------------------------------------------------------------------
    // Frame receive state machine (11 bits per frame)
    //----------------------------------------------------------------------
    reg [3:0]  bit_cnt;        // 0..10
    reg [10:0] shift_reg;      // [10]=stop, [9]=parity, [8:1]=data, [0]=start
    reg        receiving;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt   <= 4'd0;
            shift_reg <= 11'd0;
            receiving <= 1'b0;
        end
        else if (clk_fall) begin
            if (!receiving) begin
                // Wait for start bit (data low)
                if (ps2_dat_s == 1'b0) begin
                    receiving <= 1'b1;
                    bit_cnt   <= 4'd1;
                    shift_reg <= {10'd0, ps2_dat_s};  // shift_reg[0] = 0 (start)
                end
            end
            else if (bit_cnt < 4'd10) begin
                bit_cnt   <= bit_cnt + 4'd1;
                shift_reg <= {ps2_dat_s, shift_reg[10:1]};
            end
            else begin
                // bit_cnt == 10: last bit (stop bit)
                receiving <= 1'b0;
                bit_cnt   <= 4'd0;
                shift_reg <= {ps2_dat_s, shift_reg[10:1]};
            end
        end
    end

    //----------------------------------------------------------------------
    // Frame complete detection + scan code extraction
    //----------------------------------------------------------------------
    reg frame_ready;
    reg [7:0] scan_code;

    // Odd parity check
    wire parity_ok = (^shift_reg[8:1]) ^ shift_reg[9];  // should be 1 (odd)
    wire frame_valid = !shift_reg[0] && shift_reg[10] && parity_ok;  // start=0, stop=1, parity ok

    always @(posedge clk) begin
        if (rst) begin
            frame_ready <= 1'b0;
            scan_code   <= 8'd0;
        end
        else if (!receiving && bit_cnt == 4'd0 && clk_fall) begin
            // Frame just completed, check validity
            if (frame_valid) begin
                frame_ready <= 1'b1;
                scan_code   <= shift_reg[8:1];
            end
            else begin
                frame_ready <= 1'b0;
            end
        end
        else begin
            frame_ready <= 1'b0;
        end
    end

    //----------------------------------------------------------------------
    // Extended key state machine
    //   E0 prefix → next byte is extended scan code
    //   F0 prefix → next byte is break code (key released)
    //----------------------------------------------------------------------
    reg        e0_flag;       // last byte was E0
    reg        f0_flag;       // last byte was F0
    reg [7:0]  last_scan;     // last make scan code

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            e0_flag   <= 1'b0;
            f0_flag   <= 1'b0;
            last_scan <= 8'd0;
        end
        else if (frame_ready) begin
            if (scan_code == 8'hE0) begin
                e0_flag <= 1'b1;
                f0_flag <= 1'b0;
            end
            else if (scan_code == 8'hF0) begin
                e0_flag <= 1'b0;
                f0_flag <= 1'b1;
            end
            else begin
                // Regular scan code — interpret based on flags
                if (!f0_flag) begin
                    // Make code (key pressed)
                    last_scan <= e0_flag ? {1'b1, scan_code[6:0]} : scan_code;
                end
                e0_flag <= 1'b0;
                f0_flag <= 1'b0;
            end
        end
    end

    // Extended code marker: store as 8'h8x (set bit 7)
    wire [7:0] extended_code = {1'b1, scan_code[6:0]};
    wire make_code_valid = frame_ready && !f0_flag && scan_code != 8'hE0 && scan_code != 8'hF0;

    //----------------------------------------------------------------------
    // Key mapping → single-cycle pulses
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_up    <= 1'b0;
            btn_down  <= 1'b0;
            btn_left  <= 1'b0;
            btn_right <= 1'b0;
            btn_start <= 1'b0;
        end
        else begin
            // Default: all low (pulse for one cycle only)
            btn_up    <= 1'b0;
            btn_down  <= 1'b0;
            btn_left  <= 1'b0;
            btn_right <= 1'b0;
            btn_start <= 1'b0;

            if (make_code_valid) begin
                if (e0_flag) begin
                    // Extended keys (arrow keys)
                    case (scan_code)
                        8'h75: btn_up    <= 1'b1;   // Arrow Up
                        8'h72: btn_down  <= 1'b1;   // Arrow Down
                        8'h6B: btn_left  <= 1'b1;   // Arrow Left
                        8'h74: btn_right <= 1'b1;   // Arrow Right
                        default: ;
                    endcase
                end
                else begin
                    // Regular keys
                    case (scan_code)
                        8'h1D: btn_up    <= 1'b1;   // W
                        8'h1B: btn_down  <= 1'b1;   // S
                        8'h1C: btn_left  <= 1'b1;   // A
                        8'h23: btn_right <= 1'b1;   // D
                        8'h5A: btn_start <= 1'b1;   // Enter
                        8'h29: btn_start <= 1'b1;   // Space
                        8'h2D: btn_start <= 1'b1;   // R (restart)
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
