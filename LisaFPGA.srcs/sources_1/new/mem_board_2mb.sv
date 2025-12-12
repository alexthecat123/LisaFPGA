`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 08/30/2025 12:00:42 PM
// Design Name: Apple Lisa 2MB Memory Board
// Module Name: mem_board_2mb
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

module mem_board_2mb(
    // The address to feed to the RAM chips; gets interpreted as a row or column address
    input logic [8:1] RA,

    // Higher-order address lines passed straight through from the CPU board
    // On normal RAM boards, these are used for bank selection
    // But here we feed them straight to the SDRAM controller since SDRAM uses a different addressing scheme
    input wire A16,
    input wire A17,
    input wire A18,
    input wire A19,
    input wire A20,

    // The RAM size select lines from the jumpers on the PCB
    (* MARK_DEBUG = "TRUE" *) input logic [1:0] RAM_SEL,

    // The 20-ish MHz dot clock
    input logic DOTCK,
    // Upper and lower data strobes
    input wire _UDS,
    input wire _LDS,
    // Column and row address strobes
    input logic _CAS,
    input logic _RAS,
    // High for reads, low for writes
    input logic MREAD,

    // The bidirectional memory data bus
    input logic [15:0] MD_IN,
    output logic [15:0] MD_OUT,

    // Hard and soft error signals; indicates an unrecoverable (HDER) or recoverable (SFER) read error
    // SFER wasn't implemented on the original boards, and isn't implemented here either
    // Either the CPU board or the RAM board can assert HDER or SFER
    // The RAM board in the case of a parity error, and the CPU board in the case of forcing an error for testing purposes
    // But our SDRAM-based board doesn't do parity checking, so it can't really generate HDER either
    // The logic is still here though for ease of re-enabling in the future
    input logic _HDER_in,
    output logic _HDER_out,
    output logic HDER_OE,
    input logic _SFER_in,
    output logic _SFER_out,
    output logic SFER_OE,

    // Signals to the external SDRAM chip
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

    // The memory data bus is bidirectional, so we need to mux the input and output based on whether we're reading or writing
    logic [15:0] MD;
    logic LBDSL_readop;
    assign MD = LBDSL_readop ? MD_OUT : MD_IN;
   
    
    assign _SFER_out = 1'b1; // SFER isn't implemented on Apple's RAM boards or ours, so just keep it deasserted
    assign SFER_OE = 1'b0;

    (* MARK_DEBUG = "TRUE" *) logic [7:0] buffered_RA;

    logic CAS, RAS;

    logic BDSL;
    (* MARK_DEBUG = "TRUE" *) logic LBDSL;

    // Get the active-high versions of CAS and RAS
    assign CAS = ~_CAS;
    assign RAS = ~_RAS;

    // Latch the RAM address whenever CAS goes low
    // The original logic continually latches it until CAS goes low and then stops, so that's what we do too
    always_ff @(posedge DOTCK) begin
        if (_CAS) begin
            buffered_RA <= RA;
        end
    end

    // The original RAM boards would decode the high-order address lines and SLOT signals to generate a board select signal
    // But since we just have a single board with 2MB of SDRAM, we can just tie the board select high all the time
    assign BDSL = 1'b1;

    // We latch the board select signal when RAS is low, for use in the parity-checking circuitry
    // It's always high here, but I kept the original logic anyway in case we want to re-enable multiple memory boards in the future
    always @(_RAS, BDSL) begin
        if (!_RAS) begin
            LBDSL <= BDSL;
        end
    end

    // Now time for the (currently disabled) parity checking logic
    logic disable_parity;
    assign disable_parity = 1'b1; // Go ahead and disable parity checking before we forget
    (* MARK_DEBUG = "TRUE" *) logic latched_parity_lower, latched_parity_upper;
    (* MARK_DEBUG = "TRUE" *) logic write_bad_parity_lower, write_bad_parity_upper;
    (* MARK_DEBUG = "TRUE" *) logic PIL, POL, PIU, POU;
    (* MARK_DEBUG = "TRUE" *) logic low_odd, high_odd;
    (* MARK_DEBUG = "TRUE" *) logic invalid_parity, invalid_parity_latched;

    // Whenever RAS is asserted, latch the lower and upper parity coming out of the parity RAM chips (that we don't have)
    always @(RAS, POL, POU) begin
        if (RAS) begin
            latched_parity_lower <= POL;
            latched_parity_upper <= POU;
        end
    end

    // We force the LS280s to generate bad parity in two situations
    // One is if _HDER is asserted, which can be done by either logic on the CPU board on on the RAM board
    // And the other is if we're doing a read op (obviously we don't care in writes) and the latched parity isn't even like it should be
    // Do this for the upper and lower bytes
    assign write_bad_parity_lower = ~(~(latched_parity_lower & MREAD) & _HDER_in);
    assign write_bad_parity_upper = ~(~(latched_parity_upper & MREAD) & _HDER_in);

    // Make our two LS280 parity generators and checkers
    // The main input to each one is the mem data bus, but the high bit is the write_bad_parity signal so we can force bad parity
    // The even output feeds straight into the parity RAM input, and the odd output is used by us in our logic
    parity_generator_LS280 lower_byte_parity(
        .ABCDEFGHI({write_bad_parity_lower, MD[7:0]}),
        .EVEN(PIL),
        .ODD(low_odd)
    );

    parity_generator_LS280 upper_byte_parity(
        .ABCDEFGHI({write_bad_parity_upper, MD[15:8]}),
        .EVEN(PIU),
        .ODD(high_odd)
    );

    // Parity is considered invalid if either the low byte is selected and the low byte has odd parity
    // Or the high byte is selected and the high byte has odd parity
    assign invalid_parity = (~(_LDS | low_odd) | ~(_UDS | high_odd));

    // Take the latched board select from earlier and AND it with MREAD, so that it's only asserted during read operations
    // LBDSL is always asserted thanks to our earlier logic, so LBDSL_readop basically just follows MREAD here
    // But we keep the original logic in case we want to re-enable multiple memory boards in the future
    assign LBDSL_readop = LBDSL & MREAD;

    // The parity error flip-flop, which is clocked by _CAS and asynchronously cleared by our readop-only board select from above
    always_ff @(posedge _CAS, negedge LBDSL_readop) begin
        if (!LBDSL_readop) begin
            invalid_parity_latched <= 1'b0;
        end else begin
            // This flip-flop just lets us hold onto the bad parity until the next memory cycle, so we can tell the CPU board about it
            invalid_parity_latched <= invalid_parity;
        end
    end

    // We've encountered a hard memory error if we're in the middle of a read op (with this board selected) and the parity is invalid
    // We have to make an OE for HDER here since the CPU board can drive it too; it gets muxed with the CPU board in top.sv
    // Prevemt HDER from ever being asserted if parity checking is disabled (which it is currently thanks to our SDRAM)
    assign _HDER_out = disable_parity ? 1'b1 : (LBDSL_readop & invalid_parity_latched ? 1'b0 : 1'b1);
    assign HDER_OE = disable_parity ? 1'b0 : (LBDSL_readop & invalid_parity_latched);

    // The last thing to do before we instantiate the SDRAM controller is to implement the RAM size select jumpers
    // All we do is check the jumpers and inhibit RAS/CAS if the CPU tries to access memory beyond the selected size
    // The jumper configs are:
        // 00 = 512KB
        // 01 = 1MB
        // 10 = 1.5MB
        // 11 = 2MB (all RAM enabled)
    (* MARK_DEBUG = "TRUE" *) logic _CAS_sdram;
    (* MARK_DEBUG = "TRUE" *)logic _RAS_sdram;
    always_comb begin
        case (RAM_SEL)
            2'b00: begin // 512KB
                if (A20 || A19) begin // If either A20 or A19 is set, then it means the CPU is trying to access beyond 512KB
                    _CAS_sdram = 1'b1;
                    _RAS_sdram = 1'b1;
                end else begin
                    _CAS_sdram = _CAS;
                    _RAS_sdram = _RAS;
                end
            end
            2'b01: begin // 1MB
                if (A20) begin // If A20 is set, then it means the CPU is trying to access beyond 1MB
                    _CAS_sdram = 1'b1;
                    _RAS_sdram = 1'b1;
                end else begin
                    _CAS_sdram = _CAS;
                    _RAS_sdram = _RAS;
                end
            end
            2'b10: begin // 1.5MB
                if (A20 && A19) begin // If both A20 and A19 are set, then it means the CPU is trying to access beyond 1.5MB
                    _CAS_sdram = 1'b1;
                    _RAS_sdram = 1'b1;
                end else begin
                    _CAS_sdram = _CAS;
                    _RAS_sdram = _RAS;
                end
            end
            default: begin // 2MB, all RAM enabled
                _CAS_sdram = _CAS;
                _RAS_sdram = _RAS;
            end
        endcase
    end

    // Now make the SDRAM controller instance
    SDRAM_Controller_Flat SDRAM_2MB(
        .clk(DOTCK),
        .A(buffered_RA),
        .A16(A16),
        .A17(A17),
        .A18(A18),
        .A19(A19),
        .A20(A20),
        .MD(MD),
        .R_W(MREAD),
        ._CAS(_CAS_sdram),
        ._RAS(_RAS_sdram),
        ._UDS(_UDS),
        ._LDS(_LDS),
        .DO(MD_OUT),
        .PO({POU, POL}),
        ._CE_SRAM(_CE_SRAM),
        ._OE_SRAM(_OE_SRAM),
        ._WE_SRAM(_WE_SRAM),
        ._UDS_SRAM(_UDS_SRAM),
        ._LDS_SRAM(_LDS_SRAM),
        .A_SRAM(A_SRAM),
        .DIN_SRAM(DIN_SRAM),
        .DOUT_SRAM(DOUT_SRAM),
        .SRAM_BUS_DIR(SRAM_BUS_DIR)
    );
endmodule