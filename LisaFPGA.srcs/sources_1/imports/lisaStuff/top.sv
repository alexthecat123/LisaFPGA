`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: AlexTheCat123
// 
// Create Date: 08/29/2025 11:38:35 PM
// Design Name: The Apple Lisa - All Inside an FPGA!!!
// Module Name: top
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


module top(
        input logic sysclk,

        output logic _VSYNC,
        output logic _HSYNC,
        output logic VID,
        output logic [5:0] CONT,
        input logic INVID,
        input logic SCANLINES,

        output logic TONE,
        output logic [2:0] VC,

        output logic HDMI_CLK_N,
        output logic HDMI_CLK_P,
        output logic [2:0] HDMI_D_N,
        output logic [2:0] HDMI_D_P,

        output logic _CE_SRAM,
        output logic _OE_SRAM,
        output logic _WE_SRAM,
        output logic _UDS_SRAM,
        output logic _LDS_SRAM,
        output logic [20:1] A_SRAM,
        inout logic [15:0] D_SRAM,

        input logic [1:0] RAM_SEL,

        inout logic [5:0] ESFLOPPY_COMM_BUS,
        input logic RDA_ESFLOPPY,
        output logic WRD_ESFLOPPY,
        input logic SNS_ESFLOPPY,
        output logic _WRQ_ESFLOPPY,
        output logic HDS_ESFLOPPY,
        output logic [3:0] PH_ESFLOPPY,
        output logic MT1_ESFLOPPY,
        output logic MT0_ESFLOPPY,
        output logic _DR1_ESFLOPPY,
        output logic _DR0_ESFLOPPY,
        output logic PWM_ESFLOPPY,

        input logic LEFT_ESFLOPPY,
        input logic OK_ESFLOPPY,
        input logic RIGHT_ESFLOPPY,

        input logic RDA_EXTFLOPPY,
        output logic WRD_EXTFLOPPY,
        input logic SNS_EXTFLOPPY,
        output logic _WRQ_EXTFLOPPY,
        output logic HDS_EXTFLOPPY,
        output logic [3:0] PH_EXTFLOPPY,
        output logic MT1_EXTFLOPPY,
        output logic MT0_EXTFLOPPY,
        output logic _DR1_EXTFLOPPY,
        output logic _DR0_EXTFLOPPY,
        output logic PWM_EXTFLOPPY,

        input logic FLOPPY_SRC,

        inout logic [2:0] ESPROFILE_COMM_BUS,
        output logic _CMD_ESPROFILE,
        input logic _BSY_ESPROFILE,
        output logic R_W_ESPROFILE,
        output logic _STRB_ESPROFILE,
        inout logic _PRES_ESPROFILE,
        input logic _PARITY_ESPROFILE,
        input logic OCD_ESPROFILE,
        inout logic [7:0] PD_ESPROFILE,

        output logic _CMD_EXTPROFILE,
        input logic _BSY_EXTPROFILE,
        output logic R_W_EXTPROFILE,
        output logic _STRB_EXTPROFILE,
        inout logic _PRES_EXTPROFILE,
        input logic _PARITY_EXTPROFILE,
        input logic OCD_EXTPROFILE,
        inout logic [7:0] PD_EXTPROFILE,

        input logic HDD_SRC,

        inout logic KBD_DN,
        inout logic KBD_DP,

        inout logic KBD,

        input logic KBD_SEL,

        inout logic MOUSE_DN,
        inout logic MOUSE_DP,

        input logic [6:0] M_LISA,

        input logic MOUSE_SEL,

        input logic [5:0] GPIO,

        output logic SCC_C4M,
        output logic SCC_WR,
        output logic SCC_RD,
        input logic _SCC_RSIR,
        output logic SCC_A2,
        output logic SCC_A1,
        output logic _SCC_CS,
        input logic _SCC_PSI,
        inout logic [7:0] SCC_D,

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

        output logic INTERNAL_SCC_EN,

        input logic _PWRSW,
        output logic ON,
        input logic _RSTSW,
        output logic _RESET,
        input logic _NMISW,

        input logic [1:0] SPEED_SEL,
        input logic CPU_ROM_SEL,
        input logic IO_ROM_SEL
    );

    // The internal Verilog SCC isn't working yet, so disable the transceivers that hook it to the serial bus
    assign INTERNAL_SCC_EN = 1'b1;
    // Stick something random on the GPIO pins for now
    //assign GPIO = {_VSYNC, _HSYNC, VID, TONE, LEFT_ESFLOPPY, OK_ESFLOPPY};

    logic _SL0;
    logic _SH0;
    logic _SL1;
    logic _SH1;
    logic _SL2;
    logic _SH2;
    tri1 _INT0;
    tri1 _IAK0;
    tri1 _INT1;
    tri1 _IAK1; 
    tri1 _INT2; 
    tri1 _IAK2; 
    tri1 _RSIR; 
    tri1 _KBIR; 
    logic _IOIR; // Original is open-collector, we're making it a regular logic signal instead, so unidirectional now (out of I/O, into CPU)
    logic E;
    logic CPUCK;
    tri1 _LDMA; 
    tri1 _BGACK; 
    tri1 _BR; 
    logic _BG;
    logic [15:0] BD;
    logic [15:0] BD_CPU;
    logic BD_OE_CPU;
    logic [15:0] BD_IO;
    logic BD_OE_IO;
    logic [12:1] A;
    logic _VMA;
    logic _VPA; // Original is open-collector, we're making it a regular logic signal instead that gets muxed here in the top module
    logic _VPA_CPU; // It gets muxed from these
    logic VPA_OE_CPU;
    logic _VPA_IO;
    logic VPA_OE_IO;
    logic _DTACK; // Original is open-collector, we're making it a regular logic signal instead that gets muxed here in the top module
    logic _DTACK_CPU; // It gets muxed from these
    logic DTACK_OE_CPU;
    logic _DTACK_IO;
    logic DTACK_OE_IO;
    tri1 _AS;
    tri1 READ;
    tri1 _LDS;
    tri1 _UDS;
    logic _CSYNC;
    logic _INTIO;
    logic VA10B;
    logic VA9B;
    logic _R1;
    logic _R2;
    tri [15:0] MD;
    logic [15:0] MD_IN;
    logic [15:0] MD_OUT;
    logic [8:1] RA;
    logic A16;
    logic A17;
    logic A18;
    logic A19;
    logic MREAD;
    logic _CAS;
    logic _RAS;
    logic A20;
    logic _HDER; // Original is open-collector, we're making it a regular logic signal instead that gets muxed here in the top module
    logic _HDER_CPU; // It gets muxed from these
    logic HDER_OE_CPU;
    logic _HDER_MEM;
    logic HDER_OE_MEM;
    logic _SFER; // Original is open-collector, we're making it a regular logic signal instead that gets muxed here in the top module
    logic _SFER_CPU; // It gets muxed from these
    logic SFER_OE_CPU;
    logic _SFER_MEM;
    logic SFER_OE_MEM;
    logic VID_int;
    logic _NMI;
    logic VAL_LED;
    logic E_pos_phase;
    logic E_neg_phase;
    logic E_either_edge;

    logic T1, T2, T3;

    assign _BGACK = 1'b1;
    assign _LDMA = 1'b1;
    assign _BR = 1'b1;
    assign _INT0 = 1'b1;
    assign _INT1 = 1'b1;
    assign _INT2 = 1'b1;

    logic DOTCK;
    logic sysclk_ibuf;

    IBUF sysclk_ibuf_buffer (
        .I(sysclk),
        .O(sysclk_ibuf)
    );

    logic COPCK;
    logic SCCCK_ungated;
    logic SCCCK;

    // We need to generate the 20.37504MHz DOTCK from the 125MHz sysclk
    // And the 3.9MHz COPCK, 3.68MHz SCCCK, and 16MHz C16M too
    logic C16M_ungated;
    logic C16M;
    logic COPCK_2x;
    logic SCCCK_2x;
    logic C5M_ungated;
    logic C5M;
    // This is the main Lisa dot clock before we gate it with the power switch; it can be anywhere from 20MHz to 75MHz
    logic DOTCK_ungated;
    // And here's a 12MHz clock for USB
    logic usbclk;

    // We use an MMCM for this, but there's a catch
    // It can't generate either COPCK or SCCCK directly because the frequencies are too low
    // So instead, we generate 2x the frequency of each and divide it by 2 with flip-flops
    // We'll use this MMCM to generate everything but the DOTCK
    clock_divider primary_clock_divider (
        .sysclk(sysclk_ibuf),
        //.lisa_dotck(lisa_dotck_ungated), // dotck_20M
        .C16M(C16M_ungated),
        .COPCK_2x(COPCK_2x),
        .SCCCK_2x(SCCCK_2x),
        .C5M(C5M_ungated),
        .usbclk(usbclk)
    );

    // The DOTCK is a little bit different because we need to be able to select between multiple frequencies for it
    // So we generate all of the possible DOTCK frequencies with a separate MMCM, and then use clock muxing to pick which one we want
    logic dotck_20M;
    logic dotck_40M;
    logic dotck_60M;
    logic dotck_80M;

    // This second MMCM generates all of the dotck frequencies we can select from
    dotck_mmcm dotck_generator (
        .sysclk(sysclk_ibuf),
        .dotck_20M(dotck_20M),
        .dotck_40M(dotck_40M),
        .dotck_60M(dotck_60M),
        .dotck_80M(dotck_80M)
    );

    // Now we need to read the speed select inputs and pick which dot clock to use
    // We have to use special BUFGMUX primitives that are designed for clock muxing; clocks can't be safely routed through regular muxes
    // Each BUFGMUX can only select between two clocks, so we have to do it in multiple stages
    // One for 20 or 40M, one for 60 or 80M, and one for selecting between the two groups

    logic dotck_A, dotck_B;

    // SPEED_SEL is in an unknown clock domain, so let's bring it into the dotck_20M domain before feeding it into the muxes
    // This should help to get rid of any noise from flipping the switches too
    logic [1:0] SPEED_SEL_dotck;
    always_ff @(posedge dotck_20M) begin
        SPEED_SEL_dotck <= SPEED_SEL;
    end

    // Use the first BUFGMUX to select between 20M and 40M
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC") // Synchronous clock switching vs async, doesn't really matter here
    ) dotck_mux_20M40M (
        .I0(dotck_20M), // The two clock inputs
        .I1(dotck_40M),
        .S(~SPEED_SEL_dotck[0]), // Our select line; inverted to match the way the switch is labeled on my PCB
        .O(dotck_A) // The output clock
    );

    // Now do it again for 60M and 80M
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) dotck_mux_60M80M (
        .I0(dotck_60M),
        .I1(dotck_80M),
        .S(~SPEED_SEL_dotck[0]),
        .O(dotck_B)
    );

    // And finally, select between the two groups to get the final DOTCK
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) dotck_final_mux (
        .I0(dotck_A), // 20M/40M group
        .I1(dotck_B), // 60M/80M group
        .S(~SPEED_SEL_dotck[1]), // Select between the two groups, once again inverted to match the PCB switch labeling
        .O(DOTCK_ungated) // Final DOTCK output
    );

    //assign COPCK = rpio_24_r;
    // Here's that division by 2
    always_ff @(posedge COPCK_2x) begin
        // In simulation, we need to give COPCK a defined state on reset
        `ifdef SIMULATION
            if (!_RSTSW) begin
                COPCK <= 1'b0;
            end else begin
                COPCK <= ~COPCK;
            end
        // But in real life, we don't want to do this; the COP should run at all times when powered on
        // And we just use whatever random state it happens to be in on power-up
        `else
            COPCK <= ~COPCK;
        `endif
    end

    always_ff @(posedge SCCCK_2x, negedge _RESET) begin
        if (!_RESET) begin
            SCCCK_ungated <= 1'b0;
        end else begin
            SCCCK_ungated <= ~SCCCK_ungated;
        end
    end

    `ifdef SIMULATION
        // In simulation, we want the Lisa to always be on, so we don't gate the clocks
        assign DOTCK = DOTCK_ungated;
        assign C16M = C16M_ungated;
        assign SCCCK = SCCCK_ungated;
        assign C5M = C5M_ungated;
    `else
        // In real life, we gate the clocks based on the ON signal
        // Use BUFGCE primitives for this; clocks shouldn't be routed through regular muxes
        BUFGCE DOTCK_bufg (
            .I(DOTCK_ungated), // Input clock
            .CE(ON), // Clock enable (1 = pass clock through, 0 = hold low)
            .O(DOTCK) // Output clock
        );
        BUFGCE C16M_bufg (
            .I(C16M_ungated),
            .CE(ON),
            .O(C16M)
        );
        BUFGCE SCCCK_bufg (
            .I(SCCCK_ungated),
            .CE(ON),
            .O(SCCCK)
        );
        BUFGCE C5M_bufg (
            .I(C5M_ungated),
            .CE(ON),
            .O(C5M)
        );
        // This was the old and dumb way of doing things; it's a good thing I stopped doing it like this
        //assign lisa_dotck = (ON) ? lisa_dotck_ungated : 1'b0;
        //assign C16M = (ON) ? C16M_ungated : 1'b0;
        //assign SCCCK = (ON) ? SCCCK_ungated : 1'b0;
        //assign C5M = (ON) ? C5M_ungated : 1'b0;
    `endif

    logic _RSTSW_int;

    // We need to be able to reset when the COP turns the Lisa on too, not just when the reset button is pressed
    // Otherwise, many things will work, but some will be in bad states at power-on
    // Like the 6504 for instance, which will pick up executing code wherever it left off when the Lisa was last powered down
    logic ON_prev;
    logic ON_rising;

    always_ff @(posedge COPCK_2x) begin
        ON_prev <= ON;
        _RSTSW_int <= _RSTSW & ~(ON & ~ON_prev); // Detect the rising edge of ON and use that plus the reset switch to reset the system
    end

    // We need a version of _RSTSW_int synchronized into the DOTCK domain for the CPU board, so do that now
    (* ASYNC_REG = "TRUE" *) logic _RSTSW_dotck_int, _RSTSW_dotck;
    always_ff @(posedge DOTCK_ungated) begin
        _RSTSW_dotck_int <= _RSTSW_int;
        _RSTSW_dotck <= _RSTSW_dotck_int;
    end

    // Note the inversion of _VSYNC and VID here; the LS132 on the motherboard does this
    logic _VSYNC_int;
    assign _VSYNC = ~_VSYNC_int;
    assign VID = ~VID_int;
    // 1 means don't invert, 0 means invert
    // From the CPU board's perspective, a 1 actually inverts the video, but the aforementioned LS132 inverts it back again
    //assign INVID = 1'b1;

    /*assign _RSIR = 1'b1;
    assign _KBIR = 1'b1;
    assign _IOIR = 1'b1;
    assign _VPA = 1'b1;*/

    logic tmds_clock;
    logic [2:0] tmds;

    logic VA_overflow;
    logic _clr_vid_clk;

    `ifndef SIMULATION
        HDMI_Interface lisa_hdmi_output(
            .sysclk(sysclk_ibuf),
            ._reset(_RESET),
            .DOTCK(DOTCK),
            .framerate_sel(GPIO[0]), // 0 for 1080p30, 1 for 1080p60
            .VA_overflow(VA_overflow), // Replaces VSYNC; better reflects the VSYNC time which is actually longer than _VSYNC
            ._clr_vid_clk(_clr_vid_clk), // Replaces _HSYNC; better reflects the HSYNC time which is actually shorter than _HSYNC
            .VID(VID_int),
            .CONT(CONT),
            .TONE(TONE),
            .VC(VC),
            .CPU_ROM_SEL(CPU_ROM_SEL),
            .blank_video(~ON), // When the Lisa is off, we want to blank the video output
            .scanlines(SCANLINES), // When high, put scanlines on the video output to make it look cool
            .tmds_clock(tmds_clock),
            .tmds(tmds)
        );
    `endif

    genvar i;
    generate
        for (i = 0; i < 3; i++)
        begin: obufds_gen
            OBUFDS #(.IOSTANDARD("TMDS_33")) obufds (.I(tmds[i]), .O(HDMI_D_P[i]), .OB(HDMI_D_N[i]));
        end
        OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_clock(.I(tmds_clock), .O(HDMI_CLK_P), .OB(HDMI_CLK_N));
    endgenerate

    CPU_board cpu_board(
        ._SL0(_SL0),
        ._SH0(_SH0),
        ._SL1(_SL1),
        ._SH1(_SH1),
        ._SL2(_SL2),
        ._SH2(_SH2),
        ._INT0(_INT0),
        ._IAK0(_IAK0),
        ._INT1(_INT1),
        ._IAK1(_IAK1),
        ._INT2(_INT2),
        ._IAK2(_IAK2),
        ._RSIR(_RSIR),
        ._KBIR(_KBIR),
        ._IOIR(_IOIR),
        .E(E),
        ._RESET(_RESET),
        .CPUCK(CPUCK),
        ._LDMA(_LDMA),
        ._BGACK(_BGACK),
        ._BR(_BR),
        ._BG(_BG),
        .BD_in(BD),
        .BD_out(BD_CPU),
        .BD_OE(BD_OE_CPU),
        .A_OUT(A),
        ._VMA(_VMA),
        ._VPA_in(_VPA),
        ._VPA_out(_VPA_CPU),
        .VPA_OE(VPA_OE_CPU),
        ._DTACK_in(_DTACK),
        ._DTACK_out(_DTACK_CPU),
        .DTACK_OE(DTACK_OE_CPU),
        ._AS(_AS),
        .READ(READ),
        ._LDS(_LDS),
        ._UDS(_UDS),
        ._CSYNC(_CSYNC),
        ._INTIO(_INTIO),
        .VA10B(VA10B),
        .VA9B(VA9B),
        ._R1(_R1),
        ._R2(_R2),
        .MD_IN(MD_IN),
        .MD_OUT(MD_OUT),
        .RA(RA),
        ._RSTSW(_RSTSW_dotck),
        .A16(A16),
        .A17(A17),
        .A18(A18),
        .A19(A19),
        .DOTCK(DOTCK),
        .MREAD(MREAD),
        ._CAS(_CAS),
        ._RAS(_RAS),
        .A20(A20),
        ._HSYNC(_HSYNC),
        ._HDER_in(_HDER),
        ._HDER_out(_HDER_CPU),
        .HDER_OE(HDER_OE_CPU),
        ._VSYNC(_VSYNC_int),
        ._SFER_in(_SFER),
        ._SFER_out(_SFER_CPU),
        .SFER_OE(SFER_OE_CPU),
        .VID(VID_int),
        ._NMI(_NMI),

        .VAL_LED(VAL_LED),
        .INVID(~INVID),
        .E_pos_phase(E_pos_phase),
        .E_neg_phase(E_neg_phase),
        .E_either_edge(E_either_edge),
        .CPU_ROM_SEL(CPU_ROM_SEL),
        .VA_overflow(VA_overflow),
        ._clr_vid_clk(_clr_vid_clk)
    );

    logic [3:0] PH;
    logic WRD;
    logic _WRQ;
    logic RDA;
    logic _DR1;
    logic _DR0;
    logic HDS;
    logic SNS;
    logic MT1;
    logic MT0;
    logic _IRQ;
    logic _BG0;
    logic OCD;
    logic [7:0] PD_in;
    logic [7:0] PD_out;
    logic _ProFile_EN;
    logic PR_W_ungated;
    logic _PARITY;
    logic _PSTRB;
    logic DR_W;
    logic _BSY;
    logic _CMD;
    //logic SPKRIN;
    logic KBD_in;
    logic KBD_out;
    logic [6:0] M;
    logic _NMI_IO;
    logic NMI_OE_IO;
    logic _CRES_in;
    logic _CRES_out;

    // Here we mux VPA from the CPU board, I/O board, and expansion slots together
    always_comb begin
        // If the CPU board is trying to assert VPA, let it through
        if (VPA_OE_CPU) begin
            _VPA <= _VPA_CPU;
        // Otherwise, if the I/O board is trying to assert VPA, let it through
        end else if (VPA_OE_IO) begin
            _VPA <= _VPA_IO;
        // And otherwise, nothing is trying to drive it, so make sure it's deasserted
        end else begin
            _VPA <= 1'b1;
        end
        // Add more to this mux once we add the expansion slots!
    end

    // Same deal with the DTACK mux
    always_comb begin
        if (DTACK_OE_CPU) begin
            _DTACK <= _DTACK_CPU;
        end else if (DTACK_OE_IO) begin
            _DTACK <= _DTACK_IO;
        end else begin
            _DTACK <= 1'b1;
        end
        // Add more to this mux once we add the expansion slots!
    end

    // And we need one for the buffered data bus (BD) too
    always_comb begin
        if (BD_OE_CPU) begin
            BD <= BD_CPU;
        end else if (BD_OE_IO) begin
            BD <= BD_IO;
        end else begin
            BD <= 16'b0;
        end
        // Add more to this mux once we add the expansion slots!
    end

     // And another mux for NMI, which can be triggered by either the I/O board or the interrupt switch
    always_comb begin
        if (NMI_OE_IO) begin
            _NMI = _NMI_IO;
        end else if (!_NMISW) begin
            _NMI = 1'b0;
        end else begin
            _NMI = 1'b1;
        end
    end

    // And yet another for HDER, which can be triggered by either the CPU board or the memory board
    always_comb begin
        if (HDER_OE_CPU) begin
            _HDER = _HDER_CPU;
        end else if (HDER_OE_MEM) begin
            _HDER = _HDER_MEM;
        end else begin
            _HDER = 1'b1;
        end
    end

    // One more for SFER too, which is the same deal as HDER
    always_comb begin
        if (SFER_OE_CPU) begin
            _SFER = _SFER_CPU;
        end else if (SFER_OE_MEM) begin
            _SFER = _SFER_MEM;
        end else begin
            _SFER = 1'b1;
        end
    end

    assign _INT0 = 1'b1;
    assign _INT1 = 1'b1;
    assign _INT2 = 1'b1;

    assign _IRQ = 1'b1;
    //assign SPKRIN = 1'b0;

    // The floppy drive signals come from either the onboard ESFloppy or an external floppy drive
    // This depends on the FLOPPY_SRC signal, so we need to mux between them

    // Set the ESFloppy comms bus to a random value for now
    assign ESFLOPPY_COMM_BUS = 6'h55;

    // First generate the Sony drive's PWM motor control signal
    // It's derived from MT0, but processed through the Lite Adapter
    // So let's make a Lite adapter to generate it
    logic PWM;

    Lite_Adapter lisa_lite (
        .clk(C5M),
        .rst(~_RSTSW_int),
        .PH0(PH[0]),
        .MT(MT1),
        .PWM(PWM)
    );

    always_comb begin
        // If FLOPPY_SRC is high, use the external floppy drive signals
        if (FLOPPY_SRC) begin
            if (IO_ROM_SEL) begin
                // If we're in Twiggy mode, hook RDA and SNS up to their own individual pins
                RDA = RDA_EXTFLOPPY;
                SNS = SNS_EXTFLOPPY;
            end else begin
                // If we're in Sony mode, hook both RDA and SNS to RDA
                RDA = RDA_EXTFLOPPY;
                SNS = RDA_EXTFLOPPY;
            end
            WRD_EXTFLOPPY = WRD;
            _WRQ_EXTFLOPPY = _WRQ;
            HDS_EXTFLOPPY = HDS;
            PH_EXTFLOPPY = PH;
            MT1_EXTFLOPPY = MT1;
            MT0_EXTFLOPPY = MT0;
            _DR1_EXTFLOPPY = _DR1;
            _DR0_EXTFLOPPY = _DR0;
            PWM_EXTFLOPPY = PWM;
            // And make sure that the onboard ESFloppy signals are inactive
            WRD_ESFLOPPY = 1'b0;
            _WRQ_ESFLOPPY = 1'b1;
            HDS_ESFLOPPY = 1'b0;
            PH_ESFLOPPY = 4'b0000;
            MT1_ESFLOPPY = 1'b0;
            MT0_ESFLOPPY = 1'b0;
            _DR1_ESFLOPPY = 1'b1;
            _DR0_ESFLOPPY = 1'b1;
            PWM_ESFLOPPY = 1'b0;
        // Otherwise, use the onboard ESFloppy signals
        end else begin
            if (IO_ROM_SEL) begin
                // If we're in Twiggy mode, hook RDA and SNS up to their own individual pins
                RDA = RDA_ESFLOPPY;
                SNS = SNS_ESFLOPPY;
            end else begin
                // If we're in Sony mode, hook both RDA and SNS to RDA
                RDA = RDA_ESFLOPPY;
                SNS = RDA_ESFLOPPY;
            end
            WRD_ESFLOPPY = WRD;
            _WRQ_ESFLOPPY = _WRQ;
            HDS_ESFLOPPY = HDS;
            PH_ESFLOPPY = PH;
            MT1_ESFLOPPY = MT1;
            MT0_ESFLOPPY = MT0;
            _DR1_ESFLOPPY = _DR1;
            _DR0_ESFLOPPY = _DR0;
            PWM_ESFLOPPY = PWM;
            // And make sure that the external floppy drive signals are inactive
            WRD_EXTFLOPPY = 1'b0;
            _WRQ_EXTFLOPPY = 1'b1;
            HDS_EXTFLOPPY = 1'b0;
            PH_EXTFLOPPY = 4'b0000;
            MT1_EXTFLOPPY = 1'b0;
            MT0_EXTFLOPPY = 1'b0;
            _DR1_EXTFLOPPY = 1'b1;
            _DR0_EXTFLOPPY = 1'b1;
            PWM_EXTFLOPPY = 1'b0;
        end
    end

    // The mouse can either be driven over USB or by a real Lisa/Mac mouse
    logic [6:0] M_USB;

    // Now it's time to do our USB peripherals
    // Previously, the first USB port was for the mouse and the second for the keyboard
    // But now they're flexible and you can plug either device into either port
    // So we basically instantiate two USB HID host controllers, one for each port
    // And then read their type codes to figure out which is which
    // Then we route the mouse data from whichever port has the mouse, and the keyboard data from whichever port has the keyboard

    // Before we do anything else related to USB though, we need to mess with our reset signal a bit
    // The regular reset signal is generated in the DOTCK domain, but we need it in the usbclk domain
    // So we'll create a synchronized version of it here
    (* ASYNC_REG = "TRUE" *) logic usbrst_int, usbrst;
    always_ff @(posedge usbclk) begin
        usbrst_int <= _RESET;
        usbrst <= usbrst_int;
    end

    // We also need IOBUFs for the USB data lines since they're bidirectional
    // First for the USB D+ line
    logic usb_dp_in_port0;
    logic usb_dp_out_port0;
    logic usb_dm_in_port0;
    logic usb_dm_out_port0;
    logic usb_oe_port0;
    IOBUF USB_PORT0_DP_BUF (
        // Send anything coming over the port to usb_dp_in
        .O(usb_dp_in_port0),
        // The bidirectional line is MOUSE_DP (the first USB port was previously hard-wired to be for the mouse)
        .IO(MOUSE_DP),
        // Drive the line with usb_dp_out
        .I(usb_dp_out_port0),
        // But only drive it when usb_oe is asserted (high)
        .T(~usb_oe_port0)
    );

    // Same for the USB D- line
    IOBUF USB_PORT0_DN_BUF (
        .O(usb_dm_in_port0),
        .IO(MOUSE_DN), // The first USB port was previously hard-wired to be for the mouse, the name is a bit of a misnomer now
        .I(usb_dm_out_port0),
        .T(~usb_oe_port0)
    );

    logic [1:0] usb_typ_port0;
    logic usb_report_port0;
    logic [7:0] usb_mouse_btn_port0;
    logic signed [7:0] usb_mouse_dx_port0;
    logic signed [7:0] usb_mouse_dy_port0;
    logic [7:0] usb_key_modifiers_port0;
    logic [7:0] usb_key1_port0;
    // Instantiate the USB HID host module for the first USB port (port 0, previously hard-coded to be for the mouse)
    `ifndef SIMULATION
        usb_hid_host usb_port0 (
            .usbclk(usbclk), // 12MHz clock
            .usbrst_n(usbrst), // Active-low reset
            .usb_dm(usb_dm_out_port0), // USB I/O
            .usb_dp(usb_dp_out_port0),
            .usb_dp_in(usb_dp_in_port0),
            .usb_dm_in(usb_dm_in_port0),
            .usb_oe(usb_oe_port0),
            .typ(usb_typ_port0), // Type 2 = mouse, type 1 = keyboard
            .report(usb_report_port0), // Pulses when we get a report from the device
            .mouse_btn(usb_mouse_btn_port0), // Mouse button states
            .mouse_dx(usb_mouse_dx_port0), // Mouse x and y movement
            .mouse_dy(usb_mouse_dy_port0),
            .key_modifiers(usb_key_modifiers_port0), // Keyboard key modifier bits
            .key1(usb_key1_port0) // Up to 4 simultaneous keycodes
        );
    `endif

    // Now repeat all that for the second USB port (port 1), previously hard-coded to be for the keyboard but now can be for anything
    // We also need IOBUFs for the USB data lines since they're bidirectional
    // First for the USB D+ line
    logic usb_dp_in_port1;
    logic usb_dp_out_port1;
    logic usb_dm_in_port1;
    logic usb_dm_out_port1;
    logic usb_oe_port1;
    IOBUF USB_PORT1_DP_BUF (
        // Send anything coming over the port to usb_dp_in
        .O(usb_dp_in_port1),
        // The bidirectional line is KBD_DP (the second USB port was previously hard-wired to be for the keyboard)
        .IO(KBD_DP),
        // Drive the line with usb_dp_out
        .I(usb_dp_out_port1),
        // But only drive it when usb_oe is asserted (high)
        .T(~usb_oe_port1)
    );

    // Same for the USB D- line
    IOBUF USB_PORT1_DN_BUF (
        .O(usb_dm_in_port1),
        .IO(KBD_DN), // The second USB port was previously hard-wired to be for the keyboard
        .I(usb_dm_out_port1),
        .T(~usb_oe_port1)
    );

    logic [1:0] usb_typ_port1;
    logic usb_report_port1;
    logic [7:0] usb_mouse_btn_port1;
    logic signed [7:0] usb_mouse_dx_port1;
    logic signed [7:0] usb_mouse_dy_port1;
    logic [7:0] usb_key_modifiers_port1;
    logic [7:0] usb_key1_port1;
    // Instantiate the USB HID host module for the second USB port (port 1, previously hard-coded to be for the keyboard)
    `ifndef SIMULATION
        usb_hid_host usb_port1 (
            .usbclk(usbclk), // 12MHz clock
            .usbrst_n(usbrst), // Active-low reset
            .usb_dm(usb_dm_out_port1), // USB I/O
            .usb_dp(usb_dp_out_port1),
            .usb_dp_in(usb_dp_in_port1),
            .usb_dm_in(usb_dm_in_port1),
            .usb_oe(usb_oe_port1),
            .typ(usb_typ_port1), // Type 2 = mouse, type 1 = keyboard
            .report(usb_report_port1), // Pulses when we get a report from the device
            .mouse_btn(usb_mouse_btn_port1), // Mouse button states
            .mouse_dx(usb_mouse_dx_port1), // Mouse x and y movement
            .mouse_dy(usb_mouse_dy_port1),
            .key_modifiers(usb_key_modifiers_port1), // Keyboard key modifier bits
            .key1(usb_key1_port1) // Up to 4 simultaneous keycodes
        );
    `endif

    // Now we just need to look at the type codes from each port and route the data accordingly
    logic signed [7:0] mouse_dx_selected;
    logic signed [7:0] mouse_dy_selected;
    logic [7:0] mouse_btn_selected;
    logic mouse_report_selected;
    logic [7:0] key_modifiers_selected;
    logic [7:0] key1_selected;
    logic key_report_selected;

    always_comb begin
        if (usb_typ_port0 == 2'd1) begin
            // If the port0 type is 1, then it's a keyboard, so route it to the keyboard module
            key_modifiers_selected = usb_key_modifiers_port0;
            key1_selected = usb_key1_port0;
            key_report_selected = usb_report_port0;
        end else if (usb_typ_port1 == 2'd1) begin
            // Otherwise, if port1 is a keyboard, then route that to the keyboard module
            // Notice that if both ports are keyboards, port0 takes priority
            key_modifiers_selected = usb_key_modifiers_port1;
            key1_selected = usb_key1_port1;
            key_report_selected = usb_report_port1;
        end else begin
            // If neither port is a keyboard, just send zeros to the keyboard module
            key_modifiers_selected = 8'b0;
            key1_selected = 8'b0;
            key_report_selected = 1'b0;
        end
        if (usb_typ_port0 == 2'd2) begin
            // If the port0 type is 2, then it's a mouse, so route it to the mouse module
            mouse_dx_selected = usb_mouse_dx_port0;
            mouse_dy_selected = usb_mouse_dy_port0;
            mouse_btn_selected = usb_mouse_btn_port0;
            mouse_report_selected = usb_report_port0;
        end else if (usb_typ_port1 == 2'd2) begin
            // Otherwise, if port1 is a mouse, then route that to the mouse module
            // Once again, if both ports are the same peripheral, then port0 takes priority
            mouse_dx_selected = usb_mouse_dx_port1;
            mouse_dy_selected = usb_mouse_dy_port1;
            mouse_btn_selected = usb_mouse_btn_port1;
            mouse_report_selected = usb_report_port1;
        end else begin
            // If neither port is a mouse, just send zeros to the mouse module
            mouse_dx_selected = 8'sb0;
            mouse_dy_selected = 8'sb0;
            mouse_btn_selected = 1'b0;
            mouse_report_selected = 1'b0;
        end
    end

    logic KBD_in_USB;
    logic KBD_out_USB;
    // Finally, instantiate the USB mouse interface module, routing in the appropriate signals
    `ifndef SIMULATION
        usb_mouse_interface usb_mouse_interface (
            .usbclk(usbclk),
            .usbrst(usbrst),
            .mouse_dx_in(mouse_dx_selected),
            .mouse_dy_in(mouse_dy_selected),
            .mouse_btn_in(mouse_btn_selected),
            .report(mouse_report_selected),
            .M(M_USB)
        );
        // And now the USB keyboard one
        usb_keyboard_interface usb_kbd_interface (
            .usbclk(usbclk),
            .usbrst(usbrst),
            .key_modifiers_in(key_modifiers_selected),
            .key1_in(key1_selected),
            .report(key_report_selected),
            .KBD_in(KBD_out_USB),
            .KBD_out(KBD_in_USB)
        );
    `endif

    // There's a little more we need to do for the keyboard though; it's bidirectional, so we need to make an IOBUF for the Lisa keyboard interface
    logic KBD_in_LISA;
    logic KBD_out_LISA;
    IOBUF KBDBuf (
        // Any data received from the keyboard goes to KBD_in
        .O(KBD_in_LISA),
        // The actual bidirectional pin that goes to the keyboard connector is KBD
        .IO(KBD),
        // We hard-wire the data we want to send to the keyboard to 1'b0 (the keyboard line is open-collector, so we can only pull it low)
        .I(1'b0),
        // And we pull it low whenever KBD_out is low; otherwise the IOBUF makes the line high-z so the keyboard can drive it
        .T(KBD_out_LISA)
    );

    // And we have to mux between the USB and Lisa keyboard interfaces, depending on the KBD_SEL signal
    always_comb begin
        // If it's high, then use the USB keyboard
        if (KBD_SEL) begin
            KBD_in = KBD_in_USB;
            KBD_out_USB = KBD_out;
            KBD_out_LISA = 1'b1; // Make sure the Lisa keyboard interface is inactive
        // And if it's low, use the Lisa keyboard interface
        end else begin
            KBD_in = KBD_in_LISA;
            KBD_out_LISA = KBD_out;
            KBD_out_USB = 1'b1; // Make sure the USB keyboard interface is inactive
        end
    end

    // The Lisa mouse interface is literally just the M_LISA line from the port declaration
    // So now mux between them based on the MOUSE_SEL signal
    always_comb begin
        // If MOUSE_SEL is high, use the USB mouse
        if (MOUSE_SEL) begin
            M = M_USB;
        // Otherwise, use the Lisa mouse interface
        end else begin
            M = M_LISA;
        end
    end

    // In real life, the ProFile can either be a real ProFile, or an onboard ESProFile emulator
    // We'll need to mux between them, but first let's worry about the ProFile's bidirectional data bus
    logic [7:0] PD_in_ESProFile;
    logic [7:0] PD_out_ESProFile;
    logic _ProFile_EN_ESProFile;
    logic PR_W_ungated_ESProFile;
    // All the ProFile data bus signals are bidirectional, so we need IOBUFs for them
    // We use a generate loop to make 8 of them at once, first for the ESProFile
    generate
        for (i = 0; i < 8; i++) begin
            IOBUF PDBuf_ESProFile (
                // Incoming data from the ProFile goes to PD_in_ESProFile[i]
                .O(PD_in_ESProFile[i]),
                // The bidirectional pins that go to the ProFile connector are PD_ESPROFILE[0] through PD_ESPROFILE[7]
                .IO(PD_ESPROFILE[i]),
                // The data to send to the ProFile is PD_out_ESProFile[i]
                .I(PD_out_ESProFile[i]),
                // The direction is controlled by the unbuffered DR_W; high means ProFile->Lisa, low means Lisa->ProFile
                // But only when _ProFile_EN is low; when it's high, make the lines high-Z
                .T(_ProFile_EN_ESProFile | PR_W_ungated_ESProFile)
            );
        end
    endgenerate
    // Oh yeah, CRES or PRES or whatever is bidirectional too
    logic _CRES_in_ESProFile;
    logic _CRES_out_ESProFile;
    IOBUF cresBuf_ESProFile (
        // Resets from the ProFile go to _CRES_in
        .O(_CRES_in_ESProFile),
        // The bidirectional pin that goes to the ProFile connector is _PRES_ESPROFILE
        .IO(_PRES_ESPROFILE),
        // Since the data line is open collector, we hard-wire the data we want to send to the ProFile to 1'b0
        .I(1'b0),
        // Pull it low whenever _CRES_out is low; otherwise make it high-Z and a pullup will take it high
        .T(_CRES_out_ESProFile)
    );
    // Now do the same thing for the external "real" ProFile
    logic [7:0] PD_in_ExtProFile;
    logic [7:0] PD_out_ExtProFile;
    logic _ProFile_EN_ExtProFile;
    logic PR_W_ungated_ExtProFile;
    generate
        for (i = 0; i < 8; i++) begin
            IOBUF PDBuf_ExtProFile (
                // Incoming data from the ProFile goes to PD_in_ExtProFile[i]
                .O(PD_in_ExtProFile[i]),
                // The bidirectional pins that go to the ProFile connector are PD_EXTPROFILE[0] through PD_EXTPROFILE[7]
                .IO(PD_EXTPROFILE[i]),
                // The data to send to the ProFile is PD_out_ExtProFile[i]
                .I(PD_out_ExtProFile[i]),
                // The direction is controlled by the unbuffered DR_W; high means ProFile->Lisa, low means Lisa->ProFile
                // But only when _ProFile_EN is low; when it's high, make the lines high-Z
                .T(_ProFile_EN_ExtProFile | PR_W_ungated_ExtProFile)
            );
        end
    endgenerate
    logic _CRES_in_ExtProFile;
    logic _CRES_out_ExtProFile;
    IOBUF cresBuf_ExtProFile (
        // Resets from the ProFile go to _CRES_in
        .O(_CRES_in_ExtProFile),
        // The bidirectional pin that goes to the ProFile connector is _PRES_EXTPROFILE
        .IO(_PRES_EXTPROFILE),
        // Since the data line is open collector, we hard-wire the data we want to send to the ProFile to 1'b0
        .I(1'b0),
        // Pull it low whenever _CRES_out is low; otherwise make it high-Z and a pullup will take it high
        .T(_CRES_out_ExtProFile)
    );
    // For now, just hard-code something to the "ESProFile comm bus"
    assign ESPROFILE_COMM_BUS = 3'b101;
    // And now we just have to mux all that, along with some unidirectional control signals
    // This depends on the state of the HDD_SRC switch
    always_comb begin
        // If HDD_SRC is low, use the ESProFile
        if (!HDD_SRC) begin
            PD_in = PD_in_ESProFile;
            PD_out_ESProFile = PD_out;
            _ProFile_EN_ESProFile = _ProFile_EN;
            PR_W_ungated_ESProFile = PR_W_ungated;
            _CRES_in = _CRES_in_ESProFile;
            _CRES_out_ESProFile = _CRES_out;
            _CMD_ESPROFILE = _CMD;
            _BSY = _BSY_ESPROFILE;
            R_W_ESPROFILE = DR_W;
            _STRB_ESPROFILE = _PSTRB;
            _PARITY = _PARITY_ESPROFILE;
            OCD = OCD_ESPROFILE;
            // But make sure that the external ProFile is left in a safe state (all outputs deasserted)
            PD_out_ExtProFile = 8'b00000000;
            _ProFile_EN_ExtProFile = 1'b1;
            PR_W_ungated_ExtProFile = 1'b1;
            _CRES_out_ExtProFile = 1'b1;
            _CMD_EXTPROFILE = 1'b1;
            R_W_EXTPROFILE = 1'b1;
            _STRB_EXTPROFILE = 1'b1;
        // Otherwise, use the external "real" ProFile
        end else begin
            PD_in = PD_in_ExtProFile;
            PD_out_ExtProFile = PD_out;
            _ProFile_EN_ExtProFile = _ProFile_EN;
            PR_W_ungated_ExtProFile = PR_W_ungated;
            _CRES_in = _CRES_in_ExtProFile;
            _CRES_out_ExtProFile = _CRES_out;
            _CMD_EXTPROFILE = _CMD;
            _BSY = _BSY_EXTPROFILE;
            R_W_EXTPROFILE = DR_W;
            _STRB_EXTPROFILE = _PSTRB;
            _PARITY = _PARITY_EXTPROFILE;
            OCD = OCD_EXTPROFILE;
            // And make sure that ESProFile is left in a safe state
            PD_out_ESProFile = 8'b00000000;
            _ProFile_EN_ESProFile = 1'b1;
            PR_W_ungated_ESProFile = 1'b1;
            _CRES_out_ESProFile = 1'b1;
            _CMD_ESPROFILE = 1'b1;
            R_W_ESPROFILE = 1'b1;
            _STRB_ESPROFILE = 1'b1;
        end
    end

    logic [7:0] SCC_DOUT;
    logic [7:0] SCC_DIN;

    IO_board io_board(
        .PH(PH),
        .WRD(WRD),
        ._WRQ(_WRQ),
        .RDA(RDA),
        ._DR1(_DR1),
        ._DR0(_DR0),
        .HDS(HDS),
        .SNS(SNS),
        .MT1(MT1),
        .MT0(MT0),
        ._IRQ(_IRQ),
        ._RSIR(_RSIR),
        ._KBIR(_KBIR),
        ._IOIR(_IOIR),
        .E(E),
        ._RESET_SYSTEM(_RESET),
        .CPUCK(CPUCK),
        ._LDMA(_LDMA),
        ._BGACK(_BGACK),
        ._BR(_BR),
        ._BG0(_BG0),
        ._BG(_BG),
        .BD_in(BD),
        .BD_out(BD_IO),
        .BD_OE(BD_OE_IO),
        .A(A),
        ._VMA(_VMA),
        ._VPA_in(_VPA),
        ._VPA_out(_VPA_IO),
        .VPA_OE(VPA_OE_IO),
        ._DTACK_in(_DTACK),
        ._DTACK_out(_DTACK_IO),
        .DTACK_OE(DTACK_OE_IO),
        ._AS(_AS),
        .READ(READ),
        ._LDS(_LDS),
        ._UDS(_UDS),
        ._INTIO(_INTIO),
        .OCD(OCD),
        .PD_in(PD_in),
        .PD_out(PD_out),
        ._ProFile_EN(_ProFile_EN),
        .PR_W_ungated(PR_W_ungated),
        ._PARITY(_PARITY),
        ._PSTRB(_PSTRB),
        .DR_W(DR_W),
        ._BSY(_BSY),
        ._CMD(_CMD),
        //.SPKRIN(SPKRIN),
        .TONE(TONE),
        .CONT(CONT),
        .KBD_in(KBD_in),
        .KBD_out(KBD_out),
        .M(M),
        .SYNCA(SYNCA),
        .TXDA(TXDA),
        .RTSA(RTSA),
        .DTRA(DTRA),
        .RXDA(RXDA),
        .CTSA(CTSA),
        .DCDA(DCDA),
        .TRXCA(TRXCA),
        .RTXCA(RTXCA),
        .TXDB(TXDB),
        .DTRB(DTRB),
        .RTSB(RTSB),
        .RXDB(RXDB),
        .CTSB_TRXCB(CTSB_TRXCB),
        ._CRES_in(_CRES_in),
        ._CRES_out(_CRES_out),
        ._NMI(_NMI_IO),
        .NMI_OE(NMI_OE_IO),
        ._PWRSW(_PWRSW),
        .ON(ON),

        .sysclk(sysclk_ibuf),
        .C16M(C16M),
        .COPCK_2x(COPCK_2x),
        .COPCK(COPCK),
        .SCCCK(SCCCK),
        .E_pos_phase(E_pos_phase),
        .E_neg_phase(E_neg_phase),
        .DOTCK(DOTCK),
        .E_either_edge(E_either_edge),
        .VC(VC),
        .SCC_C4M(SCC_C4M),
        .SCC_WR(SCC_WR),
        .SCC_RD(SCC_RD),
        ._SCC_RSIR(_SCC_RSIR),
        .SCC_A2(SCC_A2),
        .SCC_A1(SCC_A1),
        ._SCC_CS(_SCC_CS),
        ._SCC_PSI(_SCC_PSI),
        .SCC_DOUT(SCC_DOUT),
        .SCC_DIN(SCC_DIN),
        .IO_ROM_SEL(IO_ROM_SEL)
    );


    `ifndef SIMULATION
        // The external SCC uses a bidrectional data bus, so we need IOBUFs for it
        generate
            for (i = 0; i < 8; i++) begin
                IOBUF SCC_DBuf (
                    // Incoming data from the SCC goes into SCC_DIN[i]
                    .O(SCC_DIN[i]),
                    // The bidirectional SCC bus is SCC_D[7:0]
                    .IO(SCC_D[i]),
                    // Outgoing data to the SCC is SCC_DOUT[i]
                    .I(SCC_DOUT[i]),
                    // Direction is determined by SCC_WR; high means SCC->Lisa, low means Lisa->SCC
                    .T(SCC_WR)
                );
            end
        endgenerate
    `endif


    logic [15:0] DIN_SRAM;
    logic [15:0] DOUT_SRAM;
    logic SRAM_BUS_DIR;
    `ifndef SIMULATION
        // The external SRAM chip has a bidirectional data bus, so we need IOBUFs for it
        generate
            for (i = 0; i < 16; i++) begin
                IOBUF SRAM_DBuf (
                    // Incoming data from the SRAM goes into DIN_SRAM[i]
                    .O(DIN_SRAM[i]),
                    // The bidirectional SRAM data bus is D_SRAM[15:0]
                    .IO(D_SRAM[i]),
                    // And the data to send to the RAM is DOUT_SRAM[i]
                    .I(DOUT_SRAM[i]),
                    // Only output data when SRAM_BUS_DIR is low (RAM controller is writing to RAM)
                    // Otherwise we should be reading input from the RAM
                    .T(SRAM_BUS_DIR)
                );
            end
        endgenerate
    `endif

    `ifdef SIMULATION
        // If we're simulating, just instantiate a single 512KB memory board; it's the only one that supports block RAM
        mem_board_512k slot1(
            .RA(RA),
            .A17(A17),
            .A18(A18),
            .A19(A19),
            .A20(A20),
            .VA9(VA9B),
            .VA10(VA10B),
            .DOTCK(DOTCK),
            ._UDS(_UDS),
            ._LDS(_LDS),
            ._CAS(_CAS),
            ._RAS(_RAS),
            .MREAD(MREAD),
            .SLOT(1'b1),
            ._RFSH(_R1),
            .T1(T1),
            .T2(T2),
            .T3(T3),
            .A16(A16),
            .S1(1'b0),
            .S2(1'b0),
            .S3(1'b0),
            .MD_IN(MD_OUT),
            .MD_OUT(MD_IN),
            ._HDER_in(_HDER),
            ._HDER_out(_HDER_MEM),
            .HDER_OE(HDER_OE_MEM),
            ._SFER_in(_SFER),
            ._SFER_out(_SFER_MEM),
            .SFER_OE(SFER_OE_MEM),
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
    `else
        // Otherwise, instantiate a 2MB memory board; it uses the external SDRAM chip
        mem_board_2mb slot1(
            .RA(RA),
            .A16(A16),
            .A17(A17),
            .A18(A18),
            .A19(A19),
            .A20(A20),
            .RAM_SEL(RAM_SEL),
            .DOTCK(DOTCK),
            ._UDS(_UDS),
            ._LDS(_LDS),
            ._CAS(_CAS),
            ._RAS(_RAS),
            .MREAD(MREAD),
            .MD_IN(MD_OUT),
            .MD_OUT(MD_IN),
            ._HDER_in(_HDER),
            ._HDER_out(_HDER_MEM),
            .HDER_OE(HDER_OE_MEM),
            ._SFER_in(_SFER),
            ._SFER_out(_SFER_MEM),
            .SFER_OE(SFER_OE_MEM),
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