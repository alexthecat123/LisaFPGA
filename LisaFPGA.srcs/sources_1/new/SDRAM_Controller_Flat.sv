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
    (*MARK_DEBUG = "TRUE" *) output logic _CE_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic _OE_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic _WE_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic _UDS_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic _LDS_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic [20:1] A_SRAM,
    (*MARK_DEBUG = "TRUE" *) input logic [15:0] DIN_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic [15:0] DOUT_SRAM,
    (*MARK_DEBUG = "TRUE" *) output logic SRAM_BUS_DIR
    );

    (*MARK_DEBUG = "TRUE" *) logic [7:0] row_addr; // Latched row address (from A0-A7)
    (*MARK_DEBUG = "TRUE" *) logic [7:0] col_addr; // Latched column address (from A0-A7)

    // Latch the row address on the falling edge of _RAS
    always_ff @(negedge _RAS) begin
        row_addr <= A;
    end

    // Latch the column address on the falling edge of _CAS (if _RAS is already active)
    always_ff @(negedge _CAS) begin
        if (!_RAS) // Only latch if _RAS is already low
            col_addr <= A;
    end

    // Select the SDRAM when both RAS and CAS are low
    (*MARK_DEBUG = "TRUE" *) logic _CS;
    always_ff @(posedge clk) begin
        if (!_RAS && !_CAS) begin
            _CS <= 1'b0; // SDRAM selected
        end else begin
            _CS <= 1'b1; // Not selected
        end
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