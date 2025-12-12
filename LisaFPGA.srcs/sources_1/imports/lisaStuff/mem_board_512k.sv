`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 08/30/2025 12:00:42 PM
// Design Name: Apple Lisa 512K Memory Board
// Module Name: mem_board_512k
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

// ******** Discrepancies From Original Design ********
// Original logic only latches RAM address every other DOTCK cycle, but we latch every cycle; hopefully not a problem
// Original logic generates a buffered /CAS called /B_CAS, I guess to reduce loading of the original signal, but we don't do this

module mem_board_512k(
    // The address to feed to the RAM chips; gets interpreted as a row or column address
    input logic [8:1] RA,

    // Address lines used for RAM bank selection, slot decoding, and refresh cycles in the case of VA9/10
    input wire A17,
    input wire A18,
    input wire A19,
    input wire A20,
    input logic VA9,
    input logic VA10,

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
    // Motherboard drives this high in one slot and low in the other
    input logic SLOT,
    // Goes low when the CPU board wants to refresh some RAM
    input logic _RFSH,
    
    // These are just tied to Vcc and GND; used for more slot decoding
    output logic T1,
    output logic T2,
    output logic T3,

    // None of these are connected to anything
    input wire A16,
    input logic S1,
    input logic S2,
    input logic S3,

    // The bidirectional memory data bus
    input logic [15:0] MD_IN,
    output logic [15:0] MD_OUT,

    // Hard and soft error signals; indicates an unrecoverable (HDER) or recoverable (SFER) read error
    // SFER wasn't implemented on the original boards, and isn't implemented here either
    // Either the CPU board or the RAM board can assert HDER or SFER
    // The RAM board in the case of a parity error, and the CPU board in the case of forcing an error for testing purposes
    input logic _HDER_in,
    output logic _HDER_out,
    output logic HDER_OE,
    input logic _SFER_in,
    output logic _SFER_out,
    output logic SFER_OE,

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

    logic [15:0] MD;
    logic LBDSL_readop;
    assign MD = LBDSL_readop ? MD_OUT : MD_IN;
    //assign MD = MREAD ? 16'h1234 : 16'bz; // Temporary: always read back 0x1234
    //assign _HDER = 1'bz; // Temporary: never assert HDER
    assign _SFER_out = 1'b1; // SFER isn't implemented on Apple's RAM boards, so just keep it deasserted
    assign SFER_OE = 1'b0;

    (* MARK_DEBUG = "TRUE" *) logic [7:0] buffered_RA;
    logic [7:0] _decoded_bank_address;
    logic [3:0] _decoded_RAS_address;

    logic CAS, RAS;
    logic CAS0_sel, CAS1_sel, CAS2_sel, CAS3_sel;
    logic RAS0_sel, RAS1_sel, RAS2_sel, RAS3_sel;
    (* MARK_DEBUG = "TRUE" *) logic _CAS0, _CAS1, _CAS2, _CAS3;
    (* MARK_DEBUG = "TRUE" *) logic _RAS0, _RAS1, _RAS2, _RAS3;

    logic BDSL;
    (* MARK_DEBUG = "TRUE" *) logic LBDSL;

    logic [3:0] _A19_A20_decoded;

    assign T3 = 1'b1;
    assign T2 = 1'b0;
    assign T1 = 1'b0;

    assign CAS = ~_CAS;
    assign RAS = ~_RAS;

    // Latch the RAM address whenever CAS goes low
    // The original logic continually latches it until CAS goes low and then stops, so that's what we do too
    always_ff @(posedge DOTCK) begin
        if (_CAS) begin
            buffered_RA <= RA;
        end
    end

    // Decode the RAM chip to select based on SLOT, A17, and A18
    // Outputs are active low
    decoder_3to8 bank_address_decoder(
        .ABC({SLOT, A18, A17}),
        ._G2A(1'b0),
        ._G2B(1'b0),
        .G1(1'b1),
        ._Y(_decoded_bank_address)
    );

    // There are multiple ways to select chips with RAS; one of them is for memory refresh cycles based on VA9 and VA10
    // Outputs are active low
    decoder_2to4 RAS_address_decoder(
        .AB({VA10, VA9}),
        ._G(_RFSH),
        ._Y(_decoded_RAS_address)
    );

    // Each CAS is selected based on two bits of the bank address decoder output
    assign CAS0_sel = ~(_decoded_bank_address[3] & _decoded_bank_address[4]);
    assign CAS1_sel = ~(_decoded_bank_address[2] & _decoded_bank_address[5]);
    assign CAS2_sel = ~(_decoded_bank_address[1] & _decoded_bank_address[6]);
    assign CAS3_sel = ~(_decoded_bank_address[0] & _decoded_bank_address[7]);

    // But the final active-low _CAS signal is also gated with the master CAS signal and the board select signal
    assign _CAS0 = ~(BDSL & CAS0_sel & CAS);
    assign _CAS1 = ~(BDSL & CAS1_sel & CAS);
    assign _CAS2 = ~(BDSL & CAS2_sel & CAS);
    assign _CAS3 = ~(BDSL & CAS3_sel & CAS);

    // RAS selection is similar to CAS selection, except RAS can also be fired off by the refresh decoder
    assign RAS0_sel = ~(_decoded_RAS_address[0] & _decoded_bank_address[3] & _decoded_bank_address[4]);
    assign RAS1_sel = ~(_decoded_RAS_address[1] & _decoded_bank_address[2] & _decoded_bank_address[5]);
    assign RAS2_sel = ~(_decoded_RAS_address[2] & _decoded_bank_address[1] & _decoded_bank_address[6]);
    assign RAS3_sel = ~(_decoded_RAS_address[3] & _decoded_bank_address[0] & _decoded_bank_address[7]);

    // Each final active-low _RAS signal is gated with the master RAS signal
    assign _RAS0 = ~(RAS0_sel & RAS);
    assign _RAS1 = ~(RAS1_sel & RAS);
    assign _RAS2 = ~(RAS2_sel & RAS);
    assign _RAS3 = ~(RAS3_sel & RAS);

    // Decodes A19 and A20 so that we can determine if this board is the one being addressed
    // Remember that the decoder outputs are active low
    decoder_2to4 board_select_decoder(
        .AB({A20, A19}),
        ._G(1'b0),
        ._Y(_A19_A20_decoded)
    );

    // This board is selected if we're in the low SLOT, A19 is high, and A20 is low, or we're in the high SLOT, A20 is high, and A19 is low
    assign BDSL = (~(~SLOT | _A19_A20_decoded[2]) | ~(SLOT | _A19_A20_decoded[1]));

    // We latch the board select signal when RAS is low, for use in the parity-checking circuitry
    always @(_RAS, BDSL) begin
        if (!_RAS) begin
            LBDSL <= BDSL;
        end
    end

    (* MARK_DEBUG = "TRUE" *) logic latched_parity_lower, latched_parity_upper;
    (* MARK_DEBUG = "TRUE" *) logic write_bad_parity_lower, write_bad_parity_upper;
    (* MARK_DEBUG = "TRUE" *) logic PIL, POL, PIU, POU;
    (* MARK_DEBUG = "TRUE" *) logic low_odd, high_odd;
    (* MARK_DEBUG = "TRUE" *) logic invalid_parity, invalid_parity_latched;

    // Whenever RAS is asserted, latch the lower and upper parity coming out of the parity RAM chips
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
    // Prevemt HDER from ever being asserted if parity checking is disabled (for SDRAM operation)
    assign _HDER_out = disable_parity ? 1'b1 : (LBDSL_readop & invalid_parity_latched ? 1'b0 : 1'b1);
    assign HDER_OE = disable_parity ? 1'b0 : (LBDSL_readop & invalid_parity_latched);
    //assign _HDER_DAT = ~(~(LBDSL_readop & invalid_parity_latched));
    //assign HDER_OE = ~(LBDSL_readop & invalid_parity_latched);

    (* MARK_DEBUG = "TRUE" *) logic LR_W, UR_W;

    // The R/W signals for the lower and upper banks of RAM
    assign LR_W = _LDS | MREAD;
    assign UR_W = _UDS | MREAD;

    logic [15:0] DO;
    logic _DOlatch_OE;

    // We should enable the output of the memory DO (Data Out) latch if this board is selected and it's a read cycle
    // This latch drives the main MD bus if it's enabled, so obviously we don't want to enable it on writes
    assign _DOlatch_OE = ~(LBDSL & MREAD);

    // The latch updates its contents whenever RAS is asserted
    /*always @(RAS, DO, _DOlatch_OE) begin
        if (RAS) begin
            // Update the data on MD on every clock
            MD_DAT <= DO;
            // But only output it if the latch output is enabled; if not, then the CPU board is driving the bus
            MD_OE <= ~_DOlatch_OE;
        end
    end*/

    // If we're simulating, then we need to use block RAM
    // So instantiate two RAM matrices, each of which is 256K x 8 Bits worth of 4164s
    // One's the low byte of the RAM board, and the other's the high byte
    logic disable_parity;
    `ifdef SIMULATION
        assign disable_parity = 1'b0; // In simulation, we always want parity checking enabled since we're using 18-bit wide block RAMs
        RAM_matrix low_byte_matrix(
            .clk(DOTCK),
            .A(buffered_RA),
            .MD(MD_IN[7:0]),
            .PI(PIL),
            .R_W(LR_W),
            ._CAS({_CAS3, _CAS2, _CAS1, _CAS0}),
            ._RAS({_RAS3, _RAS2, _RAS1, _RAS0}),
            .DO(MD_OUT[7:0]),
            .PO(POL)
        );

        RAM_matrix high_byte_matrix(
            .clk(DOTCK),
            .A(buffered_RA),
            .MD(MD_IN[15:8]),
            .PI(PIU),
            .R_W(UR_W),
            ._CAS({_CAS3, _CAS2, _CAS1, _CAS0}),
            ._RAS({_RAS3, _RAS2, _RAS1, _RAS0}),
            .DO(MD_OUT[15:8]),
            .PO(POU)
        );
    `else
        // Otherwise, instantiate the SDRAM controller to drive real SDRAM chips
        assign disable_parity = 1'b1; // When using real SDRAM, we don't want parity checking since SDRAM doesn't support it
        SDRAM_Controller_Banked SDRAM_2MB(
            .clk(DOTCK),
            .A(buffered_RA),
            .MD(MD),
            .R_W(MREAD),
            ._CAS({_CAS3, _CAS2, _CAS1, _CAS0}),
            ._RAS({_RAS3, _RAS2, _RAS1, _RAS0}),
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
    `endif

endmodule
