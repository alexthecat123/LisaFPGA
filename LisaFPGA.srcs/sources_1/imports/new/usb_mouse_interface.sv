`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/15/2025 05:49:45 PM
// Design Name: 
// Module Name: usb_keyboard_interface
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module usb_mouse_interface(
    input logic usbclk,
    input logic usbrst,
    input logic signed [7:0] mouse_dx_in,
    input logic signed [7:0] mouse_dy_in,
    input logic [7:0] mouse_btn_in,
    input logic report,
    output logic [6:0] M
    );

    // The mouse button states from mouse_btn_in, but broken out and latched
    (*MARK_DEBUG = "true"*) logic left;
    (*MARK_DEBUG = "true"*) logic middle;
    (*MARK_DEBUG = "true"*) logic right;
    // The latched versions of mouse_dx_in and mouse_dy_in
    (*MARK_DEBUG = "true"*) logic signed [7:0] mouse_dx;
    (*MARK_DEBUG = "true"*) logic signed [7:0] mouse_dy;

    //localparam int ACCUM_SHIFT = 4;   // 16 sub-pixels per quadrature step

    // High-resolution accumulators
    //logic signed [15:0] accum_x;
    //logic signed [15:0] accum_y;

    // Now latch the button states on report
    always_ff @(posedge usbclk, negedge usbrst) begin
        // On reset, clear all the latched values
        if (!usbrst) begin
            left <= 1'b0;
            right <= 1'b0;
            middle <= 1'b0;
        end else if (report) begin
            // If report is asserted, latch the button states and movement values
            mouse_dx <= mouse_dx_in;
            mouse_dy <= mouse_dy_in;
            left <= mouse_btn_in[0];
            right <= mouse_btn_in[1];
            middle <= mouse_btn_in[2];
        end
    end

    // The button states go straight through to the M output lines, just inverted, so map them now
    assign M[5] = ~left;
    //assign M[0] = ~right;
    //assign M[3] = ~middle;
    // Middle and right buttons aren't connected on the Lisa, so just leave them low to tell the Lisa that the mouse is plugged in
    assign M[0] = 1'b0;
    assign M[3] = 1'b0;

    // -------------------------------------------------------------------------
    // Internal: movement accumulators
    // -------------------------------------------------------------------------
    (*MARK_DEBUG = "true"*) logic signed [15:0] x_accum = 0;
    (*MARK_DEBUG = "true"*) logic signed [15:0] y_accum = 0;

    // -------------------------------------------------------------------------
    // Quadrature state machines
    // A/B sequences for + direction:
    //     00 → 01 → 11 → 10 → (repeat)
    // and reverse order for negative direction.
    // -------------------------------------------------------------------------

    logic [1:0] x_phase = 2'b00;
    logic [1:0] y_phase = 2'b00;

    // Output assignment
    assign M[6] = x_phase[1];
    assign M[2] = x_phase[0];
    assign M[1] = y_phase[1];
    assign M[4] = y_phase[0];

    // Divider for stepping speed
    (*MARK_DEBUG = "true"*) logic [12:0] divcnt = 0;
    //logic [12:0] set_div_val = 6000;

    (*MARK_DEBUG = "true"*) logic new_delta;
    assign new_delta = report;

    // Pulse generation occurs when we still have movement accumulated
    (*MARK_DEBUG = "true"*) logic x_pending;
    (*MARK_DEBUG = "true"*) logic y_pending;
    assign x_pending = (x_accum != 0);
    assign y_pending = (y_accum != 0);

    always @(posedge usbclk) begin
        if (!usbrst) begin
            divcnt  <= 0;
            x_phase <= 2'b00;
            y_phase <= 2'b00;
            x_accum <= 16'd0;
            y_accum <= 16'd0;
       end else begin
            // Accumulate new deltas           
            if (x_pending && (divcnt == 13'd6000) && new_delta) begin
                x_accum <= x_accum > 16'sd0 ? x_accum - 16'sd1 + mouse_dx : x_accum <= x_accum + 16'sd1 + mouse_dx;
            end
            else if (x_pending && (divcnt == 13'd6000)) begin
                x_accum <= x_accum > 16'sd0 ? x_accum - 16'sd1 : x_accum + 16'sd1;
            end
            else if (new_delta) begin
                x_accum <= x_accum + mouse_dx;
            end
            // Y accumulation
            if (y_pending && (divcnt == 13'd6000) && new_delta) begin
                y_accum <= y_accum > 16'sd0 ? y_accum - 16'sd1 + mouse_dy : y_accum <= y_accum + 16'sd1 + mouse_dy;
            end
            else if (y_pending && (divcnt == 13'd6000)) begin
                y_accum <= y_accum > 16'sd0 ? y_accum - 16'sd1 : y_accum + 16'sd1;
            end
            else if (new_delta) begin
                y_accum <= y_accum + mouse_dy;
            end
            // Divider counting
            if (divcnt == 13'd6000) begin
                divcnt <= 0;

                // ------------------- X movement ------------------------------
                if (x_pending) begin
                    if (x_accum > 0) begin
                        // forward sequence
                        case (x_phase)
                            2'b00: x_phase <= 2'b01;
                            2'b01: x_phase <= 2'b11;
                            2'b11: x_phase <= 2'b10;
                            2'b10: x_phase <= 2'b00;
                        endcase
                        //x_accum <= x_accum - 1;
                    end else begin
                        // reverse sequence
                        case (x_phase)
                            2'b00: x_phase <= 2'b10;
                            2'b10: x_phase <= 2'b11;
                            2'b11: x_phase <= 2'b01;
                            2'b01: x_phase <= 2'b00;
                        endcase
                        //x_accum <= x_accum + 1;
                    end
                end

                // ------------------- Y movement ------------------------------
                if (y_pending) begin
                    if (y_accum > 0) begin
                        case (y_phase)
                            2'b00: y_phase <= 2'b01;
                            2'b01: y_phase <= 2'b11;
                            2'b11: y_phase <= 2'b10;
                            2'b10: y_phase <= 2'b00;
                        endcase
                        //y_accum <= y_accum - 1;
                    end else begin
                        case (y_phase)
                            2'b00: y_phase <= 2'b10;
                            2'b10: y_phase <= 2'b11;
                            2'b11: y_phase <= 2'b01;
                            2'b01: y_phase <= 2'b00;
                        endcase
                        //y_accum <= y_accum + 1;
                    end
                end

            end else begin
                divcnt <= divcnt + 1;
            end
        end
    end

    // But we need to scale the mouse movement values to make it feel better on the Lisa


    // Thresholds for different sensitivity zones
    /*localparam FINE_THRESHOLD = 2;      // Full sensitivity below this
    localparam MEDIUM_THRESHOLD = 1000;   // Reduced sensitivity above this
    
    logic signed [7:0] abs_dx;
    logic is_negative_dx;
    
    assign is_negative_dx = mouse_dx[7];
    assign abs_dx = is_negative_dx ? -mouse_dx : mouse_dx;
    
    logic signed [7:0] scaled_abs_dx;

    logic signed [7:0] scaled_mouse_dx;

    always_comb begin
        if (abs_dx <= FINE_THRESHOLD) begin
            // Small movements: 1:1 mapping
            scaled_abs_dx = abs_dx;
        end
        else if (abs_dx <= MEDIUM_THRESHOLD) begin
            // Medium movements: 0.33x sensitivity
            scaled_abs_dx = FINE_THRESHOLD + ((abs_dx - FINE_THRESHOLD) * 341 >> 10);
        end
        else begin
            // Large movements: 0.25x sensitivity
            scaled_abs_dx = FINE_THRESHOLD + 
                         ((MEDIUM_THRESHOLD - FINE_THRESHOLD) * 341 >> 10) +
                         ((abs_dx - MEDIUM_THRESHOLD) >> 2);
        end
        
        // Restore sign
        scaled_mouse_dx = is_negative_dx ? -scaled_abs_dx : scaled_abs_dx;
    end

    logic signed [7:0] abs_dy;
    logic is_negative_dy;
    
    assign is_negative_dy = mouse_dy[7];
    assign abs_dy = is_negative_dy ? -mouse_dy : mouse_dy;
    
    logic signed [7:0] scaled_abs_dy;

    logic signed [7:0] scaled_mouse_dy;

    always_comb begin
        if (abs_dy <= FINE_THRESHOLD) begin
            // Small movements: 1:1 mapping
            scaled_abs_dy = abs_dy;
        end
        else if (abs_dy <= MEDIUM_THRESHOLD) begin
            // Medium movements: 0.33x sensitivity
            scaled_abs_dy = FINE_THRESHOLD + ((abs_dy - FINE_THRESHOLD) * 341 >> 10);
        end
        else begin
            // Large movements: 0.25x sensitivity
            scaled_abs_dy = FINE_THRESHOLD + 
                         ((MEDIUM_THRESHOLD - FINE_THRESHOLD) * 341 >> 10) +
                         ((abs_dy - MEDIUM_THRESHOLD) >> 2);
        end
        
        // Restore sign
        scaled_mouse_dy = is_negative_dy ? -scaled_abs_dy : scaled_abs_dy;
    end

    // M6 and M2 are right/left movement
    // M1 and M4 are up/down movement

    // Now we need to send over the movement values
    // The Lisa mouse uses quadrature encoding for movement
    // M6 and M2 are right/left movement and M1 and M4 are up/down movement
    // Each movement step consists of 4 transitions on the two lines
    // For right movement, the sequence is:
    //   M6 M2
    //   0  0
    //   1  0
    //   1  1
    //   0  1
    //   0  0
    // For left movement, the sequence is reversed
    //   M6 M2
    //   0  0
    //   0  1
    //   1  1
    //   1  0
    //   0  0
    // Up/down movement on M1 and M4 is the same idea
    // We'll interpret positive values in mouse_dx/mouse_dy as right/up movement, negative as left/down
    
    // Before we do any state machines though, we need to create a clock enable for M movement
    // Let's make it so that M updates at approximately 1000Hz; any faster and the Lisa may not be able to keep up
    // Given that clk is 12MHz, we need a divide-by-12000 counter
    (*MARK_DEBUG = "true"*) logic [13:0] m_clk_divider;
    (*MARK_DEBUG = "true"*) logic m_clk_en;
    always_ff @(posedge clk, negedge rst_int) begin
        if (!rst_int) begin
            m_clk_divider <= 14'd0;
            m_clk_en <= 1'b0;
        end else begin
            if (m_clk_divider == 14'd11999) begin // Change to 5 for testing
                m_clk_divider <= 14'd0;
                m_clk_en <= 1'b1;
            end else begin
                m_clk_divider <= m_clk_divider + 1'b1;
                m_clk_en <= 1'b0;
            end
        end
    end

    // Use an enum to define the states for the movement state machines
    typedef enum logic [1:0] {
        IDLE,
        STEP1,
        STEP2,
        STEP3
    } move_state_t;

    // And create signals to hold the current state for X and Y movement
    (*MARK_DEBUG = "true"*) move_state_t x_state;
    (*MARK_DEBUG = "true"*) move_state_t y_state;

    // As well as for the remaining movement counters
    (*MARK_DEBUG = "true"*) logic signed [7:0] x_movement_remaining;
    (*MARK_DEBUG = "true"*) logic signed [7:0] y_movement_remaining;

    always_ff @(posedge clk, negedge rst_int) begin
        if (!rst_int) begin
            x_movement_remaining <= 8'sd0;
            x_state <= IDLE;
            M[6] <= 1'b0;
            M[2] <= 1'b0;
        // Only proceed with movement if m_clk_en is asserted (about 1000Hz)
        end else if (report) begin
            x_movement_remaining <= scaled_mouse_dx;
        end else if (m_clk_en) begin
            case (x_state)
                IDLE: begin
                    // In the idle state, check if we have any movement remaining
                    // And if so, go to STEP1 to start sending pulses to the Lisa
                    // Also, make sure both M1 and M4 are deasserted
                    M[6] <= 1'b0;
                    M[2] <= 1'b0;
                    if (x_movement_remaining != 0) begin
                        x_state <= STEP1;
                    end
                end
                // In STEP1, assert either M6 or M2 depending on direction, then go to STEP2
                STEP1: begin
                    if (x_movement_remaining > 0) begin
                        M[6] <= 1'b0;
                        M[2] <= 1'b1;
                    end else if (x_movement_remaining < 0) begin
                        M[6] <= 1'b1;
                        M[2] <= 1'b0;
                    end
                    x_state <= STEP2;
                end
                // In STEP2, assert both M6 and M2, which will be the case for both directions, then go to STEP3
                STEP2: begin
                    M[6] <= 1'b1;
                    M[2] <= 1'b1;
                    x_state <= STEP3;
                end
                // In STEP3, deassert either M4 or M1 depending on direction, then either add or subtract 1 from the remaining movement counter and go back to IDLE
                // And return to IDLE
                STEP3: begin
                    if (x_movement_remaining > 0) begin
                        M[6] <= 1'b1;
                        M[2] <= 1'b0;
                        x_movement_remaining <= x_movement_remaining - 1;
                    end else if (x_movement_remaining < 0) begin
                        M[6] <= 1'b0;
                        M[2] <= 1'b1;
                        x_movement_remaining <= x_movement_remaining + 1;
                    end
                    x_state <= IDLE;
                end
            endcase
        end
    end

    // Do the exact same thing for the Y movement on M1 and M4
    always_ff @(posedge clk, negedge rst_int) begin
        if (!rst_int) begin
            y_movement_remaining <= 8'sd0;
            y_state <= IDLE;
            M[4] <= 1'b0;
            M[1] <= 1'b0;
        end else if (report) begin
            y_movement_remaining <= scaled_mouse_dy;
        // Only proceed with movement if m_clk_en is asserted (about 1000Hz)
        end else if (m_clk_en) begin
            case (y_state)
                IDLE: begin
                    // In the idle state, check if we have any movement remaining
                    // And if so, go to STEP1 to start sending pulses to the Lisa
                    // Also, make sure both M1 and M4 are deasserted
                    M[4] <= 1'b0;
                    M[1] <= 1'b0;
                    if (y_movement_remaining != 0) begin
                        y_state <= STEP1;
                    end
                end
                // In STEP1, assert either M4 or M1 depending on direction, then go to STEP2
                STEP1: begin
                    if (y_movement_remaining > 0) begin
                        M[4] <= 1'b1;
                        M[1] <= 1'b0;
                    end else if (y_movement_remaining < 0) begin
                        M[4] <= 1'b0;
                        M[1] <= 1'b1;
                    end
                    y_state <= STEP2;
                end
                // In STEP2, assert both M4 and M1, which will be the case for both directions, then go to STEP3
                STEP2: begin
                    M[4] <= 1'b1;
                    M[1] <= 1'b1;
                    y_state <= STEP3;
                end
                // In STEP3, deassert either M4 or M1 depending on direction, then either add or subtract 1 from the remaining movement counter and go back to IDLE
                // And return to IDLE
                STEP3: begin
                    if (y_movement_remaining > 0) begin
                        M[4] <= 1'b0;
                        M[1] <= 1'b1;
                        y_movement_remaining <= y_movement_remaining - 1;
                    end else if (y_movement_remaining < 0) begin
                        M[4] <= 1'b1;
                        M[1] <= 1'b0;
                        y_movement_remaining <= y_movement_remaining + 1;
                    end
                    y_state <= IDLE;
                end
            endcase
        end
    end*/

endmodule