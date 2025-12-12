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


/*module SDRAM_Controller(
    input logic clk,
    input logic [7:0] A,
    input logic [15:0] MD,
    input logic R_W,
    input logic [3:0] _CAS,
    input logic [3:0] _RAS,
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
    always_ff @(negedge (&_RAS)) begin
        row_addr <= A;
    end

    // Latch the column address on the falling edge of _CAS (if RAS is already active)
    always_ff @(negedge (&_CAS)) begin
        if (!_RAS[0] | !_RAS[1] | !_RAS[2] | !_RAS[3]) // Only latch if RAS is already low
            col_addr <= A;
    end

    // The bank address is determined by which RAS/CAS pair is active; it'll be the high 2 bits of the SDRAM address
    (*MARK_DEBUG = "TRUE" *) logic [1:0] bank_addr;
    (*MARK_DEBUG = "TRUE" *) logic _CS;
    always_ff @(posedge clk) begin
        if (!_RAS[0] && !_CAS[0]) begin
            bank_addr <= 2'b00;
            _CS <= 1'b0; // Bank 0 selected
        end else if (!_RAS[1] && !_CAS[1]) begin
            bank_addr <= 2'b01;
            _CS <= 1'b0; // Bank 1 selected
        end else if (!_RAS[2] && !_CAS[2]) begin
            bank_addr <= 2'b10;
            _CS <= 1'b0; // Bank 2 selected
        end else if (!_RAS[3] && !_CAS[3]) begin
            bank_addr <= 2'b11;
            _CS <= 1'b0; // Bank 3 selected
        end else begin
            _CS <= 1'b1; // Not selected
        end
    end

    assign _CE_SRAM = 1'b0; // Chip enable is always low (asserted)
    assign _UDS_SRAM = _UDS; // Forward the upper and lower data strobes straight through to the RAM
    assign _LDS_SRAM = _LDS;
    assign A_SRAM = {2'b00, bank_addr, row_addr, col_addr}; // Concatenate bank, row, and column addresses to form the full SDRAM address

    assign PO = 2'b00; // Parity output not implemented

    // We're going to need a state machine to handle the SDRAM timing requirements, so let's set up some registers for that
    (*MARK_DEBUG = "TRUE" *) logic we_int;
    (*MARK_DEBUG = "TRUE" *) logic oe_int;
    (*MARK_DEBUG = "TRUE" *) logic bus_drive;

    logic [15:0] dout_int;
    logic [15:0] din_int;

    assign DOUT_SRAM = dout_int; // Drive the SDRAM data bus from our internal register
    assign DO = din_int; // Data output from SDRAM, renamed for use by the rest of the system
    assign SRAM_BUS_DIR = ~bus_drive; // And control the direction of the SDRAM data bus

    // WE and OE are asserted whenever their internal equivalents are asserted and the chip is selected
    assign _WE_SRAM = we_int | _CS;
    assign _OE_SRAM = oe_int | _CS;

    assign DO = din_int; // Drive the output data from our internal register

    // Normally I just use numbers for state machines, but in this case I'll try something new
    // Let's use an enum instead to make it more readable
    typedef enum logic [2:0] {
        IDLE = 3'd0,
        WRITE_SETUP = 3'd1,
        WRITE_PULSE = 3'd2,
        WRITE_DONE  = 3'd3,
        READ_SETUP  = 3'd4,
        READ_ENABLE = 3'd5,
        READ_DONE   = 3'd6
    } SDRAM_state_t;

    (*MARK_DEBUG = "TRUE" *) SDRAM_state_t state, next_state;

    // Now let's make an edge detector for CAS so we can figure out when reads and writes start
    logic any_CAS;
    logic any_CAS_int;
    // We care about the falling edge of any CAS line, so let's combine them
    assign any_CAS = &(_CAS);
    always_ff @(posedge clk) begin
        any_CAS_int <= any_CAS;
    end
    // And now the falling edge detection
    (*MARK_DEBUG = "TRUE" *) logic cas_falling_edge;
    assign cas_falling_edge = any_CAS_int & ~any_CAS;

    // Also capture whatever's on the data bus at that moment for write operations, in case the op takes multiple cycles and the bus changes
    always_ff @(posedge clk) begin
        if (state == IDLE && cas_falling_edge && !R_W) begin
            dout_int <= MD;
        end
    end

    // Now we need logic to figure out the next state based on the current state and inputs
    always_comb begin
        next_state = state; // Default to staying in the same state
        case (state)
            // If we're currently idle, wait for a CAS falling edge to start a read or write operation
            IDLE: begin
                if (cas_falling_edge) begin
                    if (R_W) begin
                        next_state = READ_SETUP;
                    end else begin
                        next_state = WRITE_SETUP;
                    end
                end
            end
            // If we're in a write, go through the write states (setup, pulse, done, back to idle)
            WRITE_SETUP: begin
                next_state = WRITE_PULSE;
            end
            WRITE_PULSE: begin
                next_state = WRITE_DONE;
            end
            WRITE_DONE: begin
                next_state = IDLE;
            end
            // If we're in a read, go through the read states (setup, enable, done, back to idle)
            READ_SETUP: begin
                next_state = READ_ENABLE;
            end
            READ_ENABLE: begin
                next_state = READ_DONE;
            end
            READ_DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE; // Fallback to idle on invalid state (shouldn't happen)
            end
        endcase
    end

    // Now let's implement the state transitions and output logic
    always_ff @(posedge clk) begin
        // Transition to the next state on each clock cycle
        state <= next_state;
        // And then figure out what to do based on the state
        case (next_state)
            IDLE: begin
                // Do nothing in idle; write disabled, output disabled, and data bus not driven
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b0;
            end
            WRITE_SETUP: begin
                // In write setup, prepare to write by starting to drive the data bus, but don't assert write yet
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b1;
            end
            WRITE_PULSE: begin
                // Now in write pulse, actually assert write enable to perform the write
                we_int <= 1'b0;
                oe_int <= 1'b1;
                bus_drive <= 1'b1;
            end
            WRITE_DONE: begin
                // When the write is done, deassert write enable, but don't release the bus yet; we'll do that in the next state (idle)
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b1;
            end
            READ_SETUP: begin
                // In read setup, just make sure that everything is disabled to give the address time to settle
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b0;
            end
            READ_ENABLE: begin
                // Now enable the output to read the data from SDRAM, and of course don't drive the data bus
                we_int <= 1'b1;
                oe_int <= 1'b0;
                bus_drive <= 1'b0;
            end
            READ_DONE: begin
                // Disable output again and capture the data into our internal register
                din_int <= DIN_SRAM;
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b0;
            end
            default: begin
                // Fallback to idle behavior on invalid state (shouldn't happen)
                we_int <= 1'b1;
                oe_int <= 1'b1;
                bus_drive <= 1'b0;
            end
        endcase
    end

endmodule
*/

module SDRAM_Controller_Banked(
    input logic clk,
    input logic [7:0] A,
    input logic [15:0] MD,
    input logic R_W,
    input logic [3:0] _CAS,
    input logic [3:0] _RAS,
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
    always_ff @(negedge (&_RAS)) begin
        row_addr <= A;
    end

    // Latch the column address on the falling edge of _CAS (if RAS is already active)
    always_ff @(negedge (&_CAS)) begin
        if (!_RAS[0] | !_RAS[1] | !_RAS[2] | !_RAS[3]) // Only latch if RAS is already low
            col_addr <= A;
    end

    // The bank address is determined by which RAS/CAS pair is active; it'll be the high 2 bits of the SDRAM address
    (*MARK_DEBUG = "TRUE" *) logic [1:0] bank_addr;
    (*MARK_DEBUG = "TRUE" *) logic _CS;
    always_ff @(posedge clk) begin
        if (!_RAS[0] && !_CAS[0]) begin
            bank_addr <= 2'b00;
            _CS <= 1'b0; // Bank 0 selected
        end else if (!_RAS[1] && !_CAS[1]) begin
            bank_addr <= 2'b01;
            _CS <= 1'b0; // Bank 1 selected
        end else if (!_RAS[2] && !_CAS[2]) begin
            bank_addr <= 2'b10;
            _CS <= 1'b0; // Bank 2 selected
        end else if (!_RAS[3] && !_CAS[3]) begin
            bank_addr <= 2'b11;
            _CS <= 1'b0; // Bank 3 selected
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
    assign A_SRAM = {2'b00, bank_addr, row_addr, col_addr}; // Concatenate bank, row, and column addresses to form the full SDRAM address
    assign DO = DIN_SRAM; // Data output from SDRAM, renamed for use by the rest of the system
    assign DOUT_SRAM = MD; // Data to SDRAM from controller
    assign SRAM_BUS_DIR = R_W; // Control the direction of the SDRAM data bus

    assign PO = 2'b00; // Parity output not implemented


endmodule