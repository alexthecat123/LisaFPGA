`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 09/23/2025 03:31:58 PM
// Design Name: The Apple Lisa I/O Board
// Module Name: IO_board
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

module IO_board(
    output logic [3:0] PH,
    output logic WRD,
    output logic _WRQ,
    input logic RDA,
    output logic _DR1,
    output logic _DR0,
    output logic HDS,
    input logic SNS,
    output logic MT1,
    output logic MT0,
    input logic _IRQ, // not connected to anything, from the floppy drives
    output logic _RSIR,
    output logic _KBIR,
    output logic _IOIR,
    input logic E,
    input logic _RESET_SYSTEM,
    input logic CPUCK,
    input logic _LDMA,
    input logic _BGACK, // also not connected to anything
    input logic _BR, // also not connected to anything
    output logic _BG0,
    input logic _BG,
    input logic [15:0] BD_in,
    output logic [15:0] BD_out,
    output logic BD_OE,
    input wire [12:1] A,
    input logic _VMA,
    input logic _VPA_in,
    output logic _VPA_out,
    output logic VPA_OE,
    input logic _DTACK_in,
    (* MARK_DEBUG = "TRUE" *) output logic _DTACK_out,
    (* MARK_DEBUG = "TRUE" *) output logic DTACK_OE,
    input logic _AS,
    input logic READ,
    input logic _LDS,
    input logic _UDS,
    input logic _INTIO,
    (* MARK_DEBUG = "TRUE" *) input logic OCD,
    (* MARK_DEBUG = "TRUE" *) input logic [7:0] PD_in,
    (* MARK_DEBUG = "TRUE" *) output logic [7:0] PD_out,
    (* MARK_DEBUG = "TRUE" *) output logic _ProFile_EN,
    (* MARK_DEBUG = "TRUE" *) output logic PR_W_ungated,
    (* MARK_DEBUG = "TRUE" *) input logic _PARITY,
    (* MARK_DEBUG = "TRUE" *) output logic _PSTRB,
    (* MARK_DEBUG = "TRUE" *) output logic DR_W,
    (* MARK_DEBUG = "TRUE" *) input logic _BSY,
    (* MARK_DEBUG = "TRUE" *) output logic _CMD,
    // input logic BAT, // no battery on an FPGA
    //input logic SPKRIN,
    (* MARK_DEBUG = "TRUE" *) output logic TONE,
    output logic [5:0] CONT, // 1 analog signal on original; here we pipe out the full 6 bit digital value
    input logic KBD_in,
    output logic KBD_out,
    input logic [6:0] M,

    // Serial signals not currently implemented
    input logic SYNCA,
    output logic TXDA,
    output logic RTSA,
    output logic DTRA,
    input logic RXDA,
    input logic CTSA,
    input logic DCDA,
    output logic TRXCA,
    input logic RTXCA,
    output logic TXDB,
    output logic DTRB,
    output logic RTSB,
    input logic RXDB,
    input logic CTSB_TRXCB,

    input logic _CRES_in,
    output logic _CRES_out,
    output logic _NMI,
    output logic NMI_OE,
    (* MARK_DEBUG = "TRUE" *) input logic _PWRSW,
    output logic ON,

    // These clocks are normally generated on the I/O board in a real Lisa, but we gen them in the top-level module with an MMCM
    input logic sysclk, // 125MHz FPGA system clock
    input logic C16M, // 16MHz clock
    input logic COPCK, // 3.9MHz clock for the COP421
    input logic SCCCK, // 3.68MHz clock for the 8530 SCC
    (* MARK_DEBUG = "TRUE" *) input logic E_pos_phase, // A pulse that goes high for two cycles just after the rising edge of E, used by the 6522 VIA core
    (* MARK_DEBUG = "TRUE" *) input logic E_neg_phase, // Same but for the falling edge of E
    (* MARK_DEBUG = "TRUE" *) input logic E_either_edge, // A pulse that goes high for one cycle just after either edge of E, used by the 6522 VIA core
    output logic [2:0] VC, // 3-bit volume control for the external speaker amp
    
    // All the signals that go to the external SCC
    output logic SCC_C4M,
    output logic SCC_WR,
    output logic SCC_RD,
    input logic _SCC_RSIR,
    output logic SCC_A2,
    output logic SCC_A1,
    output logic _SCC_CS,
    input logic _SCC_PSI,
    output logic [7:0] SCC_DOUT,
    input logic [7:0] SCC_DIN,
    
    input logic IO_ROM_SEL // Selects whether the I/O board uses ROM revision A8 or 40
    );

    // Before we do anything else, let's take the _SYSTEM_RESET signal and turn it into a _RESET signal for the I/O board
    // _SYSTEM_RESET is in the DOTCK clock domain, but we need _RESET to be in the C16M clock domain
    // So we'll use a two-stage synchronizer to avoid metastability issues
    logic _RESET_int, _RESET;
    always_ff @(posedge C16M) begin
        _RESET_int <= _RESET_SYSTEM;
        _RESET <= _RESET_int;
    end

    // Okay, let's get Page 1 out of the way first; it's literally just:
    assign _BG0 = _BG; // This forwards all the bus grants through the I/O board to expansion cards
    // If the I/O board could take control of the bus (which it can't), it might need to do something more complex here
    // And only pass the signal on if it wasn't what was trying to take over the bus

    // Now let's get the hardest page out of the way: Page 4, the floppy controller and its associated hardware
    // First, instantiate a 6504 microprocessor, but there aren't actually any IP cores available for that
    // So we'll use a 6502 core (apparently this one's transistor-accurate) and adapt it a bit since they're basically the same chip
    // This 4-bit signal is the counter that synchronizes all the operations in the floppy controller
    (* MARK_DEBUG = "TRUE" *) logic [3:0] FDC_counter;
    // The R/W line from the 6504
    (* MARK_DEBUG = "TRUE" *) logic RW_FDC;
    // The 6504's address and data buses
    (* MARK_DEBUG = "TRUE" *) logic [15:0] MA;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] FD_in;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] FD_out;

    (* MARK_DEBUG = "TRUE" *)  logic [15:0] MA_unlatched;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] FD_out_unlatched;
    (* MARK_DEBUG = "TRUE" *) logic RW_FDC_latched;
    (* MARK_DEBUG = "TRUE" *) logic _RW_FDC_unlatched;

    cpu FDC_6504(
        .clk(FDC_counter[2]), // PHI0 clock input is FDC_counter[2]
        .reset(~_RESET), // Reset comes from systemwide _RESET
        .AB(MA_unlatched), // This core expects synchronous RAM, so we'll latch the RAM address
        .DI(FD_in), // Data input/output buses
        .DO(FD_out_unlatched), // Latch the output just like the address bus
        .WE(_RW_FDC_unlatched), // Latch the R/W line too
        .IRQ(1'b0), // 6504 actually does have IRQ, but the Lisa ties it high (inactive)
        .NMI(1'b0), // No NMI on a 6504, always inactive
        .RDY(1'b1)  // Also doesn't exist on a 6504, set to always ready
    );

    // The FD_in bus going into the 6504 can be fed by a few different sources
    always_comb begin
        if (!_IOROM_CE) begin
            // If the ROM is selected, then put its data on the bus
            FD_in = ROM_out;
        end else if (!_FDC_RAM_CS_processed) begin
            // If the RAM is selected, then do the same for it
            FD_in = RD_out;
        end else if (!MA[0] && !_state_machine_OE1) begin
            // And finally, put the floppy state machine's shift register output on the bus if it's selected
            FD_in = PSM_out;
        end else begin 
            // If nothing's selected, just pull it high
            FD_in = 8'b11111111;
        end
    end

    // Forward the unlatched address, data, and R/W signals to the latched versions on the rising edge of the PHI2 clock (FDC_counter[2])
    always_ff @(posedge FDC_counter[2]) begin
        MA <= MA_unlatched;
        FD_out <= FD_out_unlatched;
        RW_FDC <= ~_RW_FDC_unlatched;
    end

    // We have to get a bit more creative for the R/W line though
    // The 6504 will leave it asserted for the entire duration of multi-byte writes, but our async RAM can't handle this
    // The RAM will detect this as a single write op and miss the second data byte, so we must deassert it in the middle of multi-byte writes
    // We can do this by simply gating it with FDC_counter[2], which is high for half of the cycle time
    /*always_comb begin
        if (RW_FDC_latched == 1'b0 && FDC_counter[2] == 1'b0) begin
            RW_FDC = 1'b0;
        end else begin
            RW_FDC = 1'b1;
        end
    end*/


    // The 6504 also generates a PHI2 clock output, which we need, but this core doesn't provide it
    // Luckily it's literally just PHI0 with a slight gate delay, so we can probably get away with just using PHI0
    // That's what we'll try, at least

    (*MARK_DEBUG = "TRUE" *) logic [7:0] ROM_out;

    // Now let's instantiate the I/O board ROM and hook it to the 6504
    // We do this twice, once for the A8 ROM once for the 40 ROM, and use the IO_ROM_SEL signal to pick between them
    (* MARK_DEBUG = "TRUE" *) logic _IOROM_CE;
    IOROM_2732 #(.ROM_file("IOROM_A8.mem")) IOROM_A8(
        .A(MA[11:0]),
        ._OE(1'b0), // Always enabled
        ._CE(_IOROM_CE | IO_ROM_SEL), // Use A8 ROM when IO_ROM_SEL is low
        .D(ROM_out)
    );

    IOROM_2732 #(.ROM_file("IOROM_40.mem")) IOROM_40(
        .A(MA[11:0]),
        ._OE(1'b0), // Always enabled
        ._CE(_IOROM_CE | ~IO_ROM_SEL), // Use 40 ROM when IO_ROM_SEL is high
        .D(ROM_out)
    );

    // Let's do the same for the two 444C-3 RAM chips that provide 1K of RAM to the FDC, shared by the 6504 for FDC and the 68K for PRAM
    // Chip select for both chips
    (* MARK_DEBUG = "TRUE" *) logic _FDC_RAM_CS;
    // Address lines for the chips, will be multiplexed between the 6504 and 68K
    (* MARK_DEBUG = "TRUE" *) logic [9:0] RA;
    // R/W line multiplexed between the 6504 and 68K too
    (* MARK_DEBUG = "TRUE" *) logic RW_FDC_RAM;

    // We've got to do some special processing on the chip select signal to get things to work on the actual FPGA
    // IF we just forwarded the select signal from the 6504 or 68K directly to the RAM, we would run into timing issues
    // The address and data lines might not be stable when the RAM sees the falling edge of the chip select signal
    // And this completely breaks the floppy controller obviously
    // So we need to do some synchronization and delay magic here to make sure the RAM gets selected only after everything is stable
    // But there's another edge case to worry about too; what if the 68K interrupted a 6504 access to RAM?
    // Well, in that case, the 6504's clock will get paused for the duration of the 68K access, and will resume (finishing the interrupted cycle) afterwards
    // But since the 68K access changed the RAM address, the RAM will still be outputting the 68K's data when the 6504 cycle resumes
    // And so the 6504 will read the wrong data, causing crazy stuff to happen
    // So we need to make sure that when the 68K stops accessing the RAM, the RAM gets unselected and reselected again so it latches the 6504 address again
    (*MARK_DEBUG = "TRUE" *) logic _FDC_RAM_CS_processed;
    (*MARK_DEBUG = "TRUE" *) logic _FDC_RAM_CS_muxed;
    (*MARK_DEBUG = "TRUE" *) logic FDC_counter_inhibit_flag;
    (*MARK_DEBUG = "TRUE" *) logic FDC_counter_inhibit;

    // First, we use this flip-flop to determine what should be feeding the RAM's chip select; no delay logic yet
    always_ff @(posedge C16M) begin
        // If the 68K is trying to access the RAM, then keep the select low for as long as it's selecting it
        if (~FDC_RAM_addr_select) begin
            _FDC_RAM_CS_muxed = 1'b0;
        // If the 68K just stopped accessing the RAM, then unselect it for one sysclk cycle to allow a falling edge again
        // If we don't do this, then CS will just stay low when the 6504 regains control and tries to access RAM itself
        // And since the 6504 is trying to access a different address, the RAM needs to see a falling edge on CS again to latch the new address
        end else if (~FDC_RAM_addr_select_prev && FDC_RAM_addr_select) begin
            _FDC_RAM_CS_muxed = 1'b1;
        // Otherwise, just forward the 6504's chip select signal directly to the RAM
        end else begin
            _FDC_RAM_CS_muxed = _FDC_RAM_CS;
        end
    end

    // This handles the setting and clearing of the counter inhibit flag that we use to pause the 6504 clock
    // The flag only lasts for one sysclk cycle here, but we'll stretch it out in the next always_ff block
    always_ff @(posedge C16M) begin
        // If we're at the end of a 68K access to the RAM (rising edge of FDC_RAM_addr_select), then set the flag
        // Also set it during end of the access (when DTACK is asserted), so that there's not a quick toggle of this signal
        if ((~FDC_RAM_addr_select_prev && FDC_RAM_addr_select) | !_DTACK_ungated) begin
            FDC_counter_inhibit_flag <= 1'b1;
        end else begin
            // Otherwise, clear it
            FDC_counter_inhibit_flag <= 1'b0;
        end
    end

    logic [3:0] FDC_inhibit_delay;
    // Here's that next always_ff block I was talking about
    // We need the inhibit to be active a bit longer so we have time to set and clear the CS strobe of the RAM before the 6504 clock resumes
    // So we'll latch it whenever the flag goes high, and then hold it for a few sysclk cycles afterwards before releasing it again
    // The RAM CS signal is registered on sysclk/2, so 16 sysclk cycles here should be plenty of time
    always_ff @(posedge C16M, negedge _RESET) begin
        if (!_RESET) begin
            FDC_inhibit_delay <= 4'b0000;
            FDC_counter_inhibit <= 1'b0;
        end else if (FDC_counter_inhibit_flag) begin
            FDC_inhibit_delay <= 4'b1111;
            FDC_counter_inhibit <= 1'b1;
        end else if (FDC_inhibit_delay != 4'b0000) begin
            FDC_inhibit_delay <= FDC_inhibit_delay - 1;
            FDC_counter_inhibit <= 1'b1;
        end else if (FDC_inhibit_delay == 4'b0000) begin
            FDC_counter_inhibit <= 1'b0;
        end
    end

    /*logic sysclk_counter;
    logic sysclk_divided;

    always_ff @(posedge sysclk, negedge _RESET) begin
        if (!_RESET) begin
            sysclk_counter <= 1'b0;
            sysclk_divided <= 1'b0;
        end else begin
            sysclk_counter <= sysclk_counter + 1;
            if (sysclk_counter == 1'b1) begin
                sysclk_divided <= ~sysclk_divided;
            end
        end
    end*/

    // So that all handles determining what gets forwarded to the RAM, but we still need to delay it to account for the setup time of the address and data lines
    // We do this by simply registering the signal on the rising edge of the system clock
    // We could probably get away with using the 16MHz clock here, but using the faster sysclk gives us more margin
    always_ff @(posedge C16M) begin
        _FDC_RAM_CS_processed <= _FDC_RAM_CS_muxed;
    end

    // And this little flip-flop here just remembers what the previous state of FDC_RAM_addr_select was for our edge detection logic in the mux
    (*MARK_DEBUG = "TRUE" *) logic FDC_RAM_addr_select_prev;
    always_ff @(posedge C16M) begin
        FDC_RAM_addr_select_prev <= FDC_RAM_addr_select;
    end

    (*MARK_DEBUG = "TRUE" *) logic [7:0] RD_out;

    IO_RAM_444C_3 low_FDC_RAM(
        .A(RA),
        ._CS(_FDC_RAM_CS_processed),
        .R_W(RW_FDC_RAM),
        .D_in(RD_in[3:0]), // We'll talk about this in a second
        .D_out(RD_out[3:0])
    );

    IO_RAM_444C_3 high_FDC_RAM(
        .A(RA),
        ._CS(_FDC_RAM_CS_processed),
        .R_W(RW_FDC_RAM),
        .D_in(RD_in[7:4]), // Same here
        .D_out(RD_out[7:4])
    );

    // As I said, the RAM is shared with the 68K, so let's make its contents available to the 68K on the systemwide BD bus
    // If the 68K is reading from the RAM, then put its contents on BD, else set BD to high-z so other stuff can use it
    (* MARK_DEBUG = "TRUE" *) logic FDC_RAM_addr_select;
    // As with some other signals, BD can be driven by multiple modules (I/O, CPU, and expansion cards), so we have to mux it in top.sv
    // So we have to make BD_out and BD_OE signals here that go to top.sv
    // We use a tri-state OE internally to make it easier to set the OE everywhere, and then we forward it to the standard logic output
    // We'll drive BD_out later when we drive it from IO_D as well
    tri0 BD_OE_int;
    assign BD_OE = BD_OE_int;
    assign BD_OE_int = (~FDC_RAM_addr_select && READ) ? 1'b1 : 1'bz;

    // Thanks to a lack of tri-state logic, we have to do some multiplexing on the RAM, which is what RD_in is for
    (* MARK_DEBUG = "TRUE" *) logic [7:0] RD_in;
    // When low, the RAM is being accessed by the 68K and its contents should be put on the BD bus
    // When we're accessing the RAM from the 68K, put the 68K's data on the RAM's input lines, else put the 6504's data on it
    assign RD_in = (~FDC_RAM_addr_select) ? BD_in[7:0] : FD_out;

    // What addresses the RAM with the RA lines depends on whether the 68K or 6504 is accessing it
    // If the 68K is accessing it, then RA comes from A[10:1], else it comes from the 6504-generated MA[9:0]
    assign RA = (~FDC_RAM_addr_select) ? A[10:1] : MA[9:0];
    // Wow, that one line of code replaced three whole LS157 multiplexers on the original board

    // Before we get down to the middle part of the schematic with all the flip-flops and stuff, let's do the PROM state machine
    // It consists of a 6309 PROM just like the VSROM and an LS323 shift register, as well as an LS174 hex D flip-flop to latch the outputs
    // It's pure magic and basically works the same way as the floppy controller state machine on the Apple ][

    // The state machine's clock
    (* MARK_DEBUG = "TRUE" *) logic state_machine_clk;
    // One of the two OE signals for the state machine LS323; the other comes from MA[0]
    (* MARK_DEBUG = "TRUE" *) logic _state_machine_OE1;
    // This one comes from the output of a 2-to-4 decoder that decodes MA[5:4]
    (* MARK_DEBUG = "TRUE" *) logic [3:0] FDC_address_decoder_1;
    assign _state_machine_OE1 = FDC_address_decoder_1[0];
    // We don't actually use QH for anything, so just tie it to a dummy wire
    (* MARK_DEBUG = "TRUE" *) logic QH_dummy; 
    (*MARK_DEBUG = "TRUE" *) logic [7:0] PSM_out;
    LS323_shiftreg FDC_state_shiftreg(
        .clk(state_machine_clk),
        ._CLR(PROM_data[3]),
        ._OE1(_state_machine_OE1),
        ._OE2(MA[0]),
        .S0(PROM_data[1]),
        .S1(PROM_data[0]),
        .SR(SNS),
        .SL(PROM_data[2]),
        .D(FD_out),
        .Q(PSM_out),
        .QA(PROM_address[1]),
        .QH(QH_dummy)
    );

    // Now let's do the PROM; it's called the "P6A" on the schematics, which is the EXACT SAME PART used in the Apple ][ disk controller
    // Cool, right?

    // Address and data lines for the PROM
    (* MARK_DEBUG = "TRUE" *) logic [7:0] PROM_address;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] PROM_data;

    // Initialize the PROM address to 0 on power-up; just for simulation
    // Otherwise, the address will be X and the PROM will output X, which will propagate through the LS323 and cause everything to break
    initial begin
        PROM_address = 8'b0;
    end

    PROM_6309 #(.ROM_file("P6A.mem")) floppy_state_machine(
        .A(PROM_address),
        ._E1(1'b0), // Permanently enabled
        ._E2(1'b0),
        .D(PROM_data)
    );

    // Now we'll simulate the LS174 hex D flip-flop that latches the PROM outputs
    // As with the PROM and LS323, this is pure magic based on whatever's in that PROM, so I'm not going to try to explain how it works
    // The flip-flops are clocked by the same state machine clock as the LS323

    // Two intermediate signals used to store multiple past states of RDA
    (* MARK_DEBUG = "TRUE" *) logic RDA_int1;
    (* MARK_DEBUG = "TRUE" *) logic RDA_int2;

    // Initialize the RDA intermediate signals to 1 on power-up, just for simulation
    // Just like with the PROM address, this prevents X propagation and everything breaking
    initial begin
        RDA_int1 = 1'b1;
        RDA_int2 = 1'b1;
    end

    // The LS174 itself
    always_ff @(posedge state_machine_clk) begin
        // Latch some of the PROM data outputs back into the PROM address lines
        PROM_address[7] <= PROM_data[7];
        PROM_address[6] <= PROM_data[6];
        PROM_address[5] <= PROM_data[4];
        PROM_address[0] <= PROM_data[5];
        // And store the last two states of RDA into RDA_int1 and RDA_int2
        RDA_int1 <= RDA;
        RDA_int2 <= RDA_int1;
    end

    // Address line 4 of the PROM is generated by a little combinational logic based on the RDA (read data from floppy) line
    // If we're on the rising edge of RDA (RDA just went from low to high), then make PROM_address[4] low
    // In all other cases, make it high
    // Since GCR encoding bases everything on transitions, this edge detector basically converts flux transitions to bits
    assign PROM_address[4] = ~(RDA_int1 & ~RDA_int2);

    // And also, the floppy disk WRD line gets pulled straight off the PROM address line 7, before it goes thru the flip-flop
    assign WRD = PROM_address[7];

    // Now for the two LS259 addressable latches that hold the floppy drive control signals
    // This is pretty simple; they're addressed by MA[3:1] with the data on MA[0] and clocked by lines from a decoder we'll make later
    // One of the latch outputs is an intermediate signal used to form the state machine clock
    (* MARK_DEBUG = "TRUE" *) logic state_machine_clk_int;
    // The latch also outputs HDS, but it's the inverted HDS
    logic _HDS;
    addressable_latch_LS259 upper_FDC_latch(
        .A(MA[3:1]),
        .D(MA[0]),
        ._G(FDC_address_decoder_1[0]),
        ._CLR(_RESET),
        .Q({PROM_address[3], PROM_address[2], state_machine_clk_int, _HDS, PH[3:0]})
    );

    // _WRQ is just the inverted version of PROM_address[3], which was one of the outputs of the upper latch
    assign _WRQ = ~PROM_address[3];

    // Invert _HDS from the latch to get HDS
    assign HDS = ~_HDS;

    // We have to do the same inversion thing for DR0 and DR1, so make intermediate signals for them too
    (* MARK_DEBUG = "TRUE" *) logic DR0;
    (* MARK_DEBUG = "TRUE" *) logic DR1;
    // FDIR (floppy disk interrupt) and DISK_DIAG (set when the FDC is doing diagnostics) are also outputs from the lower latch
    (* MARK_DEBUG = "TRUE" *) logic FDIR;
    (* MARK_DEBUG = "TRUE" *) logic DISK_DIAG;
    // A latch output that's used to lock out CPU board accesses to the FDC RAM when the 6504 is using it
    (* MARK_DEBUG = "TRUE" *) logic DIS;
    // And a dummy bit we won't use
    logic dummy_bit;
    addressable_latch_LS259 lower_FDC_latch(
        .A(MA[3:1]),
        .D(MA[0]),
        ._G(FDC_address_decoder_1[1]),
        ._CLR(_RESET),
        .Q({FDIR, DISK_DIAG, dummy_bit, DIS, MT1, MT0, DR1, DR0})
    );
    
    // Do the inverted assignments for DR0 and DR1
    assign _DR0 = ~DR0;
    assign _DR1 = ~DR1;

    // Now let's do the main timing state machine that generates clocks for much of the FDC circuitry
    // It's a 4-bit binary counter that's fed by the 16MHz clock, and enabled by a combination of its Q1 output and a flip-flop
    // Whenever the Q3 bit goes low, it resets itself back to either 1000 or 1001 depending on the state of another flip-flop
    // The reset is done synchronously with the 16MHz clock
    (* MARK_DEBUG = "TRUE" *) logic FDC_counter_enable;
    (* MARK_DEBUG = "TRUE" *) logic _DTACK_FF_1_output;
    always_ff @(posedge C16M, negedge _RESET) begin
        // The original counter didn't have a reset, but we need one to get a known state on power-up in an FPGA
        if (!_RESET) begin
            FDC_counter <= 4'b0000;
        // If we're not in reset, and Q3 is low, then reset the counter to either 1000 or 1001 depending on the reset value flip-flop
        end else if (!FDC_counter[3]) begin
            FDC_counter <= {3'b100, _DTACK_FF_1_output};
        // Otherwise, as long as the counter is enabled, increment it
        end else if (FDC_counter_enable) begin
            FDC_counter <= FDC_counter + 1;
        end
    end

    // The counter is disabled when Q1 of the counter is high and the output of the secopnd flop-flop is deasserted
    // And also whenever we inhibit the counter to allow the RAM to unselect and reselect when switching between 68K and 6504 access
    // That third condition was added by me though; it's not part of the original design
    // Otherwise, it's enabled
    assign FDC_counter_enable = ((FDC_counter[1] && !FDC_RAM_addr_select) || FDC_counter_inhibit) ? 1'b0 : 1'b1;

    // Now we'll implement oone of the three flip-flops that controls the counter and the creation of _DTACK
    // _DTACK is only generated when the 68K is accessing the FDC, so it'll only be activated when the 68K is talking to us
    // The flip-flop is async preset whenever AS gets deasserted, indicating the end of a bus cycle
    // And it's clocked by the Q0 output of the counter
    // The D input goes low when we're addressing I/O with the _INTIO signal, A12 is low, and DIS is deasserted (the 68K isn't locked out)
    // High otherwise
    // The Q output determines whether the counter gets preset with 1000 or 1001, gets fed to another FF, and controls the OE for _DTACK
    // Setting the counter to 1000 is what happens when the 68K is accessing the FDC, and setting it to 1001 is what happens when it's not
    // So the state machine starts 1 state earlier when the 68K is accessing vs when it's not
    always_ff @(posedge FDC_counter[0], posedge _AS) begin
        if (_AS) begin
            // Async preset on deasserted AS
            _DTACK_FF_1_output <= 1'b1;
        // Otherwise, set or clear based on INTIO, A12, and DIS
        end else begin
            if (!_INTIO && !A[12] && !DIS) begin
                _DTACK_FF_1_output <= 1'b0;
            end else begin
                _DTACK_FF_1_output <= 1'b1;
            end
        end
    end

    // Now we've got a second FF that's hooked up to the output of the first one, also async preset by AS
    // The only difference is that it's clocked by !PHI2 of the 6504 instead of Q0 of the counter
    // I think the purpose of this is to move the "DTACK enable" signal from the 68K's clock domain to the 6504's clock domain
    // Its Q output is used to flip the muxes that choose between the 68K and 6504 for the RAM address lines
    // And the _Q output gets gated with some other stuff to go to a third DTACK generator FF, as well as the RAM W/R line
    (* MARK_DEBUG = "TRUE" *) logic _PHI2;
    // _PHI2 is the inverted version of the 6504's PHI2 clock, which is just FDC_counter[2] in our case
    assign _PHI2 = ~FDC_counter[2];
    always_ff @(posedge _PHI2, posedge _AS) begin
        if (_AS) begin
            // Async preset on deasserted AS, just like before
            FDC_RAM_addr_select <= 1'b1;
        // D input is output of the first flop
        end else begin
            if (_DTACK_FF_1_output) begin
                FDC_RAM_addr_select <= 1'b1;
            end else begin
                FDC_RAM_addr_select <= 1'b0;
            end
        end
    end

    // And now onto the third and final flip-flop, which actually generates (an ungated version of) _DTACK
    // No async preset or clear on this one, just clock and D
    // Clock is the 16MHz clock, and D is goes low when Q1 of the counter is high and the output of the second FF is low, else high
    (* MARK_DEBUG = "TRUE" *) logic _DTACK_ungated;
    always_ff @(posedge C16M) begin
        if (FDC_counter[1] && !FDC_RAM_addr_select) begin
            _DTACK_ungated <= 1'b0;
        end else begin
            _DTACK_ungated <= 1'b1;
        end
    end

    // Now we generate the actual _DTACK; it's _DTACK_ungated if the output from the first FF is low (68K accessing FDC), else high-z
    // As with VPA, we have to do some muxing on this in the top-level module since multiple boards can drive it
    always_comb begin
        if (!_DTACK_FF_1_output) begin
            _DTACK_out = _DTACK_ungated;
            DTACK_OE = 1'b1;
        // The PAUSE output from the (yet to be created) 9512 is one of the things that can assert _DTACK, but only if the 9512 is selected
        // So let's do that now along with the FDC DTACK; if the chip is selected and pause is deasserted, then assert _DTACK
        end else if (!_SEL9512 && _PAUSE_9512) begin
            _DTACK_out = 1'b0;
            DTACK_OE = 1'b1;
        end else begin
            _DTACK_out = 1'b1;
            DTACK_OE = 1'b0;
        end
    end

    // Let's do some random combinational logic for things like chip selection and R/W signals now
    // These are dependent on a lot of the things that we've just generated

    // First, the R/W line for the FDC RAM, which is RW_FDC_RAM
    // This one's pretty complicated; it goes high (read) when either Q1 of the counter is high and the second FF output is low
    // Or when the RAM is being read by the 68K (which is when FDC_RAM_addr_select is high and READ is high)
    // Or when the RAM is being read by the 6504 (which is when FDC_RAM_addr_select is low and RW_FDC is high)
    // In all other cases, it goes low (write)
    assign RW_FDC_RAM = ((FDC_counter[1] && !FDC_RAM_addr_select) & (_PHI2)) | ((FDC_RAM_addr_select) ? RW_FDC : READ);

    // Now onto chip select for the FDC RAM, _FDC_RAM_CS
    // This goes low (enabled) when either the 68K is accessing the RAM (FDC_RAM_addr_select is low)
    // Or when the 6504 has the bus and the output of a yet-to-be-made decoder is asserted by both MA10 and MA12 from the 6504 being low
    (* MARK_DEBUG = "TRUE" *) logic [3:0] FDC_address_decoder_0;
    assign _FDC_RAM_CS = (FDC_RAM_addr_select) ? (FDC_address_decoder_0[0] | FDC_counter[2]) : 1'b0;

    // The I/O board ROM chip select, _IOROM_CE, is asserted (low) whenever the 6504 has the bus (FDC_RAM_addr_select high) and MA12 is high
    assign _IOROM_CE = (FDC_RAM_addr_select & MA[12]) ? 1'b0 : 1'b1;

    // Now let's make the state machine clock, state_machine_clk
    // It's goes high whenever either state_machine_clk_int (the intermediate clock from the LS259) is high
    // Or when Q1 from the counter is high, but not both (XOR)
    assign state_machine_clk = state_machine_clk_int ^ FDC_counter[1];

    // And last but not least for the FDC, the two decoders that generate some control signals
    // The first one is enabled whenever the 6504 has the bus (FDC_RAM_addr_select high), and decodes MA10 and MA12
    decoder_2to4 FDC_address_decoder_low(
        .AB({MA[12], MA[10]}),
        ._G(~FDC_RAM_addr_select),
        ._Y(FDC_address_decoder_0) // The 0 output is one of the two chip selects for the FDC RAM; the 1 output feeds into the second decoder
        // The 2 and 3 outputs are unused
    );

    // The second decodes MA4 and MA5, and is enabled whenever both output 1 of the first decoder is asserted (MA10 high, MA12 low)
    // And when _PHI2 is low too
    decoder_2to4 FDC_address_decoder_high(
        .AB({MA[5], MA[4]}),
        ._G(FDC_address_decoder_0[1] | ~_PHI2),
        ._Y(FDC_address_decoder_1) // The 0 and 1 outputs are used to clock the LS259 latches that hold the floppy drive control signals
        // The 2 and 3 outputs are unused
    );



    // That's it for the FDC, so now let's move onto Page 3, which is the parallel port VIA, 8530 SCC, and 9512 math coprocessor
    // We'll get the 9512 out of the way first; it's just some selection signals and the chip itself
    // But the Lisa never actually supported the 9512, so we'll just make an empty dummy 9512 module that does nothing

    // The read and write signals for the 9512
    logic _9512_RD;
    logic _9512_WR;
    // RD is asserted whenever READ is high and we've selected the 9512 with _SEL9512
    // And as you might guess, WR is asserted whenever READ is low and we've selected the 9512
    logic _SEL9512;
    assign _9512_RD = (!_SEL9512 & READ) ? 1'b0 : 1'b1;
    assign _9512_WR = (!_SEL9512 & !READ) ? 1'b0 : 1'b1;

    // Now let's instantiate our dummy 9512 itself, which just sets all its outputs to their inactive states and not much else
    // We need to define signals for its PAUSE output, END output, and the 2MHz clock input, all of which we'll deal with later
    logic END_9512;
    logic _PAUSE_9512;
    logic C2M;

    // I/O board-wide 8-bit data bus
    (* MARK_DEBUG = "TRUE" *) tri [7:0] IO_D;
    logic [7:0] D_out_9512;

    // Now instantiate our dummy 9512 itself
    AM9512_FPU lisa_FPU(
        .C_D(A[3]), // We choose between the FPU's command and data registers with A3
        ._RD(_9512_RD),
        ._WR(_9512_WR),
        .RESET(~_RESET),
        .CLK(C2M), // Clock it with the 2MHz clock we'll make later
        ._EACK(1'b1), // Tie high like on original board
        ._SVACK(1'b1), // Same here
        ._CS(1'b0), // Lisa always keeps the chip selected
        .D_in(IO_D), // Hook the global I/O board data bus to the FPU data input
        .D_out(D_out_9512),
        .END_9512(END_9512),
        ._PAUSE(_PAUSE_9512)
    );


    // We put the 9512's output on the I/O board data bus whenever it's selected and being read from
    assign IO_D = (~_9512_RD & ~_SEL9512) ? D_out_9512 : 8'bz;

    // Now we'll move onto the 8530 SCC
    // The SCC implementation I found is from the NanoMac project, and it's missing some of the output lines that the Lisa needs
    // But it'll at least get the job done for testing
    // This SCC core requires multiple clock phases, so we need to generate those, but we'll do that later with the other clocks
    logic C4M_en_p;
    logic C4M_en_n;

    // Now we can instantiate the SCC itself, but not before defining a few signals
    // First, the output data bus from the SCC
    logic [7:0] D_out_SCC;
    // Chip select and write enable for the SCC
    (* MARK_DEBUG = "TRUE" *) logic CS_SCC;
    (* MARK_DEBUG = "TRUE" *) logic WE_SCC;
    // We don't use the SCC's WREQ output, so just tie it to a dummy wire
    logic dummy_wreq;

    // The SCC is selected whenever both VMA and AS are asserted
    assign CS_SCC = ~_VMA & ~_AS;

    // A write enable signal for the SCC that we'll generate later
    (* MARK_DEBUG = "TRUE" *) logic _WSIO;
    // We write to the SCC whenever _WSIO is asserted and we're not in reset, or when _WSIO is deasserted and we're in reset
    assign WE_SCC = (~_RESET ^ _WSIO) ? 1'b0 : 1'b1;

    // Only put the SCC's output on the I/O board data bus when it's being selected and read from
    // We use another yet-to-be-made signal, _RSIO, for this, and do the same XOR with reset as before to see if we should be reading
    // In addition to the CS check, of course
    (* MARK_DEBUG = "TRUE" *) logic _RSIO;
    assign IO_D = (~(~_RESET ^ _RSIO) & CS_SCC) ? D_out_SCC : 8'bz;

    logic IOCLK;
    logic _PSI;
    `ifdef SIMULATION
        // In simulation, use the dumb broken NanoMac SCC core
        // It's horrible, but at least it gets us through the self-tests
        logic rxd, txd, cts, rts, dcd_a, dcd_b;
        assign rxd = 1'b1;
        assign cts = 1'b0;
        assign dcd_a = 1'b0;
        assign dcd_b = 1'b0;
        assign _PSI = 1'b1; // Just tie _PSI high for now since the NanoMac SCC doesn't have it
        scc lisa_scc(
            .clk(C16M), // 16MHz "fast" clock input
            .cep(C4M_en_p), // The two clock phases used for the actual timing
            .cen(C4M_en_n),
            .reset_hw(~_RESET), // Systemwide reset
            .cs(CS_SCC), // 
            .we(WE_SCC),
            .rs(A[2:1]), // Register select lines come from A1 and A2; A1 selects serial port A or B, A2 selects data or control
            .wdata(IO_D), // Data input comes from the global I/O board data bus
            .rdata(D_out_SCC),
            ._irq(_RSIR), // IRQ hooks to _RSIR (RS-232 interrupt)
            // And all its serial I/O lines, which ARE DIFFERENT FROM THOSE OF THE ORIGINAL SCC FOR SOME REASON
            // This is the discrepancy between the NanoMac SCC and the real SCC
            .rxd(rxd),
            .txd(txd),
            .cts(cts),
            .rts(rts),
            .dcd_a(dcd_a),
            .dcd_b(dcd_b),
            .wreq(dummy_wreq) // Dummy WREQ that we don't care about
        );
    `else
        // In real life, use a real external SCC until I can develop a better core
        assign SCC_C4M = C4M;
        assign SCC_WR = ~_RESET ^ _WSIO;
        assign SCC_RD = ~_RESET ^ _RSIO;
        assign _RSIR = _SCC_RSIR;
        assign SCC_A2 = A[2];
        assign SCC_A1 = A[1];
        assign _SCC_CS = ~(~_VMA & ~_AS);
        assign _PSI = _SCC_PSI;
        assign SCC_DOUT = IO_D;
        assign D_out_SCC = SCC_DIN;
    `endif

    // Since the SCC isn't implemented internally, just tie off its unused outputs 
    assign TXDA = 1'b1;
    assign RTSA = 1'b1;
    assign DTRA = 1'b1;
    assign TRXCA = 1'b1;
    assign TXDB = 1'b1;
    assign DTRB = 1'b1;
    assign RTSB = 1'b1;


    // Now we can do the parallel port VIA, which is pretty much exclusively dedicated to handling comms with the ProFile
    // We'll be using a 6522 VIA core from the NanoMac project again, but unlike the SCC, this one's full-featured and very accurate

    // First, let's define the ProFile internal data bus (which also happens to go to the contrast latch)
    (* MARK_DEBUG = "TRUE" *) logic [7:0] SD_in;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] SD_out;
    // And now ungated versions of the ProFile control signals
    (* MARK_DEBUG = "TRUE" *) logic _PSTRB_ungated;
    (* MARK_DEBUG = "TRUE" *) logic _CMD_ungated;
    (* MARK_DEBUG = "TRUE" *) logic OCD_ungated;

    // We also need a WCNT signal to write stuff into the contrast latch
    (* MARK_DEBUG = "TRUE" *) logic WCNT;
    // As well as an IRQ from the VIA
    logic _IRQ_PP_VIA;
    logic IRQ_PP_VIA;
    assign _IRQ_PP_VIA = ~IRQ_PP_VIA;
    // We also need two parity signals: one for the parity of the data being sent to the ProFile, and one for the data coming from it
    (* MARK_DEBUG = "TRUE" *) logic parity_out;
    // The input parity is latched so that we can still read it after the drive has changed the data lines
    (* MARK_DEBUG = "TRUE" *) logic latched_parity_in;

    // We also need a selection signal called DSKPT, which we'll generate later
    logic _DSKPT;

    // As well as the VIA's data output lines
    logic [7:0] D_out_PP_VIA;

    // We also need signals for some of the VIA's I/O lines so that we can selectively assign bits to some of these other signals
    logic [7:0] port_b_in_PP_VIA;
    logic [7:0] port_b_out_PP_VIA;

    // And last but not least, a VIA chip select signal, which will active whenever both _DSKPT and VMA are asserted
    (* MARK_DEBUG = "TRUE" *) logic CS_PP_VIA;
    assign CS_PP_VIA = ~_DSKPT & ~_VMA;

    // Oh yeah, one more thing: we need a clock signal that goes high whenever either phase of E goes high
    // This is the .clock() input to the VIA core; it's what all the VIA's internal operations are synchronized to
    // The VIA logic simply checks the pos/neg phase signals to know when to do things; it's not actually clocked off them

    // So make our "IOCLK" high whenever either phase of E goes high, and low otherwise
    assign IOCLK = E_pos_phase | E_neg_phase;

    // And now we can instantiate the VIA with all this information
    via6522 pp_via(
        .clock(E_either_edge), // Clock it with the IOCLK "fast" clock
        .rising(E_pos_phase), // But use the E phase signals for timing
        .falling(E_neg_phase),
        .reset(~_RESET), // Systemwide reset
        .addr(A[6:3]), // RS0-RS3 address lines come from A3 to A6
        .wen(CS_PP_VIA & ~READ), // We write when the chip is selected and READ is low
        .ren(CS_PP_VIA & READ), // We read when the chip is selected and READ is high
        .data_in(IO_D), // Data input comes from the global I/O board data bus
        .data_out(D_out_PP_VIA),
        .port_a_o(SD_out), // Port A is the ProFile data bus
        .port_a_i(SD_in),
        .port_b_o(port_b_out_PP_VIA), // These two composite signals for Port B are about to be broken out into their individual bits
        .port_b_i(port_b_in_PP_VIA),
        .ca1_i(_BSY), // CA1 comes from _BSY, not gated by _ProFile_EN
        .ca2_o(_PSTRB_ungated), // CA2 goes to the ungated version of _PSTRB
        .ca2_i(1'b0), // Make sure the unused CA2 input is tied to a known state
        .cb1_i(END_9512), // CB1 comes from the END output of the 9512
        .cb2_i(latched_parity_in), // CB2 comes from the latched input parity
        .irq(IRQ_PP_VIA) // And of course IRQ goes out to the IRQ signal
    );

    // Only put the VIA's output data on the global I/O board data bus when it's being selected and read from
    assign IO_D = (CS_PP_VIA & READ) ? D_out_PP_VIA : 8'bz;

    // Hook the SD bus to the ProFile bus; the SD input bus should always reflect the ProFile bus
    // So that's PD_in if we're reading from the ProFile, and PD_out if we're writing to it
    assign SD_in = DR_W ? PD_in : PD_out;
    // The SD output bus should only drive the ProFile bus whenever _ProFile_EN is low and we're writing to the ProFile (PR_W low)
    assign PD_out = (~_ProFile_EN & ~DR_W) ? SD_out : 8'b0;

    // Now time to break out the individual bits of Port B
    assign port_b_in_PP_VIA[0] = OCD_ungated; // PB0 is OCD
    assign port_b_in_PP_VIA[1] = _BSY; // PB1 is _BSY, it's not gated by _ProFile_EN
    assign _ProFile_EN = port_b_out_PP_VIA[2]; // PB2 is the ProFile communications enable
    assign PR_W_ungated = port_b_out_PP_VIA[3]; // PB3 is PR_W
    assign _CMD_ungated = port_b_out_PP_VIA[4]; // PB4 is _CMD
    assign port_b_in_PP_VIA[5] = parity_out; // PB5 is the output parity
    assign port_b_in_PP_VIA[6] = DISK_DIAG; // PB6 is DISK_DIAG from the FDC
    assign WCNT = port_b_out_PP_VIA[7]; // PB7 is WCNT
    // Put the unused input bits of Port B into known states
    assign port_b_in_PP_VIA[4:2] = 3'b111;
    assign port_b_in_PP_VIA[7] = 1'b1;

    // Now we need to gate all those ungated ProFile control signals with the ProFile communications enable signal
    assign DR_W = (~_ProFile_EN) ? PR_W_ungated : 1'b1;
    assign _PSTRB = (~_ProFile_EN) ? _PSTRB_ungated : 1'b1;
    assign _CMD = (~_ProFile_EN) ? _CMD_ungated : 1'b1;
    assign OCD_ungated = (~_ProFile_EN) ? OCD : 1'b1;
    //assign _BSY_ungated = (~_ProFile_EN) ? _BSY : 1'b1;

    // Let's also make the _IOIR (I/O interrupt) signal, which gets asserted whenever either the VIA or FDC assert their IRQs
    // On the real board, this is an open-collector wired-OR signal (the CPU board can assert it too), but we have to do it differently here
    // That's because the synthesizer doesn't support multiple drivers on a single signal if the drivers are split between modules
    // So we'll make it a regular binary signal and handle the ORing of it with the CPU board's _IOIR in the CPU board module
    assign _IOIR = (~_IRQ_PP_VIA | FDIR) ? 1'b0 : 1'b1;

    // Time to do some parity stuff now, using our LS280 parity generator/checker modules
    // We hook one to the SD bus, which checks the input parity from the ProFile
    logic parity_ff_input;
    parity_generator_LS280 ProFile_input_parity_checker(
        .ABCDEFGHI({SD_in, _PARITY}),
        .EVEN(parity_ff_input)
    );

    // Its output goes into a flip-flop that latches the parity so we can still read it after the ProFile changes the data lines
    // The FF is clocked by _PSTRB_ungated, and it gets set whenever the EVEN output from the parity checker is high
    // The only thing that can reset it is an asynchronous reset from _PRES
    // So this FF basically stays idle while parities are good (not even), and then locks itself on whenever a parity error occurs
    logic _PRES;
    always_ff @(posedge _PSTRB_ungated, negedge _PRES) begin
        if (!_PRES) begin
            latched_parity_in <= 1'b0;
        end else begin
            if (parity_ff_input) begin
                latched_parity_in <= 1'b1;
            end
        end
    end

    // And another to the PD_out bus, which generates the parity of the outgoing data to the ProFile
    // This one's simpler; no latching or anything, just a straight parity output to PB5 of the VIA
    parity_generator_LS280 ProFile_output_parity_generator(
        .ABCDEFGHI({PD_out, 1'b0}), // The 9th input is tied to 0 to make odd parity
        .EVEN(parity_out)
    );


    // Now onto Page 2, which contains a little bit of address decoding and clock logic, as well as the COP421 and keyboard VIA
    // First, let's generate two clocks, C4M and C2M, by dividing C16M down
    // We only use C2M here (for the 9512) because the SCC (which used C4M in real life) is clocked by those phase signals instead
    // But we'll generate C4M anyway in case we ever do need it
    logic [2:0] clock_divider;
    always_ff @(posedge C16M, negedge _RESET) begin
        if (!_RESET) begin
            // Reset the clock divider to 0 on a system reset
            clock_divider <= 3'b000;
        end else begin
            // Otherwise, increment it on each 16MHz clock cycle
            clock_divider <= clock_divider + 1'b1;
        end
    end

    // Make the enable signals for the two phases of C4M
    assign C4M_en_p = (clock_divider[0] & !C4M);
    assign C4M_en_n = (clock_divider[0] & C4M);
    assign C4M = clock_divider[1]; // C4M is the second bit of the clock divider (divided by 4)
    assign C2M = clock_divider[2]; // C2M is the third bit of the clock divider (divided by 8)

    // Now let's do some address decoding stuff to generate _DSKPT, _SEL9512 _VPA, _RSIO, and _WSIO
    // The (non-FDC portion of the) I/O board is only selected when A12 high and _INTIO is asserted
    // When selected, the particular device is chosen based on A9, A10, and A11
    // When A10 and A11 are both low, and A9 is high, we select the SCC, asserting either _RSIO or _WSIO based on the state of READ
    // When A10 is high and A11 is low, we assert _SEL9512 to select the FPU
    // When A10 is low and A11 is high, we assert _DSKPT to select the parallel port VIA
    // And when A10 and A11 are both high, we assert _CS_KBD_VIA to select the keyboard VIA
    // Selecting the SCC or either of the VIAs also asserts _VPA to tell the 68K that it's a valid peripheral address
    // We'll accomplish all this with two 2-to-4 decoders
    (* MARK_DEBUG = "TRUE" *) logic _CS_KBD_VIA;
    (* MARK_DEBUG = "TRUE" *) logic _CS_SCC_decoder;
    logic dummy_output1, dummy_output2;
    decoder_2to4 IO_board_address_decoder(
        .AB({A[11], A[10]}), // We're decoding A10 and A11 here
        ._G(~(~_INTIO & A[12])), // Decoder only enabled when A12 is high and _INTIO is asserted
        ._Y({_CS_KBD_VIA, _DSKPT, _SEL9512, _CS_SCC_decoder}) // The outputs go to the various chip selects, the LSB enables the SCC decoder
    );
    decoder_2to4 IO_board_SCC_decoder(
        .AB({READ, A[9]}), // This time, decode A9 and READ
        ._G(_CS_SCC_decoder), // Enable whenever the primary decoder selects it
        ._Y({_RSIO, dummy_output1, _WSIO, dummy_output2}) // Feed the outputs to the SCC
    );

    // And don't forget about _VPA!
    // Which we assert whenever either the keyboard VIA, parallel port VIA, or SCC is selected
    // But as with _VPA on the CPU board, we have to do the VPA muxing in the top-level module to avoid multiple drivers on one signal
    // So we do a VPA and a VPA_OE so the mux knows when to drive the signal
    (* MARK_DEBUG = "TRUE" *) assign _VPA_out = (~_CS_KBD_VIA | ~_DSKPT | ~_CS_SCC_decoder) ? 1'b0 : 1'bz;
    (* MARK_DEBUG = "TRUE" *) assign VPA_OE = (~_CS_KBD_VIA | ~_DSKPT | ~_CS_SCC_decoder);

    // Now we'll do the mux that gets keyboard and mouse data from the peripherals to the COP
    // It's a dual 4-to-1 mux, with the select lines coming from the COP, and the data lines coming from the keyboard and mouse
    logic [1:0] KBD_mouse_mux_sel; // A is LSB, B is MSB
    logic [1:0] KBD_mouse_data_out; // X is LSB, Y is MSB

    always_comb begin
        case (KBD_mouse_mux_sel)
            // Send the appropriate two bits from the keyboard/mouse to the COP based on the select lines
            2'b00: KBD_mouse_data_out = {M[6], M[2]}; // Mouse right and left
            2'b01: KBD_mouse_data_out = {M[1], M[4]}; // Mouse down and up
            2'b10: KBD_mouse_data_out = {M[5], M[0]}; // Mouse switch 0 and switch 1
            2'b11: KBD_mouse_data_out = {KBD_in, M[3]}; // Keyboard data and mouse switch 2 (which is apparently hooked to parallel port pin 5?)
        endcase
    end

    // Now we need to make the COP, but first define some signals that connect to it
    // First up, the NMI that it can send to the CPU board
    // It's got to be a wire in order to keep the COP from getting mad during synthesis
    (* MARK_DEBUG = "TRUE" *) wire _NMI_COP;
    // NMI gets asserted when either the COP's NMI output is asserted, or the SCC's (_PSI) is
    assign _NMI = _NMI_COP & _PSI;
    // We have to mux NMI with the NMI from the interrupt switch in top.sv, so we need an OE signal for it too
    assign NMI_OE = ~_NMI_COP | ~_PSI;
    // The reset signal that it can send to the keyboard
    (* MARK_DEBUG = "TRUE" *) logic KBD_reset_COP;
    // Another reset signal that comes from the keyboard VIA
    (* MARK_DEBUG = "TRUE" *) logic _KBD_reset_VIA;
    // The power switch signal that goes to the COP
    // Same deal about being a wire
    (* MARK_DEBUG = "TRUE" *) wire _PWRSW_COP; 
    // And the signals used to communicate between the COP and the keyboard VIA
    // The L bus is a bidirectional 8 bit data bus used to send commands and data between the COP and the VIA
    (* MARK_DEBUG = "TRUE" *) logic [7:0] L_COP_out;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] L_COP_in;
    // The READY signal is driven by the COP over its D3 pin (to VIA pin PB6) to tell the VIA when it's ready to receive a command
    (* MARK_DEBUG = "TRUE" *) logic _READY_COP;
    // This is the SI (shift in) pin on the COP. It's used to acknowledge to the COP that we've read a byte off its L bus
    (* MARK_DEBUG = "TRUE" *) logic READ_ACK_COP;
    // This is the SO (shift out) pin on the COP, which hooks to VIA pin CA1. It gets asserted whenever the COP has data ready for the VIA
    (* MARK_DEBUG = "TRUE" *) logic DATA_QUEUED_COP;


    // The COP _PWRSW line gets asserted whenever the user hits the power switch, or the _RESET line goes low
    // Make sure the RESET condition only works when the system is on though
    // RESET is held asserted all the time while it's off, so otherwise the COP would think the power switch is being held down all the time
    // And since the COP refuses to start up the system until PWRSW is released, the system would never start
    assign _PWRSW_COP = _PWRSW; //& (_RESET | ~ON);

    // The KBD line is bidirectional, and we'll handle the tri-state output pin in top.sv
    // Here, just make an output signal that'll go to the keyboard pin's IOBUF when the COP wants to reset the keyboard
    // The COP or keyboard VIA asserts this low to reset the keyboard, and it goes high-z otherwise
    // Make sure that the VIA's reset is only valid when the reset pin is set as an output (DDRB[0]=1)
    // This prevents the VIA from sending an absurdly-long reset pulse to the keyboard when it's configured for input during system reset
    // We don't need a separate OE signal here; this can double as our OE since the keyboard line is open-collector
    assign KBD_out = ((KBD_reset_COP & KBD_mouse_mux_sel[1]) || (!_KBD_reset_VIA & KBD_via_DDRB[0])) ? 1'b0 : 1'b1;

    logic dummy_COP0, dummy_COP1, dummy_COP2; // Dummy wires for unused COP outputs

    // Instantiate the VHDL model of the COP421
    t420_notri #(
        // 0 = divide by 4
        // 1 = divide by 8
        // 2 = divide by 16
        // 3 = divide by 32
        .opt_ck_div_g(2), // Make sure it divides the clock by 16 (parameter=2) like the original, previously had it set to 1 (divide by 8)
        .opt_type_g(1)
    ) cop421 (
        .ck_i(COPCK), // Clock it from the 3.9MHz COPCK for perfect RTC timing
        .ck_en_i(1'b1), // The clock is always enabled
        .reset_n_i(1'b1), // Other than power-on reset, which is handled internally, we never reset the COP because that would wipe the RTC
        // .cko_i(), // We don't use the clock out pin for anything
        .io_l_i(L_COP_out), // Hook up the bidirectional L bus
        .io_l_o(L_COP_in),
        .io_d_o({_READY_COP, KBD_mouse_mux_sel, ON}), // The D output bus is 4 bits, which we use for READY, the 2-bit mux select, and the ON signal
        .io_g_i({_PWRSW_COP, _NMI_COP, KBD_mouse_data_out[0], KBD_mouse_data_out[1]}), // The G bus is also 4 bits, and we use it to input PWRSW and the two keyboard/mouse data bits
        // The NMI input is unused (it's an output), but things break if we don't hook the corresponding NMI output to the input port
        // I learned this the hard way and spent far more time than I care to admit trying to figure out why the COP wasn't working
        .io_g_o({dummy_COP0, _NMI_COP, dummy_COP1, dummy_COP2}), // The only G output is for NMI, tie the others to dummy wires
        .io_in_i(4'b1111), // The I inputs don't even exist on the COP421, so just tie them to 1
        .si_i(READ_ACK_COP), // SI is an input to the COP from CA2 on the VIA; used to tell the cop when we've read a byte off its bus
        .so_o(DATA_QUEUED_COP), // And the SO output goes to CA1 on the VIA, which is asserted whenever the COP has data ready for the VIA
        .sk_o(KBD_reset_COP) // SK is the keyboard reset output from the COP      
    );

    // Now we'll do the keyboard VIA, which is another 6522 just like the parallel port VIA
    // Like the PP VIA, we need to be able to break out some of the I/O lines on Port B
    logic [7:0] port_b_in_KBD_VIA;
    logic [7:0] port_b_out_KBD_VIA;

    // We also need to create an output bus for the VIA of course
    logic [7:0] D_out_KBD_VIA;

    // We also need a chip select for the VIA
    // We already made the _CS_KBD_VIA signal earlier, but that's only half the picture; VMA also must be asserted
    (* MARK_DEBUG = "TRUE" *) logic CS_KBD_VIA;
    assign CS_KBD_VIA = ~_CS_KBD_VIA & ~_VMA;

    logic KBIR;
    assign _KBIR = ~KBIR;

    logic [7:0] KBD_via_DDRB;

    logic READ_ACK_COP_int;
    logic ca2_oe;
    logic [7:0] L_COP_out_int;

    // And now we instantiate the chip
    via6522 kbd_via(
        .clock(E_either_edge), // Clock it with the IOCLK "fast" clock
        .rising(E_pos_phase), // But use the E phase signals for timing
        .falling(E_neg_phase),
        .reset(~_RESET), // Systemwide reset
        .addr(A[4:1]), // RS0-RS3 address lines come from A1 to A4
        .wen(CS_KBD_VIA & ~READ), // We write when the chip is selected and READ is low
        .ren(CS_KBD_VIA & READ), // We read when the chip is selected and READ is high
        .data_in(IO_D), // Data input comes from the global I/O board data bus
        .data_out(D_out_KBD_VIA),
        .port_a_o(L_COP_out_int), // Port A is the comms bus to the COP
        .port_a_i(L_COP_in),
        .port_a_t(KBD_via_DDRA), // We only want to drive the COP outputs when we're writing to it
        .port_b_o(port_b_out_KBD_VIA),
        .port_b_i(port_b_in_KBD_VIA),
        .port_b_t(KBD_via_DDRB), // We need the DDRB register so we can know when PB0 is an output to drive the keyboard reset line
        .ca1_i(DATA_QUEUED_COP), // CA1 comes from the SO (data queued) output of the COP
        .ca2_o(READ_ACK_COP_int), // CA2 goes to the SI (read acknowledge) input of the COP
        .ca2_t(ca2_oe), // We need to be able to tri-state CA2 so we don't drive the COP's SI line when we're not supposed to
        .ca2_i(1'b0), // Make sure the unused CA2 input is tied to a known state
        .cb1_i(1'b1), // CB1 is pulled up to 5V
        .cb2_o(TONE), // CB2 generates the TONE audio frequency output
        .cb2_i(1'b0), // Make sure the unused CB2 input is tied to a known state
        .irq(KBIR) // The IRQ from this VIA is _KBIR that goes to the CPU board
    );

    // When CA2 is an output, drive the COP's SI line with it, else leave it high
    assign READ_ACK_COP = (ca2_oe) ? READ_ACK_COP_int : 1'b1;

    // Only drive the L bus to the COP when the VIA is set to output on Port A
    // Otherwise set it to all zeros, except the high bit which is pulled up to 5V on the schematic
    assign L_COP_out = (KBD_via_DDRA) ? L_COP_out_int : 8'b10000000;

    // Only put the VIA's output data on the global I/O board data bus when it's being selected and read from
    assign IO_D = (CS_KBD_VIA & READ) ? D_out_KBD_VIA : 8'bz;

    // And oh yeah, we also need to expose that I/O data bus to the BD bus when necessary
    // That happens whenever A12 and _INTIO are both asserted, the direction (BD to IO_D or IO_D to BD) is determined by READ
    // And do BD_out for the FDC as well
    // Once again, BD is muxed in the top-level module, so we need an OE too
    assign BD_OE_int = (A[12] & ~_INTIO & READ) ? 1'b1 : 1'bz;
    assign IO_D = (A[12] & ~_INTIO & ~READ) ? BD_in[7:0] : 8'bz;

    always_comb begin
        if (~FDC_RAM_addr_select && READ) begin
            // Feed BD_out from the FDC RAM when it's selected by the CPU board and we're reading
            BD_out = {8'b0, FD_in};
        end else if (A[12] & ~_INTIO & READ) begin
            // Otherwise, if the rest of the I/O board is selected and we're reading, feed BD_out from the I/O board data bus
            BD_out = {8'b0, IO_D};
        end else begin
            // Else, just set BD to 0
            BD_out = 16'b0;
        end
    end

    // Now we break out the Port B bits
    assign _KBD_reset_VIA = port_b_out_KBD_VIA[0]; // PB0 is _KBD_reset_VIA
    assign VC = port_b_out_KBD_VIA[3:1]; // PB1 to PB3 are the three bits of VC (volume control)
    assign port_b_in_KBD_VIA[4] = FDIR; // PB4 is FDIR from the FDC
    assign port_b_in_KBD_VIA[5] = _PRES; // PB5 is _PRES from the ProFile
    assign port_b_in_KBD_VIA[6] = _READY_COP; // PB6 is _READY from the COP
    // PB7 is one of the things that can drive _CRES, which is asserted when either PB7 is low or _RESET is low
    // The ProFile can also drive _CRES, so we have separate CRES_out and CRES_in lines
    assign _CRES_out = (port_b_out_KBD_VIA[7] & _RESET) ? 1'b1 : 1'b0;
    // Put the other unused bits of Port B into known states
    assign port_b_in_KBD_VIA[0] = 1'b0;
    assign port_b_in_KBD_VIA[1] = 1'b0;
    assign port_b_in_KBD_VIA[2] = 1'b0;
    assign port_b_in_KBD_VIA[3] = 1'b0;
    assign port_b_in_KBD_VIA[7] = 1'b0;

    // And finally, we need to generate _PRES from _CRES
    // This is super easy though; they're literally exactly the same thing, _PRES is just buffered through an extra LS09 AND gate
    // But we don't care about that here, so just tie them together
    assign _PRES = _CRES_out & _CRES_in;

    // Last but not least, Page 5, from which we literally only need to implement one thing: the contrast latch
    // It's just an LS174 hex D flip-flop clocked by WCNT from the parallel port VIA and reset by _RESET
    // The original I/O board also had a DAC to convert the contrast to an analog voltage, but we have to do that externally (or over HDMI)
    always_ff @(posedge WCNT, negedge _RESET) begin
        if (!_RESET) begin
            CONT <= 6'b0; // On reset, set contrast to 0
        end else begin
            CONT <= SD_out[7:2]; // Otherwise, latch bits 2-7 of the SD output from the parallel port VIA into CONT
        end
    end

endmodule