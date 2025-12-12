`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 08/31/2025 03:21:11 PM
// Design Name: The Apple Lisa CPU Board
// Module Name: CPU_board
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


module CPU_board(
    output logic _SL0,
    output logic _SH0,
    output logic _SL1,
    output logic _SH1,
    output logic _SL2,
    output logic _SH2,
    input wire _INT0, // open-collector, pulled up on CPU board
    output wire _IAK0, // open-collector, i guess supposed to be pulled up on card
    input wire _INT1, // open-collector, pulled up on CPU board
    output wire _IAK1, // open-collector, i guess supposed to be pulled up on card
    input wire _INT2, // open-collector, pulled up on CPU board
    output wire _IAK2, // open-collector, i guess supposed to be pulled up on card
    (* MARK_DEBUG = "TRUE" *) input wire _RSIR, // open-collector, pulled up on CPU board
    (* MARK_DEBUG = "TRUE" *) input wire _KBIR, // open-collector, pulled up on CPU board
    (* MARK_DEBUG = "TRUE" *) input logic _IOIR, // open-collector, pulled up on i/o and CPU board
    output logic E,
    output logic _RESET, // may need to be open-collector, wait for IOB to find out
    output logic CPUCK,
    input wire _LDMA, // open-collector i think
    input wire _BGACK, // also open-collector i think
    input wire _BR, // also open-collector i think
    output logic _BG, // check if open-collector, not sure
    (* MARK_DEBUG = "TRUE" *) input logic [15:0] BD_in, // bidirectional tri-state bus
    (* MARK_DEBUG = "TRUE" *) output logic [15:0] BD_out,
    (* MARK_DEBUG = "TRUE" *) output logic BD_OE,
    output wire [12:1] A_OUT, // tri-state address bus (tri-stated by BGACK)
    output logic _VMA,
    (* MARK_DEBUG = "TRUE" *) input logic _VPA_in, // open-collector i think, input to CPU, driven by stuff on CPU board and presumably I/O board too
    (* MARK_DEBUG = "TRUE" *) output logic _VPA_out,
    (* MARK_DEBUG = "TRUE" *) output logic VPA_OE,
    (* MARK_DEBUG = "TRUE" *) input logic _DTACK_in,
    (* MARK_DEBUG = "TRUE" *) output logic _DTACK_out,
    (* MARK_DEBUG = "TRUE" *) output logic DTACK_OE,
    output wire _AS, // tri-state b/c of BGACK, pulled up to 5V when not in use
    output wire READ, // tri-state b/c of BGACK, pulled up to 5V
    output wire _LDS, // tri-state b/c of BGACK, pulled up to 5V
    output wire _UDS, // tri-state b/c of BGACK, pulled up to 5V
    output logic _CSYNC,
    output logic _INTIO,
    output logic VA10B,
    output logic VA9B,
    output logic _R1,
    output logic _R2,
    (* MARK_DEBUG = "TRUE" *) input logic [15:0] MD_IN,
    (* MARK_DEBUG = "TRUE" *) output logic [15:0] MD_OUT,
    (* MARK_DEBUG = "TRUE" *) output logic [8:1] RA,
    (* MARK_DEBUG = "TRUE" *) input logic _RSTSW,
    (* MARK_DEBUG = "TRUE" *) output wire A16, // all 4 of these are tri-state b/c of BGACK
    (* MARK_DEBUG = "TRUE" *) output wire A17,
    (* MARK_DEBUG = "TRUE" *) output wire A18,
    (* MARK_DEBUG = "TRUE" *) output wire A19,
    (* MARK_DEBUG = "TRUE" *) input logic DOTCK,
    (* MARK_DEBUG = "TRUE" *) output logic MREAD,
    (* MARK_DEBUG = "TRUE" *) output logic _CAS,
    (* MARK_DEBUG = "TRUE" *) output logic _RAS,
    (* MARK_DEBUG = "TRUE" *) output wire A20, // tri-state b/c of BGACK
    (* MARK_DEBUG = "TRUE" *) output logic _HSYNC,
    input logic _HDER_in,
    output logic _HDER_out,
    output logic HDER_OE,
    (* MARK_DEBUG = "TRUE" *) output logic _VSYNC,
    input logic _SFER_in,
    output logic _SFER_out,
    output logic SFER_OE,
    (* MARK_DEBUG = "TRUE" *) output logic VID,
    (* MARK_DEBUG = "TRUE" *) input logic _NMI, // open-collector

    // Everything below here are signals added by me that weren't on the edge connector of the original CPU board
    // The LED hooked to the video address latch
    output logic VAL_LED,
    // The inverse video flag, but exposed to the top-level module so we can control it with a switch or something
    input logic INVID,
    output logic E_pos_phase, // A pulse that goes high for two cycle just after the rising edge of E
    output logic E_neg_phase,  // A pulse that goes high for two cycles just after the falling edge of E
    output logic E_either_edge, // A pulse that goes high for one cycle just after either edge of E
    input logic CPU_ROM_SEL, // Selects whether the CPU board uses revision H or 3A boot ROMs (and VSROMs)
    output logic VA_overflow, // Goes high during vertical blanking interval (for longer than _VSYNC)
    output logic _clr_vid_clk // Goes low during horizontal active video (for shorter than _HSYNC)
    );

    // The internal CPU board version of the address bus is narrower than the version that's exposed to other cards
    // So map the low 12 bits of the wide internal version to the narrow external one
    (* MARK_DEBUG = "TRUE" *) tri [20:1] A;
    assign A_OUT = A[12:1];

    // The CPU core we're using separates the data bus into two unidirectional buses: one for input and one for output
    // So we do the same throughout the CPU board design
    // Make sure the bus going into the CPU goes into a known state when nothing's driving it
    // Otherwise the CPU core will break b/c it can't handle Z values on its input bus
    (* MARK_DEBUG = "TRUE" *) tri [15:0] UD_CPU_out;
    (* MARK_DEBUG = "TRUE" *) tri0 [15:0] UD_CPU_in;

    // Emulate the LS245s that make connections between the memory, buffered, and unbuffered data buses
    // First, we need to define _MDEN for enabling the MD-to-BD transceiver
    // _MDEN is asserted if the current cycle is not an I/O cycle, not a special I/O (MMU/ROM) cycle, and is a CPU (not video) cycle
    (* MARK_DEBUG = "TRUE" *) logic _MDEN;
    (* MARK_DEBUG = "TRUE" *) logic CPUC1;
    (* MARK_DEBUG = "TRUE" *) logic _IOCY;
    (* MARK_DEBUG = "TRUE" *) logic _SPIO;
    assign _MDEN = ~(CPUC1 & _IOCY & _SPIO);

    /*always @(CPUC1, _IOCY, _SPIO, _CDACK) begin
        if (CPUC1 & _IOCY & _SPIO) begin
            _MDEN <= 1'b0;
        end else if (_CDACK) begin
            _MDEN <= 1'b1;
        end
    end*/

    (* MARK_DEBUG = "TRUE" *) tri [15:0] BD;
    // For our data bus mux in top.sv, we pass BD through to the output all the time
    assign BD_out = BD;
    // And only feed the muxed BD value through to our internal BD_in when the CPU board isn't driving BD
    assign BD = (BD_OE) ? 16'bz : BD_in;

    (* MARK_DEBUG = "TRUE" *) logic _DBON;
    // And now we can do the transceiver logic
    // First, we pass BD through to MD if we're doing a write and _MDEN is asserted, else high-z
    assign MD_OUT = (~READ & ~_MDEN) ? BD : 16'b0;
    //assign MD = (~READ & ~_MDEN) ? BD : 16'bz;
    // We can also go the other way, passing MD through to BD, if we're doing a read and _MDEN is asserted, else high-z
    // We need an output enable signal too, for the external BD mux in top.sv
    // That's because the BD signal is driven by multiple sources (CPU, I/O, etc.) and the synthesizer won't let us do our normal tri-state trick
    assign BD = (READ & ~_MDEN) ? MD_IN : 16'bz;
    tri0 BD_OE_int;
    assign BD_OE = BD_OE_int;
    assign BD_OE_int = (READ & ~_MDEN) ? 1'b1 : 1'bz;
    //assign BD = (READ & ~_MDEN) ? MD : 16'bz;
    // BD can also be set to UD if we're doing a write and _DBON is asserted, else high-z
    assign BD = (~READ & ~_DBON) ? UD_CPU_out : 16'bz;
    assign BD_OE_int = (~READ & ~_DBON) ? 1'b1 : 1'bz;
    // And finally, UD can take on the value of BD if we're doing a read and _DBON is asserted, else high-z
    assign UD_CPU_in = (READ & ~_DBON) ? BD : 16'bz;

    // The interrupt priority level that gets fed to the CPU
    (* MARK_DEBUG = "TRUE" *) logic [2:0] _IPL;
    // Encodes one of the 7 interrupt types into an IPL priority level for the CPU
    // The IPL output hooks straight into the CPU
    (* MARK_DEBUG = "TRUE" *) logic _HPIR;
    // We're going to need an internal version of the I/O interrupt signal that incorporates the CPU board's _IOIR input
    // We'll generate it later though
    (* MARK_DEBUG = "TRUE" *) logic _IOIR_int;
    encoder_8to3_LS148 IRQ_encoder(
        ._D({_HPIR, _RSIR, _INT0, _INT1, _INT2, _KBIR, _IOIR_int, _IOIR_int}),
        ._EI(1'b0),
        ._Q(_IPL)
    );

    // Replicate the reset/halt logic from the 555 timer
    // Counter for reset state
    logic [23:0] rst_counter;
    // The reset line coming out of our "555"; gets fed to the CPU
    (* MARK_DEBUG = "TRUE" *) logic _RSTHLT_555;
    logic fast_reset;
    always_ff @(posedge DOTCK, negedge _RSTSW) begin
        // If the reset switch is being pressed, then clear the reset counter, and set _RSTHLT_555 low since we're now in reset
        if (!_RSTSW) begin
            rst_counter <= 24'b0;
            _RSTHLT_555 <= 1'b0;
        end else begin
            // If rst_counter is greater than 20 million, then we've been in reset for about a second, so get out of reset now
            if (rst_counter > 24'd20) begin
                _RSTHLT_555 <= 1'b1;
            end else begin
                // Otherwise, we still need to be in reset, so increment the counter (one increment per CPUCK) and ensure _RSTHLT is low
                rst_counter <= rst_counter + 1'b1;
                if (rst_counter < 24'd5) begin
                    fast_reset <= 1'b1;
                end else begin
                    fast_reset <= 1'b0;
                end
                _RSTHLT_555 <= 1'b0;
            end
        end
    end

    // The system-wide halt signal is asserted if either the 555 halt or the CPU-generated halt is asserted
    // This is done with wire-AND logic on the original board, but since our CPU core has separate ports for HALT in and HALT out,
    // We do it with a plain old assign statement instead
    logic _HALT;
    logic _HALTOUT_CPU;
    assign _HALT = _RSTHLT_555 & _HALTOUT_CPU;

    // Reset is a similar deal; it's just the 555 reset/halt signal wire-ANDed (or just ANDed in our case) with the CPU RESET output
    logic _RSTOUT_CPU;
    assign _RESET = _RSTHLT_555 & _RSTOUT_CPU;


    // Now to replicate the other function of the 555: the bus error timeout counter
    // It's basically just a constantly-running counter that gets reset whenever we see the end of an AS
    // And if the counter isn't reset in time and gets too big, it puts out a pulse on _BUST to signify a bus error
    logic [15:0] bust_counter;
    logic _BUST;
    always_ff @(posedge CPUCK, negedge _RSTHLT_555, posedge _AS) begin
        // If the Lisa is in reset or we want to reset the timer with AS, then reset the counter and make sure _BUST is deasserted
        if (!_RSTHLT_555 || _AS) begin
            bust_counter <= 16'b0;
            _BUST <= 1'b1;
        // Otherwise, we need to see if we have a bus error or not
        end else begin
            // If the counter is greater than 1000 (1000/5000000 = 200us-ish delay), then assert _BUST to indicate a bus error
            if (bust_counter > 16'd1000) begin
                _BUST <= 1'b0;
            end else begin
                // Otherwise, just increment the counter and make sure _BUST is deasserted
                bust_counter <= bust_counter + 1'b1;
                _BUST <= 1'b1;
            end
        end
    end

    // Unbuffered versions of _UDS, _LDS, _AS, and READ, right off the CPU
    (* MARK_DEBUG = "TRUE" *) logic _UUDS, _ULDS, _UAS, UREAD;
    // If BGACK says the CPU doesn't control the bus, disconnect the CPU from the buffered versions of these signals
    // Otherwise, we are in control, so pass the unbuffered versions through to the buffered ones
    assign _UDS = _BGACK ? _UUDS : 1'bz;
    assign _LDS = _BGACK ? _ULDS : 1'bz;
    assign _AS =  _BGACK ? _UAS : 1'bz;
    assign READ = _BGACK ? UREAD : 1'bz;

    // Now do the same thing with the unbuffered and buffered address buses
    // Note that we only care about passing on the lower 8 bits here b/c the rest go thru the MMU
    (* MARK_DEBUG = "TRUE" *) logic [23:1] UA;
    logic [23:1] UA_CPU;
    assign UA = !_RSTHLT_555 ? 23'b0 : UA_CPU;
    assign A[8:1] = _BGACK ? UA[8:1] : 8'bz;


    // Time to do the boot ROMs; this is the OE signal for them
    (* MARK_DEBUG = "TRUE" *) logic _ROM;

    // And now we instantiate them; note that we can load ROM files that will be "burnt" into the ROMs during synthesis
    // One ROM connects to the low byte of the UD bus and the other connects to the high byte
    // But we actually need two sets of ROMs, one for revision H and one for revision 3A
    // And we use the CPU_ROM_SEL signal to pick between them
    bootrom_2764 #(.ROM_file("CPU_LOW_H.mem")) low_ROM_H(
        .A(UA[13:1]),
        ._OE(_ROM | CPU_ROM_SEL), // Use the H ROMs when CPU_ROM_SEL is low
        ._CE(1'b0),
        .D(UD_CPU_in[7:0])
    );

    bootrom_2764 #(.ROM_file("CPU_HIGH_H.mem")) high_ROM_H(
        .A(UA[13:1]),
        ._OE(_ROM | CPU_ROM_SEL), // Use the H ROMs when CPU_ROM_SEL is low
        ._CE(1'b0),
        .D(UD_CPU_in[15:8])
    );

    bootrom_2764 #(.ROM_file("CPU_LOW_3A.mem")) low_ROM_3A(
        .A(UA[13:1]),
        ._OE(_ROM | ~CPU_ROM_SEL), // Use the 3A ROMs when CPU_ROM_SEL is high
        ._CE(1'b0),
        .D(UD_CPU_in[7:0])
    );

    bootrom_2764 #(.ROM_file("CPU_HIGH_3A.mem")) high_ROM_3A(
        .A(UA[13:1]),
        ._OE(_ROM | ~CPU_ROM_SEL), // Use the 3A ROMs when CPU_ROM_SEL is high
        ._CE(1'b0),
        .D(UD_CPU_in[15:8])
    );


    // Now it's time to do the memory error address latches
    // Whenever there's an HDER or SFER (hard or soft memory error), the error address gets latched for our future reference
    // Only A6-A20 and whether it was a video cycle are latched; this is plenty to be able to narrow it down to a single RAM page/chip
    // Pretty nifty for 1983, right?
    logic [15:0] mea_latch;
    // VIDEO is high if we're in a video cycle, low if not
    (* MARK_DEBUG = "TRUE" *) logic VIDEO;
    // Reads from the mem error address latch if asserted
    logic _RMEA;
    // Latch the proper bits of the address and the VIDEO bit
    logic mea_latch_we;
    always_ff @(posedge mea_latch_we) begin
        mea_latch <= {A[20:6], VIDEO};
    end
    // Put the latched data on the bus if the CPU wants to read the latch, otherwise tri-state it
    assign BD = _RMEA ? 16'bz : mea_latch;
    assign BD_OE_int = _RMEA ? 1'bz : 1'b1;


    // There's another address-related latch to do though
    // It's the DMA latch, which holds the top 8 bits (13-20) of the desired address when a peripheral is doing a DMA transfer
    // It's basically exactly the same as the MEA latch above, just with different signal names and widths
    // We only OE the DMA latch if the CPU isn't the bus master and the CPU/master (as opposed to video) is in control of memory addressing
    logic dma_latch_oe;
    (* MARK_DEBUG = "TRUE" *) logic _CMUX;
    assign dma_latch_oe = ~_BGACK & ~_CMUX;
    logic [7:0] dma_latch;
    always_ff @(posedge _LDMA) begin
        dma_latch <= BD[12:5];
    end
    assign A[20:13] = dma_latch_oe ? dma_latch : 8'bz;

    // Now let's process the function code from the CPU and use it to do some interrupt acknowledgement
    logic [2:0] FC;
    logic IAK;
    // This is pretty simple; if FC0-2 are all high, then we need to assert IAK to acknowledge an interrupt
    assign IAK = FC[0] & FC[1] & FC[2];
    // Now we just need to figure out which interrupt to acknowledge, which we do with a decoder
    assign _IAK0 = (IAK & A[3] & !A[2] & A[1]) ? 1'b0 : 1'bz;
    logic [7:0] _IAK_decoded;
    decoder_3to8 IAK_decoder(
    // The decoder takes the low three address bits
    .ABC(A[3:1]),
    // And is enabled whenever both IAK and the unbuffered address strobe are asserted at the same time
    ._G2A((~IAK | _UAS)),
    ._G2B(1'b0),
    .G1(1'b1),
    ._Y(_IAK_decoded)
    );
    // Now we test the appropriate bits in the decoded output to see what to do, setting each _IAK to either 0 or high-z accordingly
    assign _IAK0 = _IAK_decoded[5] ? 1'bz : 1'b0;
    assign _IAK1 = _IAK_decoded[4] ? 1'bz : 1'b0;
    assign _IAK2 = _IAK_decoded[3] ? 1'bz : 1'b0;
    // The other 5 bits of the output all generate _VPA, so pull it from high-z to low if any of them are set
    // We have to do the _VPA open-collecter muxing outside of the CPU module since other modules drive VPA too
    // This is just a weird limitation of the synthesizer, so we have to make an OE signal for VPA too
    // The muxing logic in top.sv returns the final _VPA signal back to the CPU board module as _VPA_in
    assign _VPA_out = (_IAK_decoded[0] & _IAK_decoded[1] & _IAK_decoded[2] & _IAK_decoded[6] & _IAK_decoded[7]) ? 1'bz : 1'b0;
    assign VPA_OE = ~(_IAK_decoded[0] & _IAK_decoded[1] & _IAK_decoded[2] & _IAK_decoded[6] & _IAK_decoded[7]);

    // Time to implement the system status latch
    // It latches the state of _HDER, _SFER, _VSIR (vertical sync interrupt), and _BUST (bus error)
    // It also holds the states of VID (video signal), _CSYNC (combo of _VSYNC and _HSYNC), and INVID (inverse video flag), all unlatched
    // All 4 latched signals except _BUST have masks that can be used to prevent them from being passed thru to the output of the latch
    // _BUST gets set in the latch on a bus error, and gets cleared when we read from the memory error address latch
    logic _SFMSK, _HDMSK, _VTMSK;

    (* MARK_DEBUG = "TRUE" *) logic _SFER_latched, _HDER_latched, _VTIR, _BUST_latched;
    // Latch _SFER
    always @(_SFMSK, _SFER_in) begin
        // If there's a soft error and it's not masked, then latch the error
        if (!_SFER_in & _SFMSK) begin
            _SFER_latched <= 1'b0;
        // Otherwise, if we're masking errors, then ignore all errors and keep the latch at 1 all the time
        end else if (!_SFMSK) begin
            _SFER_latched <= 1'b1;
        end
    end
    // Repeat for _HDER
    always @(_HDMSK, _HDER_in) begin
        if (!_HDER_in & _HDMSK) begin
            _HDER_latched <= 1'b0;
        end else if (!_HDMSK) begin
            _HDER_latched <= 1'b1;
        end
    end
    // And _VSIR (here the output's called _VTIR b/c it's used by other stuff on the schematic)
    logic _VSIR;
    always @(_VTMSK, _VSIR) begin
        if (!_VSIR & _VTMSK) begin
            _VTIR <= 1'b0;
        end else if (!_VTMSK) begin
            _VTIR <= 1'b1;
        end
    end

    // _IOIR was originally open-collector, but for reasons described in IO_board.sv, we're making it a regular logic signal instead
    // So we need to combine the _IOIR signal coming from the I/O board with the stuff that can assert it on the CPU board
    // The CPU board asserts it if _VTIR is asserted (vertical sync interrupt), so we just AND that with the _IOIR input
    assign _IOIR_int = _VTIR & _IOIR;

    // Same idea for _BUST too
    // Unlike the others, there should never be a situation here where both signals are asserted at once, but account for it anyway
    // Here we also need to account for the reset condition, in which case we want _BUST_latched to be deasserted
    always @(_RMEA, _BUST, _RSTHLT_555) begin
        if (!_RSTHLT_555) begin
            _BUST_latched <= 1'b1;
        end else begin
            if (!_BUST & _RMEA) begin
                _BUST_latched <= 1'b0;
            end else if (!_RMEA) begin
                _BUST_latched <= 1'b1;
            end
        end
    end
    // Now put all the values onto the data bus if requested
    // They should be output if selected by _RBES (read bus error status) and be high-z otherwise
    logic _RBES;
    assign BD = _RBES ? 16'bz : {8'b0, 1'b0, INVID, _CSYNC, VID, _BUST_latched, _VTIR, _HDER_latched, _SFER_latched};
    assign BD_OE_int = _RBES ? 1'bz : 1'b1;
    // There are two more signals that are generated as by-products of the latch
    // One is _HPIR (high-priority interrupt), which fires if we get an NMI or either a hard or soft memory error
    assign _HPIR = _NMI & _HDER_latched & _SFER_latched;
    // The other is the clock for the memory error address latch
    // The latch gets commanded to latch the address on every memory cycle, and stops as soon as we get a memory error
    // It won't start latching again until we read the current address from the latch to clear _HDER_latched and/or _SFER_latched
    // The CAS term is what makes it latch on every term as long as HDER and SFER are high
    assign mea_latch_we = ~_CAS & _HDER_latched & _SFER_latched;

    // Now it's time to do the MMU
    // Before we do the core of the MMU, let's do some of the surrounding logic that helps it work
    // Starting with the write enable signal for the MMU registers
    (* MARK_DEBUG = "TRUE" *) logic _MMU_reg_WE;
    (* MARK_DEBUG = "TRUE" *) logic _MMUIO;
    (* MARK_DEBUG = "TRUE" *) logic PCK;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] _T;
    // This takes the form of a JK flip-flop
    always_ff @(posedge DOTCK, posedge _MMUIO, negedge _RSTHLT_555) begin
        // If we're in reset, deassert _MMU_reg_WE
        if (!_RSTHLT_555) begin
            _MMU_reg_WE <= 1'b1;
        // If we're not doing an MMUIO cycle, then we shouldn't be writing to the MMU regs (async preset)
        end else if (_MMUIO) begin
            _MMU_reg_WE <= 1'b1;
        end else begin
            // If the write/_T4 and PCK high conditions are met at the same time, then this turns into a T flip-flop
            // So toggle WE on each clock; not sure if this ever happens in normal operation
            if (!(READ | _T[4]) & PCK) begin
                _MMU_reg_WE <= ~_MMU_reg_WE;
            // Otherwise...
            end else if (!(READ | _T[4]) & !PCK) begin
                // If we're doing a write, we're in timing state T4, and the clock is low, then it's time to assert WE for the MMU regs
                _MMU_reg_WE <= 1'b0;
            end else if ((READ | _T[4]) & PCK) begin
                // If the clock is high and the write and timing state conditions aren't valid, then deassert it
                _MMU_reg_WE <= 1'b1;
            end 
        end
    end

    // Now we have another flop that gates data transfers between the MMU regs and the UD bus
    // It controls the OE of LS245s that hook the reg outputs to the bus
    // The logic for this one is pretty simple b/c the J input to the flop is tied to ground
    // Once again, our logic is slightly different than that of the original schematic
    (* MARK_DEBUG = "TRUE" *) logic _MMU_reg_dat_OE;
    always_ff @(posedge DOTCK, posedge _MMUIO) begin
        // If the MMUIO cycle is over (or we're not doing one at all), then we shouldn't be hooking the MMU regs to the UD bus
        if (_MMUIO) begin
            _MMU_reg_dat_OE <= 1'b1;
        end else begin
            // Otherwise, if we are in an MMU cycle, connect the regs to the UD bus whenever we're in timing state T4
            // It'll stay connected until the MMU cycle is over
            if (!_T[4]) begin
                _MMU_reg_dat_OE <= 1'b0;
            end
        end
    end

    // Now for some of the combinational logic that controls the MMU
    // Selects either a base or limit register
    (* MARK_DEBUG = "TRUE" *) logic B_L;
    // The two signals used to select one of 3 MMU contexts
    // Different from the user-configurable SEG1 and SEG2 b/c these are overridden to force the Lisa into context 0 when in supervisor mode
    (* MARK_DEBUG = "TRUE" *) logic MS1, MS2;
    (* MARK_DEBUG = "TRUE" *) logic SEG1, SEG2;
    // Chip select for the MMU RAM chip that produces the upper 4 bits of the address (in SOR mode) and the 4 control bits (in SLR mode)
    (* MARK_DEBUG = "TRUE" *) logic _MMU_highreg_CS;
    // Choose the SOR (Seg Origin/Base Register) as long as either _MALE is asserted or _MMUIO is asserted while UA3 is high
    // And choose the SLR (Seg Limit Register) otherwise (so if _MALE is deasserted and _MMUIO is not asserted while UA3 is high)
    (* MARK_DEBUG = "TRUE" *) logic _MALE;
    assign B_L = ~_MALE | (~_MMUIO & UA[3]);
    // Pass ~SEG1 through to MS1, but override it to 1 (context 0) if the CPU is in supervisor mode as shown by FC2 being high
    // If it's an MMUIO cycle, then ignore supervisor mode b/c we want to write to the MMU registers in whatever context the user wants
    // Notice that everything's inverted; MS1 = ~SEG1 when passing through, and context 0 is represented by 1 not 0
    assign MS1 = (_MMUIO & FC[2]) ? 1'b1 : ~SEG1;
    // Same thing for MS2, just with SEG2
    assign MS2 = (_MMUIO & FC[2]) ? 1'b1 : ~SEG2;
    // Select the high MMU reg chip if UA14 is high, or we're in an MMUIO cycle (reading/writing MMU regs), or start is deasserted
    // By the way, _START is a signal that lets you access the MMU when your program is executing out of ROM
    // Once you have the MMU set up, you deassert (pull high) _START and then your program can start executing from RAM
    (* MARK_DEBUG = "TRUE" *) logic _START;
    assign _MMU_highreg_CS = !_RSTHLT_555 ? 1'b1 : ~(UA[14] | ~_MMUIO | _START);

    // Next, implement the logic for the LS245 that hooks the UD bus to the MMU reg bus
    // The MMU reg bus is called TD
    logic [11:0] TD;
    // If the LS245 OE is set and we want to read from the MMU regs, then put the MMU reg contents on the UD bus, else high impedance
    // We've got some spare bits, so we use one for the current bit of the serial number too
    logic SN;
    assign UD_CPU_in = (!_MMU_reg_dat_OE & READ) ? {SN, 3'b0, TD[11:0]} : 16'bz;
    // And if we want to write to the MMU regs, then we transfer 12 bits the other direction, from the US bus to the MMU reg bus
    logic [11:0] MMU_RAM_out;
    assign TD = (!_MMU_reg_dat_OE & !READ) ? UD_CPU_out[11:0] : MMU_RAM_out;

    // Aliases of the top 4 bits of the MMU reg output for easier use elsewhere in the system
    (* MARK_DEBUG = "TRUE" *) tri1 _MEM, _IO, _RO, _STK;
    assign _MEM = TD[11];
    assign _IO = TD[10];
    assign _RO = TD[9];
    assign _STK = TD[8];

    // Instantiate each of the 3 MMU RAM chips
    // I have no idea why they put the address lines in the crazy order that they did, but we'll do it the same way
    // The only chip that can be enabled/disabled is the high (seg address in SOR/control bits in SLR) one; the other 2 are always enabled
    // I had to modify these from original 2148s a bit so that it wouldn't compalain about multiple drivers on the data bus
    // The original chips have a bidirectional data bus, but we split it into input and output here
    // Note that the RAM outputs never go high-z; instead they go to 1's when not selected
    // This simulates the pull-up resistors on the original board
    // For some reason, setting MMU_RAM_out to tri1 doesn't work, so we have to do it that way instead
    MMU_RAM_2148 low_MMU_RAM(
        .A_MMU({UA[19:17], UA[21], UA[22], UA[23], MS2, UA[20], B_L, MS1}),
        ._CS(1'b0),
        ._WE(_MMU_reg_WE),
        .D_in(TD[3:0]),
        .D_out(MMU_RAM_out[3:0])
    );
    MMU_RAM_2148 mid_MMU_RAM(
        .A_MMU({UA[19:17], UA[21], UA[22], UA[23], MS2, UA[20], B_L, MS1}),
        ._CS(1'b0),
        ._WE(_MMU_reg_WE),
        .D_in(TD[7:4]),
        .D_out(MMU_RAM_out[7:4])
    );
    MMU_RAM_2148 high_MMU_RAM(
        .A_MMU({UA[19:17], UA[21], UA[22], UA[23], MS2, UA[20], B_L, MS1}),
        ._CS(_MMU_highreg_CS),
        ._WE(_MMU_reg_WE),
        .D_in(TD[11:8]),
        .D_out(MMU_RAM_out[11:8])
    );

    // Now we need to implement the MMU adders that take the segment origin/limit info from the MMU regs and calc the physical address
    // Background on how this works: first the MMU takes the 12-bit seg origin from the SOR and puts it into the adders
    // Seg origin isn't an address; it's the seg number, and the adders add it with the page offset within that seg
    // The page offset also isn't an address; it's the page number
    // The adder output forms bits 9-20 of the physical address; the lower bits are passed thru untouched
    // This gets latched into the mem addr latch with _MALE for presentation to the memory
    // Now B_L flips and the SLR gets exposed to the adders
    // The low 8 bits of the reg contains the # of pages that are present in this seg, and the high 4 bits contain some control bits
    // These bits are _MEM (whether this seg points to mem vs I/O or something else), _IO (same as mem but whether it points toward I/O),
    // _RO (says whether or not seg is read-only), and _STK (stack, meaning it's a stack seg and it grows down not up)
    // The low 8 bits (#pages in seg) go into the adders and are added with our page offset; if carry is set, then our page is beyond limits
    // Other logic in the system determines what to do based on the values of the control bits and if we're outside limits

    // We'll store the 12-bit adder output here
    logic [11:0] MMU_adder_out;
    // This is the "access check" signal that's hooked to carry and fires if we're outside the page limits
    (* MARK_DEBUG = "TRUE" *) logic ACCK;
    // This is a flag that gets set if the current seg is a stack seg
    // It causes the carry in of the low adder to be set, causing the seg to grow down not up if it's a stack seg
    logic stk_flag;
    // Assert the flag if this is a stack segment and we're in the SLR; _STK means something completely unrelated if we're in the SOR
    assign stk_flag = !_STK & !B_L;
    // Take the low 8 bits of the SOR output and sum with UA9-16, plus the stk_flag if set, forming unlatched phys addr A9-A16
    // If we're instead set to the SLR, then the output is meaningless and we only care about carry, which gets put in ACCK
    assign {ACCK, MMU_adder_out[7:0]} = TD[7:0] + UA[16:9] + stk_flag;
    // Now take the high 4 bits of the SOR output and add the carry bit, forming unlatched phys addr A17-A20
    // If we're in the SLR where the high 4 bits are control flags, then this entire operation is completely meaningless
    assign MMU_adder_out[11:8] = TD[11:8] + ACCK;

    // Now we need to latch the adder output from the SOR phase so it can be put on the addr bus and doesn't get scrambled by the SLR phase
    logic [20:9] latched_MMU_address;
    // There are also latched "I/O address" signals that are clones of the standard A13-16 but are latched under different conditions
    logic [16:13] IOA;

    // First, do the LS373 that latches A13-A20
    // Level sensitive, not edge sensitive
    assign latched_MMU_address[20:13] = !_MALE ? MMU_adder_out[11:4] : latched_MMU_address[20:13];
    /*always_ff @(negedge _MALE) begin
        // We latch on an asserted _MALE (mem addr latch enable), retain current output state otherwise
        if (!_MALE) begin
            latched_MMU_address[20:13] <= MMU_adder_out[11:4];
        end
    end*/

    // Now do the LS374 that latches A9-A12 and the IOA signals
    // Edge sensitive, not level sensitive
    logic [16:13] IOA_int;
    always_ff @(posedge _MALE) begin
        latched_MMU_address[12:9] <= MMU_adder_out[3:0];
        IOA_int <= MMU_adder_out[7:4];
    end

    // Finally, put the latched address (which can tri-state itself if the latches aren't enabled) on the address bus
    assign A[20:13] = (_BGACK & ~_CMUX) ? latched_MMU_address[20:13] : 8'bz;
    assign A[12:9] = _BGACK ? latched_MMU_address[12:9] : 4'bz;

    // And same for the I/O address
    assign IOA = _BGACK ? IOA_int : 4'bz;

    // A couple more memory-related things: first, the video address latch
    // This latch holds A15-A20 (the video page address), and is constantly output to the RAM during vid cycles
    // The vid logic just iterates thru all the lower addr bits and these stay constant
    // Changing the addr in this latch lets you move the 32K screen page anywhere in memory
    // It also has an LED hooked to it that blinks during ROM diagnostics
    // _VAL is the latch signal for the vid addr latch
    (* MARK_DEBUG = "TRUE" *) logic _VAL;
    logic [7:0] VAL_output;
    always_ff @(negedge _VAL, negedge _RSTHLT_555) begin
        if (!_RSTHLT_555) begin
            // Clear it if we're in reset, just to make sure that it's in a known state instead of XXXXX
            VAL_output <= 8'b0;
        end else begin
            // Put the video address in the top part of the output, then a 0, and then the LED value
            VAL_output <= {UD_CPU_out[5:0], 1'b0, UD_CPU_out[7]};
        end
    end

    // Put the latched video address on the addr bus if CMUX is deasserted (meaning we're in a video cycle), else high-z
    assign A[20:15] = ~_CMUX ? 6'bz : VAL_output[7:2];
    // Same for the LED; only drive it if we're in a vid cycle
    assign VAL_LED = ~_CMUX ? 1'bz : VAL_output[0];

    // Final memory thing: the RAM address mux
    // RAM can be addressed by either the regular (MMU-generated) address bus or the video address bus, it's picked by a mux
    // And not only that, but we have 8 RAM address (RA) lines but 16 addr lines to fit on them
    // So we have to mux that too, meaning we need a 4-to-1 mux for each RA line
    // This is the video address; we already have the regular address in plain old A
    (* MARK_DEBUG = "TRUE" *) logic [14:1] VA;
    // The mux is flipped through its 4 possible states based on RAS and _CMUX
    // RAS determines whether we put the low or high part of the addr on our 8 addr lines
    // And _CMUX determines whether we put on a vid addr or a regular addr
    always_comb begin
        case ({!_RAS, _CMUX})
            // RAS is deasserted and _CMUX is asserted, so put out the low part of a regular address
            2'b00: RA = A[8:1];
            // RAS is deasserted, but now _CMUX is deasserted, so put out the low part of a video address
            2'b01: RA = VA[8:1];
            // RAS is now asserted and so is _CMUX, so put out the high part of a regular address
            2'b10: RA = A[16:9];
            // RAS is asserted and now _CMUX is deasserted, so put out the high part of a video address
            // The video address only goes up to bit 14, so fill the remaining two bits with A15 and A16 from the VAL
            2'b11: RA = {A[16], A[15], VA[14:9]};
        endcase
    end

    // Now that we're done with memory stuff, let's move onto the system timing circuits
    // First, we need to divide the master clock (DOTCK) down with a counter
    // DOTCK is 20.37504MHz in the stock Lisa
    (* MARK_DEBUG = "TRUE" *) logic [3:0] Q_counter;
    (* MARK_DEBUG = "TRUE" *) logic _VT7;
    // Clock the counter on DOTCK
    always_ff @(posedge DOTCK, posedge fast_reset) begin
        // If the system gets reset, put the counter in a known state (outputs 0, carry out deasserted)
        if (fast_reset) begin
            Q_counter <= 4'b1000;
            _VT7 <= 1'b1;
        // Otherwise...
        end else begin
            // If we're about to hit 15, then pull the carry out low (asserted), else keep it high
            if (Q_counter == 4'b1110) begin
                _VT7 <= 1'b0;
            end else begin
                _VT7 <= 1'b1;
            end
            // Increment the counter/output on each clock
            Q_counter <= Q_counter + 4'b1;
        end
    end
    
    // Now we need to derive PCK and CPUCK from the counter outputs
    // They're both just DOTCK / 4, so about 5MHz
    assign PCK = Q_counter[1];
    assign CPUCK = Q_counter[1];
    
    // The VIDEO signal (which is asserted during the video half of a cycle) is just the MSB of the counter output
    // This makes sense b/c it'll be asserted for half the count and deasserted for the other half
    assign VIDEO = Q_counter[3];

    // Now decode the counter output into the Lisa's 7 timing states: _T0-_T7
    decoder_3to8 clock_decoder(
    // Take the counter output
    .ABC(Q_counter[2:0]),
    // Always stay enabled
    ._G2A(1'b0),
    ._G2B(1'b0),
    .G1(1'b1),
    // And output our 8 timing states
    ._Y(_T)
    );

    // Now do RAM refresh decoding; we refresh slot 1 when CMUX is asserted 
    // Refresh slot 1 when either _CMUX is deasserted or (VA8 or VA11 is asserted, but not both)
    // Refresh slot 2 when _CMUX is deasserted and either (both VA8 or VA11 are asserted or deasserted)
    assign _R1 = _CMUX | (VA[8] ^ VA[11]);
    assign _R2 = _CMUX & (VA[8] ~^ VA[11]);

    // Time for the absolute spaghetti of the main timing signal generator circuit

    // First up is the _BERR flip-flop, which gets asserted in the event of a bus error
    // It gets deasserted on the next cycle when AS gets pulsed
    logic BERR_unlatched;
    // So the input to the BERR latch is true if we're not in an I/O cycle, not in a special I/O cycle, CAS isn't asserted, we're in a CPU cycle, and in timing state T3
    assign BERR_unlatched = ~(~_IOCY | ~_CAS | _T[3] | ~CPUC1 | ~_SPIO);
    // And now we need to actually implement the _BERR flip-flop
    // The K input is permanently deasserted, so we just have J (_BERR_unlatched), preset (_BUST), and clear (AS)
    (* MARK_DEBUG = "TRUE" *) logic _BERR;
    always_ff @(posedge DOTCK, negedge _BUST, posedge _AS) begin
        // If we get a bus error indicated by _BUST, then preset the flop
        if (!_BUST) begin
            _BERR <= 1'b0;
        end else if (_AS) begin
            // If AS is deasserted, then clear the flop
            _BERR <= 1'b1;
        end else begin
            // Otherwise, set the flop if _BERR_unlatched is asserted, else leave it alone
            if (BERR_unlatched) begin
                _BERR <= 1'b0;
            end
        end
    end

    // Now the RAS flip-flop
    // We assert _RAS at T0 and deassert it at T5, but it can also be inhibitied if neither VIDEO nor CPUC1 are asserted
    // This would mean that we're in between CPU and video cycles, so we don't want to assert RAS
    logic _RAS_inhibit;
    assign _RAS_inhibit = VIDEO | CPUC1;
    always_ff @(posedge DOTCK, negedge _RAS_inhibit) begin
        // If RAS is inhibited, deassert it right away (async clear)
        if (!_RAS_inhibit) begin
            _RAS <= 1'b1;
        end else begin
            // Otherwise, assert it at T0 and deassert it at T5
            if (!_T[0]) begin
                _RAS <= 1'b0;
            end else if (!_T[5]) begin
                _RAS <= 1'b1;
            end
        end
    end

    // Now onto the SPIO flip-flop
    // This one gets asserted whenever we're performing a special I/O cycle (ROM or MMU register access)
    // As opposed to a regular I/O operation or RAM operation
    // And then it gets deasserted via async clear when AS is pulsed (the start of the next cycle)
    logic SPIO_unlatched;
    // We're going to need a signal called MCY for this one
    // It's asserted when the page we're accessing is memory according to the MMU, and we're in the CPU part of the cycle, not video
    (* MARK_DEBUG = "TRUE" *) logic MCY;
    assign MCY = ~_MEM & CPUC1;
    // We set the SPIO latch if BGACK says we're the bus master, this isn't a memory cycle, the stuff we're trying to access isn't read-only, we're in a CPU cycle not a video cycle, and we're in timing state T2
    assign SPIO_unlatched = ~(~_BGACK | MCY | ~_RO | ~CPUC1 | _T[2]);
    always_ff @(posedge DOTCK, posedge _AS) begin
        // If AS is pulsed, then clear the SPIO latch (async clear)
        if (_AS) begin
            _SPIO <= 1'b1;
        end else begin
            // Otherwise, set the SPIO latch if SPIO_unlatched is asserted, else leave it alone
            if (SPIO_unlatched) begin
                _SPIO <= 1'b0;
            end
        end
    end

    // Next up is the CAS flip-flop
    // This one gets asserted at T2 and deasserted at T6, so just lagging slightly behind RAS as we'd expect
    // But the set of inhibit conditions is a lot more complex than those for RAS
    // This is because RAS only gets inhibited when we know from the start that we don't want to do a memory cycle
    // But CAS's inhibit conditions come from the MMU (whether the seg is actually mem or just I/O, if we're outside limits, etc)
    // And the MMU takes a while to do its thing, so we have to save all these conditions for CAS instead of doing them immediately on RAS
    logic _full_CAS_inhibit;
    // We'll do the MMU conditions separately and then combine them with the non-MMU conditions to form the full inhibit signal
    logic MMU_CAS_inhibit;
    // The MMU will inhibit CAS if the seg is marked as read-only but we're trying to do a write,
    // Or if the cycle is not a memory cycle (MCY is low), or if we're outside the segment limits (ACCK is asserted)
    // That last condition isn't just ACCK though; if we're in a stack seg (_STK is low), then it inverts the meaning of ACCK
    // So we actually have to XOR ACCK with _STK to get the proper inhibit condition
    assign MMU_CAS_inhibit = (~_RO & ~READ) | ~MCY | ~(ACCK ^ _STK);
    // Now combine the MMU conditions with the non-MMU ones to form the full inhibit signal
    // Basically, we can only inhibit cas if the MMU says to, but we're also not in a video cycle
    // And not if something else is the master and currently controls the bus
    assign _full_CAS_inhibit = ~(MMU_CAS_inhibit & ~VIDEO & ~(~_BGACK & CPUC1));
    // Now the flip-flop itself
    always_ff @(posedge DOTCK, negedge _full_CAS_inhibit) begin
        // If CAS is inhibited, deassert it right away (async clear)
        if (!_full_CAS_inhibit) begin
            _CAS <= 1'b1;
        end else begin
            // Otherwise, assert it at T2 and deassert it at T6
            if (!_T[2]) begin
                _CAS <= 1'b0;
            end else if (!_T[6]) begin
                _CAS <= 1'b1;
            end
        end
    end

    // Now we do the _IOCY flip-flop
    // This one gets set if we're in an I/O cycle (not memory or special I/O)
    // And async cleared when AS is pulsed (the start of the next cycle)
    logic IOCY_unlatched;
    // We set the latch if _BGACK says we're the bus master, we're in timing state T2, the MMU says the page is within limits,
    // The MMU says page is marked as I/O, and we're in the CPU part of the cycle, not video
    // Note that we just look at ACCK here instead of XORing with _STK like we did for CAS because it's impossible to have an I/O stack seg
    assign IOCY_unlatched = ~(~_BGACK | _T[2] | ACCK | _IO | ~CPUC1);
    // Now the flop itself
    always_ff @(posedge DOTCK, posedge _AS) begin
        // If AS is pulsed, then clear the IOCY latch (async clear)
        if (_AS) begin
            _IOCY <= 1'b1;
        end else begin
            // Otherwise, set the IOCY latch if IOCY_unlatched is asserted, else leave it alone
            if (IOCY_unlatched) begin
                _IOCY <= 1'b0;
            end
        end
    end

    // Next up, we've got the CPUC1 flip-flop
    // Don't worry, only two more after this
    // It gets set by some combinational stuff that we'll do in a second
    // But unlike many of the other flops, it doesn't get cleared by AS
    // Instead, it gets synchronously cleared when VIDEO is asserted (the start of a video cycle)
    logic CPUC1_unlatched;
    // We set the latch if there's no bus error, _AS is asserted (start of CPU cycle), _VT7 is asserted (end of video cycle), 
    // IAK is not asserted (we're not doing an interrupt acknowledge), and we're not in an I/O cycle
    assign CPUC1_unlatched = ~(~_BERR | _AS | _VT7 | IAK | ~_IOCY);
    // Now the flip-flop itself
    always_ff @(posedge DOTCK) begin
        // If both the set and clear conditions are met at the same time, then turn it into a T flip flop
        // This should never actually happen though
        if (CPUC1_unlatched & VIDEO) begin
            CPUC1 <= ~CPUC1;
        end else if (CPUC1_unlatched) begin
            // Otherwise, set the flop if CPUC1_unlatched is asserted
            CPUC1 <= 1'b1;
        end else if (VIDEO) begin
            // And clear it if VIDEO is asserted
            CPUC1 <= 1'b0;
        end
    end

    // Second to last one: the _CMUX flip-flop
    // As with CPUC1, there's no async preset/clear here; just synchronous set and clear
    // CMUX gets set when we're in a video cycle and in timing state T6
    // And it gets cleared whenever we;re in timing state T6 (just period, regardless of VIDEO)
    // So the clear condition will be true in both CPU and video cycles, but the set condition only in video cycles
    // Meaning that the flop will will always be cleared at T6 in a CPU cycle, but will be both set and cleared in a video cycle
    // Which leads to a toggle, but since it always goes into this in the cleared state, it's equivalent to just setting it
    always_ff @(posedge DOTCK) begin
        // If both the set and clear conditions (AKA just the set condition) are met at the same time, then turn it into a T flip flop
        if (!_T[6] & VIDEO) begin
            _CMUX <= ~_CMUX;
        end else if (!_T[6]) begin
            // Otherwise, clear the flop if we're in timing state T6
            _CMUX <= 1'b1;
        end
    end

    // And last but not least: _MALE (the memory address latch enable flip-flop)
    // This one's only inputs are asynchronous preset and synchronous clear
    // We async preset whenever AS is deasserted (the address is on the bus, so it's time to latch it)
    // And we sync clear it when the CPUC1_unlatched conditions are met (basically start of a CPU cycle as long as nothing weird's going on)
    always_ff @(posedge DOTCK, posedge _AS) begin
        // If AS is deasserted, preset the latch (async preset)
        if (_AS) begin
            _MALE <= 1'b0;
        end else if (CPUC1_unlatched) begin
            // Otherwise, if the CPUC1_unlatched conditions are met, clear the latch
            _MALE <= 1'b1;
        end
    end

    // Now that we're done with the timing stuff, let's move onto some misc address decoding and latching stuff
    // First we'll do a decoder that generates selection signals for the I/O board and expansion cards
    // It requires a chip select signal based on IOCY
    logic IOCY_CS;
    always_ff @(posedge DOTCK, posedge _IOCY) begin
        // If IOCY is deasserted, deassert the chip select right away (async clear)s
        if (_IOCY) begin
            IOCY_CS <= 1'b0;
        end else begin
            // Otherwise, assert it when _IOCY gets asserted
            IOCY_CS <= 1'b1;
        end
    end
    // Now we can make the actual decoder
    (* MARK_DEBUG = "TRUE" *) logic _CPU_board_decoder_CS;
    decoder_3to8 IO_select_decoder(
        // Take IOA13-15 as inputs
        .ABC(IOA[15:13]),
        // Enable is based on IOA16 being deasserted, _UAS being asserted, and IOCY_CS being asserted
        ._G2A(_UAS),
        ._G2B(IOA[16]),
        .G1(IOCY_CS),
        // Lower 7 outputs go to the I/O and expansion selects, but the 8th goes to the chip select of our next decoder
        // We'll see that in a minute
        ._Y({_CPU_board_decoder_CS, _INTIO, _SH2, _SL2, _SH1, _SL1, _SH0, _SL0})
    );

    // Now for that next decoder, which generates select signals for some chips on the CPU board
    (* MARK_DEBUG = "TRUE" *) logic sys_ctrl_latch_WE;
    decoder_2to4 CPU_board_decoder_1(
        // It takes A11 and A12 as inputs
        .AB(A[12:11]),
        // And is selected by that CS from the previous decoder
        ._G(_CPU_board_decoder_CS),
        // It outputs the enable signals for the bus error status latch, the memory error address latch, and video addr latch
        // As well as the write enable for the system control register, which we'll implement in a second
        ._Y({_RBES, _RMEA, _VAL, sys_ctrl_latch_WE})
    );
    // The next decoder is for special I/O space
    wire unused1, unused2;
    decoder_2to4 CPU_board_decoder_2(
        // It takes unbuffered address lines 15 and 16
        .AB(UA[16:15]),
        // And only gets selected during a special I/O (MMU/ROM) cycle
        ._G(_SPIO),
        // As you'd expect from this, it outputs select signals for the MMU regs and ROM
        ._Y({unused1, unused2, _MMUIO, _ROM})
    );

    // Before we do the system control register, let's do _DBON, _DTACK, and _CDACK
    // First, _DBON, which enables the data bus; it's asserted as long as we're not in a special I/O cycle and we're the bus master
    assign _DBON = ~(_SPIO & _BGACK);

    // Now for _DTACK and _CDACK, which are a bit more complex
    // _DTACK/_CDACK are related; _CDACK is the CPU board's internal version of _DTACK, and _DTACK comes from expansions and the I/O board
    // So _DTACK is used to form _CDACK, which is then fed to the CPU
    // For the CPU board part of things, _CDACK is generated by a flop that's clocked by CAS
    // It gets synchronously set when VIDEO is low, meaning we're in a CPU cycle
    // This makes sense; we want to ack a memory transfer only during CPU cycles, not video cycles, and after we send the RAM the address
    // The flop is async cleared when AS gets deasserted
    // But it can also be async preset by _DTACK, so that if an expansion or the I/O board acks the cycle, we also ack it internally
    // _DTACK is wire-ANDed with the _Q output of the flop and _CPU_board_decoder_CS; the only things on the CPU board that drive it
    // Why? B/c that way, we also fire _CDACK for non-memory ops that access the latches on the CPU board
    // What about special I/O ops though? Well, the flop output gets ORed with SPIO, so that if we're doing a special I/O op, we also ack it
    (* MARK_DEBUG = "TRUE" *) logic _CDACK;
    logic CDACK_flop;
    /*always_ff @(negedge _CAS, posedge _AS, negedge _DTACK) begin
        // If AS is deasserted, clear the flop (async clear)
        if (_AS) begin
            CDACK_flop <= 1'b0;
        end else begin
            // Otherwise, if VIDEO is low (we're in a CPU cycle) or _DTACK is low, set the flop
            if (!VIDEO | !_DTACK) begin
                CDACK_flop <= 1'b1;
            end
        end
    end*/

    /*always_ff @(posedge DOTCK) begin
        if (_AS) begin
            CDACK_flop <= 1'b0;
        end else if ((!_CAS && !VIDEO) || !_DTACK) begin
            CDACK_flop <= 1'b1;
        end
    end*/

    // It's not quite that simple though; we have to split this logic into two parts since it requires both async and sync set/clear
    // Xilinx FPGAs don't support flops with both async preset and clear, so we have to handle them separately and or the results together
    logic CDACK_core;
    logic DTACK_latch;

    // Flop with async clear (_AS) and clock (_CAS)
    always_ff @(negedge _CAS, posedge _AS) begin
        if (_AS) begin
            CDACK_core <= 1'b0;
        end else begin
            if (!VIDEO) begin
                CDACK_core <= 1'b1;
            end
        end
    end

    // Separate async latch for _DTACK
    always_ff @(negedge _DTACK_in, posedge _AS) begin
        if (_AS) begin
            DTACK_latch <= 1'b0;
        end else begin
            DTACK_latch <= 1'b1;
        end
    end

    // OR them together to form the final flop output
    assign CDACK_flop = CDACK_core | DTACK_latch;


    // Now we can form _CDACK itself by ORing the flop output with SPIO
    assign _CDACK = ~(CDACK_flop | ~_SPIO);
    // Set DTACK if the CPU board decoder is selected or we're ACKing a memory cycle with the flop, else high-z
    // As with VPA, we have to do some muxing on this in the top-level module since multiple boards can drive it
    // So that's what the OE signal is for
    assign _DTACK_out = (_CPU_board_decoder_CS /*| ~CDACK_flop*/) ? 1'bz /*1'b1*/ : 1'b0;
    assign DTACK_OE = ~(_CPU_board_decoder_CS /*| ~CDACK_flop*/);

    // Time for the system control register
    // It's an 8-bit addressable latch that you can write to in order to control various system functions
    (* MARK_DEBUG = "TRUE" *) logic HDER_int;
    (* MARK_DEBUG = "TRUE" *) logic SFER_int;
    addressable_latch_LS259 sys_ctrl_latch(
        // It's addressed by A4-A2
        .A(A[4:2]),
        // And really by A1 too; it's used as the data input
        // If A1 is high, then we set the bit, if it's low then we clear it
        // And given that this latch doesn't care about the state of READ, we can actually write to it by reading from it
        .D(A[1]),
        // The write enable is that signal from the CPU board decoder
        ._G(sys_ctrl_latch_WE),
        // We clear the latch when we halt the system
        ._CLR(_HALT),
        // And its outputs are a lot of familiar signals from earlier
        // Other than the HDER and SFER ones, which are internal versions that we're about to use to form the real HDER/SFER
        .Q({_HDMSK, _VTMSK, _SFMSK, _START, SEG2, SEG1, HDER_int, SFER_int})
    );

    // _SFER gets asserted when SFER_int is asserted, CPUC1 is asserted, and we're doing a write operation
    // _HDER gets asserted when HDER_int is asserted, CPUC1 is asserted, and we're doing a write operation
    // Why the heck is this useful? B/c it lets you intentionally trigger hard and soft memory errors from software
    // Just set the appropriate bit in the sys ctrl reg and do a write operation, and there it is; the ROM diags actually use this
    // And we've got to have an OE for each one too, because the mem boards can drive these signals as well
    // And so we mux them in the top-level module like for DTACK and VPA and BD
    assign _SFER_out = (SFER_int & CPUC1 & ~READ) ? 1'b0 : 1'bz;
    assign SFER_OE = (SFER_int & CPUC1 & ~READ);
    assign _HDER_out = (HDER_int & CPUC1 & ~READ) ? 1'b0 : 1'b1;
    assign HDER_OE = (HDER_int & CPUC1 & ~READ);


    // And one more signal we need to generate: MREAD, which gets asserted whenever CPUC1 is deasserted or we're doing a read operation
    // This signal goes to the memory boards and tells them whether we're doing a read or write operation
    // If CPUC1 is deasserted, then we're in a video cycle and always reading from RAM, so MREAD is asserted
    // And the other READ case should be pretty obvious
    assign MREAD = ~CPUC1 | READ;

    // And now for the last thing on our list: the video circuitry
    // First, we need to make a counter that counts through all the addresses of the video state machine ROM
    logic [7:0] VSROM_address;
    logic VSROM_address_clr;
    always_ff @(negedge VIDEO, posedge VSROM_address_clr, negedge _RSTHLT_555) begin
        // Clear the counter if VSROM_address_clr is asserted
        if (VSROM_address_clr | !_RSTHLT_555) begin
            VSROM_address <= 8'b0;
        end else begin
            // Else increment it on the falling edge of VIDEO (the start of a video cycle)
            VSROM_address <= VSROM_address + 8'b1;
        end
    end

    logic vid_addr_clr;
    logic VSIR_int;
    logic [7:0] VSROM_data;

    // Now we can instantiate an actual VSROM to generate all the video timing signals
    // The address inputs are from our counter, plus VA9 and vid_addr_counter[14], which we'll generate later
    // That bit 14 of the vid addr counter tells the VSROM counter once we've overflowed the low 14 bits of the video address
    // Just like the main ROMs, we need two VSROMs, one for H and one for 3A
    PROM_6309 #(.ROM_file("VSROM_H.mem")) video_state_machine_H(
        .A({vid_addr_counter[14], VA[9], VSROM_address[5:0]}),
        ._E1(CPU_ROM_SEL), // Enable the H VSROM when the H ROM is selected
        ._E2(1'b0),
        // Output into VSROM_data
        .D(VSROM_data)
    );

    PROM_6309 #(.ROM_file("VSROM_3A.mem")) video_state_machine_3A(
        .A({vid_addr_counter[14], VA[9], VSROM_address[5:0]}),
        ._E1(~CPU_ROM_SEL), // And enable the 3A VSROM when the 3A ROM is selected
        ._E2(1'b0),
        // Output into VSROM_data
        .D(VSROM_data)
    );
    
    // Next, we need to latch the VSROM outputs; there are some errors on the original schematics about which VSROM outputs go where
    // But they're obviously hooked up correctly here
    always_ff @(posedge VIDEO) begin
        // This is the clear signal for the VSROM address counter
        VSROM_address_clr <= VSROM_data[0];
        _VSYNC <= VSROM_data[1];
        // Clear signal for the clock for the video address counter; we'll get to it later
        _clr_vid_clk <= VSROM_data[2];
        // Clear signal for the video address counter
        vid_addr_clr <= VA[8] & VSROM_data[3];
        _CSYNC <= VSROM_data[4];
        // Intermediate version of the vertical sync interrupt
        VSIR_int <= VSROM_data[5];
        _HSYNC <= VSROM_data[6];
    end

    // Now make the actual _VSIR signal; it gets asserted when VSIR_int is asserted and VA_overflow (which we haven't made yet) is asserted
    assign _VSIR = ~(VSIR_int & VA_overflow);
    // And make the serial number output; it's just the unlatched VSROM_data[7]
    assign SN = VSROM_data[7];

    // That's the state machine done; now we need the logic that counts through the video addresses and shifts stuff out to the screen
    // First, let's make a flip-flop that clocks the video address counter
    // This flop is clocked by DOTCK and gets async cleared when we're not in a video cycle or when _clr_vid_clk is asserted
    // When the clear conditions aren't met, it's just a D flip flop with _T6 as its input
    (*MARK_DEBUG = "TRUE" *) logic vid_addr_clk;
    always_ff @(posedge DOTCK, negedge VIDEO, negedge _clr_vid_clk) begin
        // If we're not in a video cycle or _clr_vid_clk is asserted, clear the flop (async clear)
        if (!VIDEO | !_clr_vid_clk) begin
            vid_addr_clk <= 1'b1;
        end else begin
            // Otherwise, just make it a D flip flop with _T6 as its input
            vid_addr_clk <= _T[6];
        end
    end

    // Now we can make the actual video address counter
    // It's a 16-bit counter, of which 14 bits are actually used for the video address, and 1 for overflow
    // The counter is clocked by the vid_addr_clk we just made
    // And it gets async cleared when vid_addr_clr and _CMUX are both asserted (meaning the CPU is in control of the bus), not video
    (*MARK_DEBUG = "TRUE" *) logic [15:0] vid_addr_counter;
    logic full_vid_addr_counter_clr;
    assign full_vid_addr_counter_clr = vid_addr_clr & ~_CMUX;
    always_ff @(negedge vid_addr_clk, posedge full_vid_addr_counter_clr, negedge _RSTHLT_555) begin
        // If the clear conditions are met, clear the counter (async clear)
        if (full_vid_addr_counter_clr | !_RSTHLT_555) begin
            vid_addr_counter <= 16'b0;
        end else begin
            // Otherwise, increment the counter on each clock
            vid_addr_counter <= vid_addr_counter + 16'b1;
        end
    end

    // And now we assign the lower 14 bits of the video address counter to VA1-14
    assign VA[14:1] = vid_addr_counter[13:0];
    // And the 15th bit is used to indicate that we've overflowed the low 14 bits
    assign VA_overflow = vid_addr_counter[14];

    // We now have addresses streaming into memory, and we just need to get the video data back and send it to the screen
    // We get each word of data back on MD and put it into a shift register, which then shifts it out to the screen 1 bit at a time
    // The shift register gets loaded by the same vid_addr_clk that clocks the video address counter
    // And it's clocked by DOTCK as you'd expect; this is where the name Dot Clock actually comes from
    // Shifting is inhibited whenever bit 14 of the video address counter goes high, so that we don't shift out garbage when we're outside the visible area
    (*MARK_DEBUG = "TRUE" *) logic [15:0] vid_shift_reg;
    (*MARK_DEBUG = "TRUE" *) logic vid_shift_out;
    always_ff @(posedge DOTCK) begin
        // No matter what, the output bit is always the MSB of the shift register
        vid_shift_out <= vid_shift_reg[15];
        // If we want to load the shift register, then stick MD into it
        if (!vid_addr_clk) begin
            vid_shift_reg <= MD_IN;
        // Otherwise, we want to shift
        end else begin
            // First, make sure we're not being inhbited by bit 14 of the vid addr counter
            if (!vid_addr_counter[14]) begin
                // We shift INVID into the low bit each time; the Lisa Hardware Manual says this was done for debugging or something
                // But it's completely useless in practice; might as well just shift in 0s or 1s
                vid_shift_reg <= {vid_shift_reg[14:0], INVID};
            end
        end
    end

    // The video output from the shift register goes through a D flip-flop; not sure what the purpose of this is, but we'll do it anyway
    logic vid_shift_out_ff;
    always_ff @(posedge DOTCK) begin
        vid_shift_out_ff <= vid_shift_out;
    end

    // And then finally, we produce VID by XORing this video signal with INVID, allowing us to invert the video by setting INVID
    assign VID = vid_shift_out_ff ^ INVID;

    // Oh yeah, we also need to forward a few internal signals to the outside world
    assign VA10B = _BGACK ? VA[10] : 1'bz;
    assign VA9B = _BGACK ? VA[9] : 1'bz;
    assign A16 = A[16];
    assign A17 = A[17];
    assign A18 = A[18];
    assign A19 = A[19];
    assign A20 = A[20];

    // And last but not least, let's instantiate a Motorola 68000 CPU to connect to everything
    // The CPU design isn't mine; it's the FX68K from ijor on Github, and it's supposed to be cycle-accurate to the original
    // There are some annoyances here though

    // This core has something weird going on with the clocks
    // It has to have two phases of the clock fed to it separately: enPhi1 and enPhi2
    // enPhi1 should fall on the rising edge of PCK, and enPhi2 should fall on the falling edge of PCK
    // Both should rise one cycle before they fall
    (* MARK_DEBUG = "TRUE" *) logic enPhi1, enPhi2;
    assign enPhi1 = Q_counter[0] & ~PCK;
    assign enPhi2 = Q_counter[0] & PCK;

    // And then we'll just feed the core DOTCK as its clk input; it's 4x the desired clock speed, but that should be fine
    // Since the actual speed is regulated by enPhi1 and enPhi2 anyway
    fx68k M68K(
        .clk(DOTCK), // in
        .HALTn(_RSTHLT_555), // in
        .extReset(~_RSTHLT_555), // in
        .pwrUp(~_RSTHLT_555), // Not a thing on the actual 68K, but our core needs it; just a copy of RESET
        .enPhi1(enPhi1), // in
        .enPhi2(enPhi2), // in
        .eRWn(UREAD),
        .ASn(_UAS),
        .LDSn(_ULDS),
        .UDSn(_UUDS),
        .E(E),
        .VMAn(_VMA),
        .E_PosClkEn(E_pos_phase), // Neither of these are used on the CPU board, but our 6522 core on the I/O board needs both these phases
        .E_NegClkEn(E_neg_phase),
        .Center_Edge_Pulse(E_either_edge),
        .FC0(FC[0]),
        .FC1(FC[1]),
        .FC2(FC[2]),
        .BGn(_BG),
        .oRESETn(_RSTOUT_CPU),
        .oHALTEDn(_HALTOUT_CPU),
        .DTACKn(_CDACK), // in
        .VPAn(_VPA_in), // in
        .BERRn(_BERR), // in
        .BRn(_BR), // in
        .BGACKn(_BGACK),
        .IPL0n(_IPL[0]), // in
        .IPL1n(_IPL[1]), // in
        .IPL2n(_IPL[2]), // in
        .iEdb(UD_CPU_in), // in
        .oEdb(UD_CPU_out),
        .eab(UA_CPU)
    );

endmodule
