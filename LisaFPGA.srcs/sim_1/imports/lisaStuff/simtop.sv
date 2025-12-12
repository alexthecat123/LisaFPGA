`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2025 11:22:38 AM
// Design Name: 
// Module Name: simtop
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

module simtop(

    );

    logic sysclk;
    logic _VSYNC;
    logic _HSYNC;
    logic VID;
    logic [5:0] CONT;

    logic TONE;
    logic [2:0] VC;

    logic HDMI_CLK_N;
    logic HDMI_CLK_P;
    logic [2:0] HDMI_D_N;
    logic [2:0] HDMI_D_P;

    logic _CE_SRAM;
    logic _OE_SRAM;
    logic _WE_SRAM;
    logic _UDS_SRAM;
    logic _LDS_SRAM;
    logic [20:1] A_SRAM;
    wire [15:0] D_SRAM;

    wire [7:0] ESFLOPPY_COMM_BUS;
    logic WRD_ESFLOPPY;
    logic _WRQ_ESFLOPPY;
    logic HDS_ESFLOPPY;
    logic [3:0] PH_ESFLOPPY;
    logic MT1_ESFLOPPY;
    logic MT0_ESFLOPPY;
    logic _DR1_ESFLOPPY;
    logic _DR0_ESFLOPPY;
    logic PWM_ESFLOPPY;

    logic WRD_EXTFLOPPY;
    logic _WRQ_EXTFLOPPY;
    logic HDS_EXTFLOPPY;
    logic [3:0] PH_EXTFLOPPY;
    logic MT1_EXTFLOPPY;
    logic MT0_EXTFLOPPY;
    logic _DR1_EXTFLOPPY;
    logic _DR0_EXTFLOPPY;
    logic PWM_EXTFLOPPY;

    wire [2:0] ESPROFILE_COMM_BUS;
    logic _CMD_ESPROFILE;
    logic R_W_ESPROFILE;
    logic _STRB_ESPROFILE;
    wire _PRES_ESPROFILE;
    wire [7:0] PD_ESPROFILE;

    logic _CMD_EXTPROFILE;
    logic R_W_EXTPROFILE;
    logic _STRB_EXTPROFILE;
    wire _PRES_EXTPROFILE;
    wire [7:0] PD_EXTPROFILE;

    wire KBD_DN;
    wire KBD_DP;

    wire KBD;

    wire MOUSE_DN;
    wire MOUSE_DP;

    logic SCC_C4M;
    logic SCC_WR;
    logic SCC_RD;
    logic SCC_A2;
    logic SCC_A1;
    logic _SCC_CS;
    wire [7:0] SCC_D;

    logic TXDA;
    logic RTSA;
    logic DTRA;
    logic TRXCA;
    logic TXDB;
    logic DTRB;
    logic RTSB;

    logic INTERNAL_SCC_EN;

    logic _PWRSW;
    logic ON;
    logic _RSTSW;
    logic _RESET;
    logic _NMISW;

    top dut (
        .sysclk(sysclk),
        ._VSYNC(_VSYNC),
        ._HSYNC(_HSYNC),
        .VID(VID),
        .CONT(CONT),
        .INVID(1'b0),

        .TONE(TONE),
        .VC(VC),

        .HDMI_CLK_N(HDMI_CLK_N),
        .HDMI_CLK_P(HDMI_CLK_P),
        .HDMI_D_N(HDMI_D_N),
        .HDMI_D_P(HDMI_D_P),

        ._CE_SRAM(_CE_SRAM),
        ._OE_SRAM(_OE_SRAM),
        ._WE_SRAM(_WE_SRAM),
        ._UDS_SRAM(_UDS_SRAM),
        ._LDS_SRAM(_LDS_SRAM),
        .A_SRAM(A_SRAM),
        .D_SRAM(D_SRAM),

        .RAM_SEL(2'b11),

        .ESFLOPPY_COMM_BUS(ESFLOPPY_COMM_BUS),
        .RDA_ESFLOPPY(1'b1),
        .WRD_ESFLOPPY(WRD_ESFLOPPY),
        .SNS_ESFLOPPY(1'b1),
        ._WRQ_ESFLOPPY(_WRQ_ESFLOPPY),
        .HDS_ESFLOPPY(HDS_ESFLOPPY),
        .PH_ESFLOPPY(PH_ESFLOPPY),
        .MT1_ESFLOPPY(MT1_ESFLOPPY),
        .MT0_ESFLOPPY(MT0_ESFLOPPY),
        ._DR1_ESFLOPPY(_DR1_ESFLOPPY),
        ._DR0_ESFLOPPY(_DR0_ESFLOPPY),
        .PWM_ESFLOPPY(PWM_ESFLOPPY),

        .LEFT_ESFLOPPY(1'b1),
        .OK_ESFLOPPY(1'b1),
        .RIGHT_ESFLOPPY(1'b1),

        .RDA_EXTFLOPPY(1'b1),
        .WRD_EXTFLOPPY(WRD_EXTFLOPPY),
        .SNS_EXTFLOPPY(1'b1),
        ._WRQ_EXTFLOPPY(_WRQ_EXTFLOPPY),
        .HDS_EXTFLOPPY(HDS_EXTFLOPPY),
        .PH_EXTFLOPPY(PH_EXTFLOPPY),
        .MT1_EXTFLOPPY(MT1_EXTFLOPPY),
        .MT0_EXTFLOPPY(MT0_EXTFLOPPY),
        ._DR1_EXTFLOPPY(_DR1_EXTFLOPPY),
        ._DR0_EXTFLOPPY(_DR0_EXTFLOPPY),
        .PWM_EXTFLOPPY(PWM_EXTFLOPPY),

        .FLOPPY_SRC(1'b0),

        .ESPROFILE_COMM_BUS(ESPROFILE_COMM_BUS),
        ._CMD_ESPROFILE(_CMD_ESPROFILE),
        ._BSY_ESPROFILE(1'b1),
        .R_W_ESPROFILE(R_W_ESPROFILE),
        ._STRB_ESPROFILE(_STRB_ESPROFILE),
        ._PRES_ESPROFILE(_PRES_ESPROFILE),
        ._PARITY_ESPROFILE(1'b1),
        .OCD_ESPROFILE(1'b1),
        .PD_ESPROFILE(PD_ESPROFILE),

        ._CMD_EXTPROFILE(_CMD_EXTPROFILE),
        ._BSY_EXTPROFILE(1'b1),
        .R_W_EXTPROFILE(R_W_EXTPROFILE),
        ._STRB_EXTPROFILE(_STRB_EXTPROFILE),
        ._PRES_EXTPROFILE(_PRES_EXTPROFILE),
        ._PARITY_EXTPROFILE(1'b1),
        .OCD_EXTPROFILE(1'b1),
        .PD_EXTPROFILE(PD_EXTPROFILE),

        .HDD_SRC(1'b0),

        .KBD_DN(KBD_DN),
        .KBD_DP(KBD_DP),

        .KBD(KBD),

        .KBD_SEL(1'b0),

        .MOUSE_DN(MOUSE_DN),
        .MOUSE_DP(MOUSE_DP),

        .M_LISA(7'b0000000),

        .MOUSE_SEL(1'b0),

        .SCC_C4M(SCC_C4M),
        .SCC_WR(SCC_WR),
        .SCC_RD(SCC_RD),
        ._SCC_RSIR(1'b1),
        .SCC_A2(SCC_A2),
        .SCC_A1(SCC_A1),
        ._SCC_CS(_SCC_CS),
        ._SCC_PSI(1'b1),
        .SCC_D(SCC_D),

        .SYNCA(1'b0),
        .TXDA(TXDA),
        .RTSA(RTSA),
        .DTRA(DTRA),
        .RXDA(1'b1),
        .CTSA(1'b1),
        .DCDA(1'b1),
        .TRXCA(TRXCA),
        .RTXCA(1'b1),
        .TXDB(TXDB),
        .DTRB(DTRB),
        .RTSB(RTSB),
        .RXDB(1'b1),
        .CTSB_TRXCB(1'b1),

        .INTERNAL_SCC_EN(INTERNAL_SCC_EN),

        ._PWRSW(_PWRSW),
        .ON(ON),
        ._RSTSW(_RSTSW),
        ._RESET(_RESET),
        ._NMISW(_NMISW),

        .SPEED_SEL(2'b00),
        .CPU_ROM_SEL(1'b1),
        .IO_ROM_SEL(1'b0)
    );

    initial begin
        _NMISW = 1'b1;
        _PWRSW = 1'b1;
        #5000;
        _RSTSW = 1'b0; // Press reset
        #500000;
        _RSTSW = 1'b1; // Release reset
        #500000000;
        //_PWRSW = 1'b0; // Simulate pressing the power switch
        #100000000;
        //_PWRSW = 1'b1; // Simulate releasing the power switch
    end

    always begin
        sysclk = 1'b0;
        #25;
        sysclk = 1'b1;
        #25;
    end


endmodule
