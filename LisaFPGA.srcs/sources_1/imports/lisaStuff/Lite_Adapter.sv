`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 10/11/2025 08:31:03 PM
// Design Name: Apple Lisa Lite Adapter
// Module Name: Lite_Adapter
// Project Name: LisaFPGA
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


module Lite_Adapter(
    input logic clk,
    input logic rst,
    input logic PH0,
    input logic MT,
    output logic PWM
    );

    // The Lite Adapter is pretty simple; it just generates a PWM signal for the floppy drive
    // It does this by comparing a shift register value to a counter value
    // The Lisa sets the PWM value by shifting bits into the shift register on PH0, clocked by MT
    // The counter runs at 5MHz, and the PWM output is high when the shift register value is greater than or equal to the counter value

    // Make sure to synchronize both MT and PH0 to the clk (C5M) domain to avoid any metastability issues
    (* ASYNC_REG = "TRUE" *) logic MT_int, PH0_int, MT_sync, PH0_sync;
    always_ff @(posedge clk) begin
        MT_int <= MT;
        PH0_int <= PH0;
        MT_sync <= MT_int;
        PH0_sync <= PH0_int;
    end

     // Now handle the shift register; reset it on system reset and shift in PH0 on the rising edge of MT
    logic [7:0] shiftreg;
    logic MT_prev;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            shiftreg <= 8'b0;
            MT_prev <= 1'b0;
        end else if (MT_sync && !MT_prev) begin
            shiftreg <= {shiftreg[6:0], PH0_sync};
        end
        MT_prev <= MT_sync;
    end

    // And now do the 8-bit counter running at 5MHz; reset it on system reset and increment it on the rising edge of clk
    logic [7:0] counter;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= 8'b0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    // Finally, compare the two values and set PWM low if shiftreg < counter, high otherwise
    // PWM is latched in a flip-flop clocked by the 5MHz clock by the way
    always_ff @(posedge clk) begin
        if (shiftreg < counter) begin
            PWM <= 1'b0;
        end else begin
            PWM <= 1'b1;
        end
    end

endmodule