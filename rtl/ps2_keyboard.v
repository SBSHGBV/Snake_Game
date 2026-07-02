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
    // Frame receiver: start, 8 data bits LSB-first, parity, stop.
    //----------------------------------------------------------------------
    reg [3:0] bit_cnt;        // 0..7=data, 8=parity, 9=stop
    reg [7:0] data_shift;
    reg       parity_bit;
    reg       receiving;
    reg       frame_ready;
    reg [7:0] scan_code;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt     <= 4'd0;
            data_shift  <= 8'd0;
            parity_bit  <= 1'b0;
            receiving   <= 1'b0;
            frame_ready <= 1'b0;
            scan_code   <= 8'd0;
        end
        else begin
            frame_ready <= 1'b0;

            if (clk_fall) begin
                if (!receiving) begin
                    // Start bit is low.
                    if (ps2_dat_s == 1'b0) begin
                        receiving  <= 1'b1;
                        bit_cnt    <= 4'd0;
                        data_shift <= 8'd0;
                        parity_bit <= 1'b0;
                    end
                end
                else if (bit_cnt < 4'd8) begin
                    data_shift[bit_cnt] <= ps2_dat_s;
                    bit_cnt <= bit_cnt + 4'd1;
                end
                else if (bit_cnt == 4'd8) begin
                    parity_bit <= ps2_dat_s;
                    bit_cnt <= 4'd9;
                end
                else begin
                    // Stop bit is high, and data plus parity must be odd.
                    receiving <= 1'b0;
                    bit_cnt <= 4'd0;
                    if (ps2_dat_s && ((^data_shift) ^ parity_bit)) begin
                        scan_code <= data_shift;
                        frame_ready <= 1'b1;
                    end
                end
            end
        end
    end

    //----------------------------------------------------------------------
    // Extended key state machine
    //   E0 prefix: next byte is extended scan code
    //   F0 prefix: next byte is break code (key released)
    //----------------------------------------------------------------------
    reg        e0_flag;       // last byte was E0
    reg        f0_flag;       // last byte was F0

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            e0_flag   <= 1'b0;
            f0_flag   <= 1'b0;
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
                e0_flag <= 1'b0;
                f0_flag <= 1'b0;
            end
        end
    end

    wire make_code_valid = frame_ready && !f0_flag && scan_code != 8'hE0 && scan_code != 8'hF0;

    //----------------------------------------------------------------------
    // Key mapping to single-cycle pulses
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
