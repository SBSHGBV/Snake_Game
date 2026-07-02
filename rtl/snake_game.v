//============================================================================
// snake_game.v - Snake Game Core Logic
//   Grid: 40 x 30 cells, 16x16 pixels = 640x480
//   Snake body: FIFO circular buffer (256 entries) + flat 1200-bit grid
//   Food: LFSR random placement with collision check, retries until empty cell found
//============================================================================
`timescale 1ns / 1ps

module snake_game (
    input  wire        clk,                // 100MHz system clock
    input  wire        rst,                // active-high async reset
    input  wire        game_tick,          // game tick (~5Hz)
    input  wire        btn_up,             // direction: up (debounced press)
    input  wire        btn_down,           // direction: down
    input  wire        btn_left,           // direction: left
    input  wire        btn_right,          // direction: right
    input  wire        btn_start,          // start/restart (debounced press)
    input  wire [15:0] lfsr_val,           // LFSR random value snapshot
    output wire [15:0] score,              // BCD score (4 digits)
    output wire        game_over,          // game over flag
    output wire        menu_active,        // start menu flag
    output wire [1:0]  difficulty,         // 0=easy, 1=normal, 2=hard
    output wire [15:0] high_score_easy,    // BCD high score per difficulty
    output wire [15:0] high_score_normal,
    output wire [15:0] high_score_hard,
    output wire [1199:0] snake_grid_flat,  // snake body grid
    output wire [5:0]  food_x,             // food X position
    output wire [4:0]  food_y,             // food Y position
    output wire [5:0]  head_x,             // snake head X (for colored head)
    output wire [4:0]  head_y              // snake head Y
);

    //----------------------------------------------------------------------
    // State machine
    //----------------------------------------------------------------------
    localparam S_MENU    = 2'd0;
    localparam S_PLAYING = 2'd1;
    localparam S_DEAD    = 2'd2;

    // Direction
    localparam DIR_UP    = 2'd0;
    localparam DIR_DOWN  = 2'd1;
    localparam DIR_LEFT  = 2'd2;
    localparam DIR_RIGHT = 2'd3;

    // Constants (parameters for sim override)
    parameter MAX_LEN   = 256;
    parameter DEAD_TIME = 25'd199_999_999;  // ~2 sec at 100MHz

    //----------------------------------------------------------------------
    // Registers
    //----------------------------------------------------------------------
    reg [1:0]  state, next_state;
    reg [24:0] dead_timer;

    // Snake body FIFO
    reg [5:0]  snake_x [0:MAX_LEN-1];
    reg [4:0]  snake_y [0:MAX_LEN-1];
    reg [7:0]  head_idx, tail_idx;
    reg [8:0]  snake_len;

    reg [1:0]  next_dir;
    reg [1:0]  difficulty_reg;
    reg [2:0]  move_div_cnt;

    // Head position
    reg [5:0]  head_x_reg, head_y_reg;

    // Food
    reg [5:0]  food_x_reg;
    reg [4:0]  food_y_reg;
    reg        food_valid;        // 0 = need to generate food, 1 = food placed

    // Score
    reg [15:0] score_reg;
    reg [15:0] high_easy_reg;
    reg [15:0] high_normal_reg;
    reg [15:0] high_hard_reg;

    // Grid: 40x30 = 1200 bits
    reg [1199:0] grid_reg;

    // Flags
    reg        collision_flag;

    //----------------------------------------------------------------------
    // State machine: reset enters the start menu
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_MENU;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_MENU:    if (btn_start)                         next_state = S_PLAYING;
            S_PLAYING: if (collision_flag)                     next_state = S_DEAD;
            S_DEAD:    if (dead_timer == 25'd0 || btn_start)  next_state = S_MENU;
            default:                                          next_state = S_MENU;
        endcase
    end

    //----------------------------------------------------------------------
    // Dead timer
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            dead_timer <= DEAD_TIME;
        else if (state == S_DEAD) begin
            if (dead_timer > 0)
                dead_timer <= dead_timer - 25'd1;
        end else
            dead_timer <= DEAD_TIME;
    end

    //----------------------------------------------------------------------
    // Direction control
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            next_dir   <= DIR_RIGHT;
        end
        else if (state != S_PLAYING)
            next_dir <= DIR_RIGHT;
        else if (state == S_PLAYING) begin
            // 180° prevention: check against next_dir (queued), not direction (committed).
            // This prevents rapid key sequences (e.g. DOWN then UP) from bypassing the check
            // before the next game_tick commits the direction.
            if (btn_up && next_dir != DIR_DOWN)
                next_dir <= DIR_UP;
            else if (btn_down && next_dir != DIR_UP)
                next_dir <= DIR_DOWN;
            else if (btn_left && next_dir != DIR_RIGHT)
                next_dir <= DIR_LEFT;
            else if (btn_right && next_dir != DIR_LEFT)
                next_dir <= DIR_RIGHT;
        end
    end

    //----------------------------------------------------------------------
    // Menu difficulty selection
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            difficulty_reg <= 2'd1;  // normal
        else if (state == S_MENU) begin
            if ((btn_left || btn_up) && difficulty_reg != 2'd0)
                difficulty_reg <= difficulty_reg - 2'd1;
            else if ((btn_right || btn_down) && difficulty_reg != 2'd2)
                difficulty_reg <= difficulty_reg + 2'd1;
        end
    end

    wire [2:0] move_div_limit =
        (difficulty_reg == 2'd0) ? 3'd3 :   // easy:   base tick / 4
        (difficulty_reg == 2'd1) ? 3'd1 :   // normal: base tick / 2
                                   3'd0;    // hard:   base tick

    wire move_tick = (state == S_PLAYING) && game_tick && (move_div_cnt == move_div_limit);

    always @(posedge clk or posedge rst) begin
        if (rst)
            move_div_cnt <= 3'd0;
        else if (state != S_PLAYING)
            move_div_cnt <= 3'd0;
        else if (game_tick) begin
            if (move_div_cnt == move_div_limit)
                move_div_cnt <= 3'd0;
            else
                move_div_cnt <= move_div_cnt + 3'd1;
        end
    end

    //----------------------------------------------------------------------
    // New head position (combinational)
    //----------------------------------------------------------------------
    reg [5:0] new_head_x;
    reg [4:0] new_head_y;

    always @(*) begin
        new_head_x = head_x_reg;
        new_head_y = head_y_reg;
        case (next_dir)
            DIR_UP:    new_head_y = head_y_reg - 5'd1;
            DIR_DOWN:  new_head_y = head_y_reg + 5'd1;
            DIR_LEFT:  new_head_x = head_x_reg - 6'd1;
            DIR_RIGHT: new_head_x = head_x_reg + 6'd1;
            default:   ;
        endcase
    end

    //----------------------------------------------------------------------
    // Collision detection
    //----------------------------------------------------------------------
    wire wall_collision = (new_head_x >= 6'd40) || (new_head_y >= 5'd30);
    // Guard grid read: prevent out-of-bounds access when coordinates underflow
    wire in_bounds      = (new_head_x < 6'd40) && (new_head_y < 5'd30);
    wire [10:0] new_head_idx = new_head_y * 40 + new_head_x;
    wire [10:0] tail_cell_idx = snake_y[tail_idx] * 40 + snake_x[tail_idx];
    wire        will_grow = food_valid && (new_head_x == food_x_reg) && (new_head_y == food_y_reg);
    wire        moving_into_tail = in_bounds && !will_grow && (new_head_idx == tail_cell_idx);
    wire        self_collision = in_bounds ? (grid_reg[new_head_idx] && !moving_into_tail) : 1'b0;

    always @(posedge clk or posedge rst) begin
        if (rst)
            collision_flag <= 1'b0;
        else if (state != S_PLAYING)
            collision_flag <= 1'b0;
        else if (move_tick)
            collision_flag <= wall_collision || self_collision;
    end

    assign game_over = (state == S_DEAD);
    assign menu_active = (state == S_MENU);

    // Food eaten check (only when food is validly placed)
    wire food_eaten = food_valid && move_tick && will_grow;

    //----------------------------------------------------------------------
    // Snake movement + grid update (on game_tick)
    //----------------------------------------------------------------------
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 1200; i = i + 1)
                grid_reg[i] <= 1'b0;

            grid_reg[15*40 + 18] <= 1'b1;
            grid_reg[15*40 + 19] <= 1'b1;
            grid_reg[15*40 + 20] <= 1'b1;

            snake_x[0] <= 6'd18;  snake_y[0] <= 5'd15;
            snake_x[1] <= 6'd19;  snake_y[1] <= 5'd15;
            snake_x[2] <= 6'd20;  snake_y[2] <= 5'd15;

            head_idx  <= 8'd3;
            tail_idx  <= 8'd0;
            snake_len <= 9'd3;
            head_x_reg    <= 6'd20;
            head_y_reg    <= 5'd15;
        end
        // Entering playing state: reset snake body
        else if (state == S_MENU && next_state == S_PLAYING) begin
            for (i = 0; i < 1200; i = i + 1)
                grid_reg[i] <= 1'b0;

            grid_reg[15*40 + 18] <= 1'b1;
            grid_reg[15*40 + 19] <= 1'b1;
            grid_reg[15*40 + 20] <= 1'b1;

            snake_x[0] <= 6'd18;  snake_y[0] <= 5'd15;
            snake_x[1] <= 6'd19;  snake_y[1] <= 5'd15;
            snake_x[2] <= 6'd20;  snake_y[2] <= 5'd15;

            head_idx  <= 8'd3;
            tail_idx  <= 8'd0;
            snake_len <= 9'd3;
            head_x_reg    <= 6'd20;
            head_y_reg    <= 5'd15;
        end
        // Normal movement — block if collision would occur THIS tick
        else if (move_tick && !wall_collision && !self_collision) begin
            // Add new head
            grid_reg[new_head_y * 40 + new_head_x] <= 1'b1;
            snake_x[head_idx] <= new_head_x;
            snake_y[head_idx] <= new_head_y;
            head_idx <= head_idx + 8'd1;
            head_x_reg   <= new_head_x;
            head_y_reg   <= new_head_y;

            if (food_eaten && snake_len < MAX_LEN) begin
                snake_len <= snake_len + 9'd1;
            end else begin
                // Remove tail
                grid_reg[snake_y[tail_idx] * 40 + snake_x[tail_idx]] <= 1'b0;
                tail_idx <= tail_idx + 8'd1;
            end
        end
    end

    //----------------------------------------------------------------------
    // Food position (with collision avoidance)
    //----------------------------------------------------------------------
    // Candidate position from LFSR (updates every cycle)
    wire [5:0] cand_food_x = {1'b0, lfsr_val[5:0]}  % 6'd40;
    wire [4:0] cand_food_y = lfsr_val[10:6] % 5'd30;
    wire       cand_blocked = grid_reg[cand_food_y * 40 + cand_food_x];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            food_x_reg  <= 6'd10;
            food_y_reg  <= 5'd10;
            food_valid  <= 1'b0;
        end
        else if (state == S_PLAYING) begin
            // Invalidate food when eaten or on manual restart
            if (food_eaten)
                food_valid <= 1'b0;

            // Generate new food if needed (retries every cycle until success)
            if (!food_valid) begin
                if (!cand_blocked) begin
                    food_x_reg <= cand_food_x;
                    food_y_reg <= cand_food_y;
                    food_valid <= 1'b1;
                end
                // else: stay invalid, LFSR gives new candidate next cycle
            end
        end
        else begin
            // S_DEAD: invalidate food so restart generates fresh one
            food_valid <= 1'b0;
        end
    end

    //----------------------------------------------------------------------
    // Score (BCD)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            score_reg <= 16'd0;
        else if (state == S_MENU && next_state == S_PLAYING)
            score_reg <= 16'd0;
        else if (state == S_PLAYING && food_eaten && score_reg != 16'h9999) begin
            if (score_reg[3:0] == 4'd9) begin
                score_reg[3:0] <= 4'd0;
                if (score_reg[7:4] == 4'd9) begin
                    score_reg[7:4] <= 4'd0;
                    if (score_reg[11:8] == 4'd9) begin
                        score_reg[11:8] <= 4'd0;
                        score_reg[15:12] <= score_reg[15:12] + 4'd1;
                    end else
                        score_reg[11:8] <= score_reg[11:8] + 4'd1;
                end else
                    score_reg[7:4] <= score_reg[7:4] + 4'd1;
            end else
                score_reg[3:0] <= score_reg[3:0] + 4'd1;
        end
    end

    //----------------------------------------------------------------------
    // High score history (per difficulty)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            high_easy_reg   <= 16'd0;
            high_normal_reg <= 16'd0;
            high_hard_reg   <= 16'd0;
        end
        else if (move_tick && (wall_collision || self_collision)) begin
            case (difficulty_reg)
                2'd0: if (score_reg > high_easy_reg)   high_easy_reg   <= score_reg;
                2'd1: if (score_reg > high_normal_reg) high_normal_reg <= score_reg;
                2'd2: if (score_reg > high_hard_reg)   high_hard_reg   <= score_reg;
                default: ;
            endcase
        end
    end

    //----------------------------------------------------------------------
    // Outputs
    //----------------------------------------------------------------------
    assign score           = score_reg;
    assign difficulty      = difficulty_reg;
    assign high_score_easy = high_easy_reg;
    assign high_score_normal = high_normal_reg;
    assign high_score_hard = high_hard_reg;
    assign snake_grid_flat = grid_reg;
    assign food_x          = food_x_reg;
    assign food_y          = food_y_reg;
    assign head_x          = head_x_reg;
    assign head_y          = head_y_reg;

endmodule
