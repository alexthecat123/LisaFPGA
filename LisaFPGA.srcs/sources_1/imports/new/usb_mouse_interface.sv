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
    logic left;
    logic middle;
    logic right;
    // The latched versions of mouse_dx_in and mouse_dy_in
    logic signed [7:0] mouse_dx;
    logic signed [7:0] mouse_dy;

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


    // Most of the stuff from here down was written by someone else; not me
    // I was really struggling with getting the USB mouse scaling to feel good, so someone sent me this, and it just worked
    // So I'm not gonna mess with it and risk breaking anything

    // -------------------------------------------------------------------------
    // Internal: movement accumulators
    // -------------------------------------------------------------------------
    logic signed [15:0] x_accum = 0;
    logic signed [15:0] y_accum = 0;

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
    logic [12:0] divcnt = 0;
    //logic [12:0] set_div_val = 6000;

    logic new_delta;
    assign new_delta = report;

    // Pulse generation occurs when we still have movement accumulated
    logic x_pending;
    logic y_pending;
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
                x_accum <= x_accum > 16'sd0 ? x_accum - 16'sd1 + mouse_dx : x_accum + 16'sd1 + mouse_dx;
            end
            else if (x_pending && (divcnt == 13'd6000)) begin
                x_accum <= x_accum > 16'sd0 ? x_accum - 16'sd1 : x_accum + 16'sd1;
            end
            else if (new_delta) begin
                x_accum <= x_accum + mouse_dx;
            end
            // Y accumulation
            if (y_pending && (divcnt == 13'd6000) && new_delta) begin
                y_accum <= y_accum > 16'sd0 ? y_accum - 16'sd1 + mouse_dy : y_accum + 16'sd1 + mouse_dy;
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

endmodule