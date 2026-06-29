`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2025 12:02:16 PM
// Design Name: 
// Module Name: SDRAM_Controller
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

module SDRAM_Controller_Flat(
    input logic clk,
    input logic [7:0] A,
    input logic A16,
    input logic A17,
    input logic A18,
    input logic A19,
    input logic A20,
    input logic [15:0] MD,
    input logic R_W,
    input logic _CAS,
    input logic _RAS,
    input logic _UDS,
    input logic _LDS,
    output logic [15:0] DO,
    output logic [1:0] PO,
    output logic _CE_SRAM,
    output logic _OE_SRAM,
    output logic _WE_SRAM,
    output logic _UDS_SRAM,
    output logic _LDS_SRAM,
    output logic [20:1] A_SRAM,
    input logic [15:0] DIN_SRAM,
    output logic [15:0] DOUT_SRAM,
    output logic SRAM_BUS_DIR
    );

    logic [7:0] row_addr; // Latched row address (from A0-A7)
    logic [7:0] col_addr; // Latched column address (from A0-A7)

    logic _RAS_prev, _CAS_prev; // Previous states of RAS and CAS for edge detection

    // Latch the row address on the falling edge of _RAS
    /*always_ff @(negedge _RAS) begin
        row_addr <= A;
    end*/
    always_ff @(posedge clk) begin
        if (!_RAS && _RAS_prev) begin // Latch the row address on the falling edge of _RAS
            row_addr <= A;
        end
        _RAS_prev <= _RAS; // Update the previous state of _RAS for edge detection
        _CAS_prev <= _CAS; // And do _CAS too
    end

    // Latch the column address on the falling edge of _CAS (if _RAS is already active)
    /*always_ff @(negedge _CAS) begin
        if (!_RAS) // Only latch if _RAS is already low
            col_addr <= A;
    end*/
    always_ff @(posedge clk) begin
        if (!_CAS && _CAS_prev && !_RAS) begin // Only latch the column address if _CAS is falling and _RAS is already low
            col_addr <= A;
        end
    end

    // Stick the _CS register in an IOB instead of a regular FF so that the SRAM chip sees it as quickly as possible
    // This allows us to have maximal selection time, which is important given that its 55ns timing is already marginal at a 75MHz DOTCK
    (* IOB = "TRUE" *) logic _CS;
    // Select the SDRAM when both RAS and CAS are low
    //logic _delayed_RAS;
    //logic _even_more_delayed_RAS;
    always_ff @(posedge clk) begin
        if (!_RAS && !_CAS) begin
        //if (!_RAS && ! _delayed_RAS) begin // _even_more_delayed_RAS
            _CS <= 1'b0; // SDRAM selected
        end else begin
            _CS <= 1'b1; // Not selected
        end
        //_delayed_RAS <= _RAS;
        //_even_more_delayed_RAS <= _delayed_RAS;
    end

    // Now let's hook all these signals up to the SDRAM chip
    assign _CE_SRAM = _CS;
    assign _OE_SRAM = ~R_W; // Output enable is low (asserted) for read operations only
    assign _WE_SRAM = R_W | (_LDS & _UDS); // Write enable is low (asserted) for write operations, but only when LDS or UDS is also low
    // During writes, UDS and LDS should be forwarded straight through to the RAM so that we only write the intended bytes
    // But during reads, they should always be asserted (low) so that we always read both bytes; the CPU can ignore the unwanted byte
    assign _UDS_SRAM = _UDS & ~R_W;
    assign _LDS_SRAM = _LDS & ~R_W;
    // The full SDRAM address is made up of A20-A17 from the CPU, plus the latched row and column addresses
    // Not A16 because that's included in the row/column addresses already (A16-A1)
    assign A_SRAM = {A20, A19, A18, A17, row_addr, col_addr};
    assign DO = DIN_SRAM; // Data output from SDRAM, renamed for use by the rest of the system
    assign DOUT_SRAM = MD; // Data to SDRAM from controller
    assign SRAM_BUS_DIR = R_W; // Control the direction of the SDRAM data bus

    assign PO = 2'b00; // Parity output not implemented


endmodule