//============================================================================
// buzzer.v - Music Player + Tone Generator for Snake Game
//   Plays "Korobeiniki" (Tetris Type A theme) on loop via a piezo buzzer.
//
//   Architecture:
//     Tempo counter → Song ROM sequencer → Frequency LUT → Tone generator
//
//   Frequency LUT: 24 semitones (C4–B5), half-period counter values
//     half_period = 50,000,000 / freq   (50 MHz → toggle at full period)
//   Song ROM:  ~48 entries × 16-bit  →  768-bit ROM
//     Each entry = {6'd0, dur[3:0], note[5:0]}
//     note[5:0]: 0–23 = C4–B5, 24 = rest, 25–62 = unused, 63 = END (loop)
//     dur[3:0]:  1–15 = count of 16th notes (~100ms each at 150 BPM)
//   Tempo: 16th note ≈ 100 ms → TEMPO_MAX = 10,000,000 at 100 MHz
//============================================================================
`timescale 1ns / 1ps

module buzzer (
    input  wire clk,           // 100MHz system clock
    input  wire rst,           // async reset
    input  wire enable,        // music enable (0 = muted, 1 = playing)
    output wire buzzer_out     // square wave to piezo buzzer
);

    //----------------------------------------------------------------------
    // Tempo: 16th-note tick (~100 ms at 100 MHz)
    //   TEMPO_MAX = 10,000,000 → 100 ms exactly → 150 BPM
    //----------------------------------------------------------------------
    localparam [23:0] TEMPO_MAX = 24'd10_000_000;

    reg [23:0] tempo_cnt;
    wire       tempo_tick = (tempo_cnt == TEMPO_MAX);

    always @(posedge clk or posedge rst) begin
        if (rst)
            tempo_cnt <= 24'd0;
        else if (!enable)
            tempo_cnt <= 24'd0;
        else if (tempo_tick)
            tempo_cnt <= 24'd0;
        else
            tempo_cnt <= tempo_cnt + 24'd1;
    end

    //----------------------------------------------------------------------
    // Song ROM sequencer
    //----------------------------------------------------------------------
    // ROM word: [15:10]=unused, [9:6]=duration, [5:0]=note
    //   note:  0–23 = C4–B5, 24 = rest, 63 = END (loop back to 0)
    //   dur:   1–15 = sixteenth notes, 0 = illegal
    //----------------------------------------------------------------------
    localparam ROM_DEPTH = 48;
    reg [15:0] song_rom [0:ROM_DEPTH-1];

    // Initialize song ROM — Korobeiniki in A minor, 150 BPM
    integer rom_init;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (rom_init = 0; rom_init < ROM_DEPTH; rom_init = rom_init + 1)
                song_rom[rom_init] <= 16'd0;

            // ---- Bar 1: E4 B4 C5 D5 | E5 D5 C5 B4 (all eighths) ----
            song_rom[0]  <= {6'd0, 4'd2, 6'd4};   // E4  (idx 4),  8th
            song_rom[1]  <= {6'd0, 4'd2, 6'd11};  // B4  (idx 11), 8th
            song_rom[2]  <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[3]  <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[4]  <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[5]  <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[6]  <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[7]  <= {6'd0, 4'd2, 6'd11};  // B4  (idx 11), 8th

            // ---- Bar 2: A4 C5 E5 A5 | G5 F5 E5 C5 (all eighths) ----
            song_rom[8]  <= {6'd0, 4'd2, 6'd9};   // A4  (idx 9),  8th
            song_rom[9]  <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[10] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[11] <= {6'd0, 4'd2, 6'd21};  // A5  (idx 21), 8th
            song_rom[12] <= {6'd0, 4'd2, 6'd19};  // G5  (idx 19), 8th
            song_rom[13] <= {6'd0, 4'd2, 6'd17};  // F5  (idx 17), 8th
            song_rom[14] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[15] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th

            // ---- Bar 3: D5 E5 F5 D5 | E5 D5 C5 B4 (all eighths) ----
            song_rom[16] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[17] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[18] <= {6'd0, 4'd2, 6'd17};  // F5  (idx 17), 8th
            song_rom[19] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[20] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[21] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[22] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[23] <= {6'd0, 4'd2, 6'd11};  // B4  (idx 11), 8th

            // ---- Bar 4: C5 D5 E5 C5 | B4(1/4) A4(1/4) ----
            song_rom[24] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[25] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[26] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[27] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[28] <= {6'd0, 4'd4, 6'd11};  // B4  (idx 11), quarter
            song_rom[29] <= {6'd0, 4'd4, 6'd9};   // A4  (idx 9),  quarter

            // ---- Bar 5: D5 F5 A5 G5 | F5 E5 C5 E5 (all eighths) ----
            song_rom[30] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[31] <= {6'd0, 4'd2, 6'd17};  // F5  (idx 17), 8th
            song_rom[32] <= {6'd0, 4'd2, 6'd21};  // A5  (idx 21), 8th
            song_rom[33] <= {6'd0, 4'd2, 6'd19};  // G5  (idx 19), 8th
            song_rom[34] <= {6'd0, 4'd2, 6'd17};  // F5  (idx 17), 8th
            song_rom[35] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th
            song_rom[36] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[37] <= {6'd0, 4'd2, 6'd16};  // E5  (idx 16), 8th

            // ---- Bar 6: D5(1/4) C5 B4 C5 | D5(1/4) E5(1/4) ----
            song_rom[38] <= {6'd0, 4'd4, 6'd14};  // D5  (idx 14), quarter
            song_rom[39] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[40] <= {6'd0, 4'd2, 6'd11};  // B4  (idx 11), 8th
            song_rom[41] <= {6'd0, 4'd2, 6'd12};  // C5  (idx 12), 8th
            song_rom[42] <= {6'd0, 4'd2, 6'd14};  // D5  (idx 14), 8th
            song_rom[43] <= {6'd0, 4'd4, 6'd16};  // E5  (idx 16), quarter

            // ---- Bar 7: C5(1/4) A4(1/4) A4(1/2) ----
            song_rom[44] <= {6'd0, 4'd4, 6'd12};  // C5  (idx 12), quarter
            song_rom[45] <= {6'd0, 4'd4, 6'd9};   // A4  (idx 9),  quarter
            song_rom[46] <= {6'd0, 4'd8, 6'd9};   // A4  (idx 9),  half

            // ---- END marker ----
            song_rom[47] <= {6'd0, 4'd0, 6'd63};  // END → loop
        end
    end

    // Sequencer state (dur_counter == 0 means "ready for next note")
    reg [5:0]  rom_ptr;        // current ROM entry index to load next
    reg [3:0]  dur_counter;    // counts down remaining tempo ticks; 0 = load next
    reg [5:0]  cur_note;       // latched note index for tone generator

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rom_ptr      <= 6'd0;
            dur_counter  <= 4'd0;
            cur_note     <= 6'd24;  // rest (silent)
        end
        else if (!enable) begin
            rom_ptr      <= 6'd0;
            dur_counter  <= 4'd0;
            cur_note     <= 6'd24;
        end
        else if (tempo_tick) begin
            if (dur_counter == 4'd0) begin
                // Load next ROM entry — no gap between notes
                if (song_rom[rom_ptr][5:0] == 6'd63) begin
                    // END marker (index 47) → seamless loop to bar 1
                    cur_note    <= song_rom[0][5:0];
                    dur_counter <= song_rom[0][9:6] - 4'd1;
                    rom_ptr     <= 6'd1;
                end
                else begin
                    cur_note    <= song_rom[rom_ptr][5:0];
                    dur_counter <= song_rom[rom_ptr][9:6] - 4'd1;
                    rom_ptr     <= rom_ptr + 6'd1;
                end
            end
            else begin
                dur_counter <= dur_counter - 4'd1;
            end
        end
    end

    //----------------------------------------------------------------------
    // Frequency lookup table — half-period counter value for each note
    //   half = 50,000,000 / frequency
    //   Index  0..23  = C4 .. B5
    //----------------------------------------------------------------------
    wire [17:0] freq_half_period;
    assign freq_half_period =
        (cur_note == 6'd0)  ? 18'd191113 :  // C4   261.63 Hz
        (cur_note == 6'd1)  ? 18'd180388 :  // C#4  277.18 Hz
        (cur_note == 6'd2)  ? 18'd170262 :  // D4   293.66 Hz
        (cur_note == 6'd3)  ? 18'd160704 :  // D#4  311.13 Hz
        (cur_note == 6'd4)  ? 18'd151687 :  // E4   329.63 Hz
        (cur_note == 6'd5)  ? 18'd143172 :  // F4   349.23 Hz
        (cur_note == 6'd6)  ? 18'd135138 :  // F#4  369.99 Hz
        (cur_note == 6'd7)  ? 18'd127551 :  // G4   392.00 Hz
        (cur_note == 6'd8)  ? 18'd120394 :  // G#4  415.30 Hz
        (cur_note == 6'd9)  ? 18'd113636 :  // A4   440.00 Hz
        (cur_note == 6'd10) ? 18'd107259 :  // A#4  466.16 Hz
        (cur_note == 6'd11) ? 18'd101238 :  // B4   493.88 Hz
        (cur_note == 6'd12) ? 18'd95557  :  // C5   523.25 Hz
        (cur_note == 6'd13) ? 18'd90194  :  // C#5  554.37 Hz
        (cur_note == 6'd14) ? 18'd85131  :  // D5   587.33 Hz
        (cur_note == 6'd15) ? 18'd80352  :  // D#5  622.25 Hz
        (cur_note == 6'd16) ? 18'd75843  :  // E5   659.26 Hz
        (cur_note == 6'd17) ? 18'd71586  :  // F5   698.46 Hz
        (cur_note == 6'd18) ? 18'd67569  :  // F#5  739.99 Hz
        (cur_note == 6'd19) ? 18'd63776  :  // G5   783.99 Hz
        (cur_note == 6'd20) ? 18'd60197  :  // G#5  830.61 Hz
        (cur_note == 6'd21) ? 18'd56818  :  // A5   880.00 Hz
        (cur_note == 6'd22) ? 18'd53630  :  // A#5  932.33 Hz
        (cur_note == 6'd23) ? 18'd50619  :  // B5   987.77 Hz
        18'd0;                               // rest / silence

    //----------------------------------------------------------------------
    // Tone generator — square wave at note frequency
    //   Counts up to half_period, toggles buzzer_out, resets.
    //   Silent (0) when freq_half_period == 0.
    //----------------------------------------------------------------------
    reg [17:0] tone_cnt;
    reg        tone_out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt <= 18'd0;
            tone_out <= 1'b0;
        end
        else if (!enable || (freq_half_period == 18'd0)) begin
            tone_cnt <= 18'd0;
            tone_out <= 1'b0;
        end
        else if (tone_cnt >= freq_half_period - 18'd1) begin
            tone_cnt <= 18'd0;
            tone_out <= ~tone_out;
        end
        else begin
            tone_cnt <= tone_cnt + 18'd1;
        end
    end

    assign buzzer_out = tone_out;

endmodule
