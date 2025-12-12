## The XDC file for the LisaFPGA Desktop board. There are a whole lot of pins defined in here!
## As well as some allowing of combinatorial loops, which we have to do thanks to the Lisa's architecture.

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/BD_out[*]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/_BUST_latched]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/_BUST_latched__0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_21_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_22_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_23_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_24_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_25_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_26_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/BD_inferred_i_27_n_0]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[13]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[14]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[15]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[16]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[17]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[18]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[19]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/latched_MMU_address[20]}]

## Make sure that any nets marked as debug are also marked as DONT_TOUCH so that they don't get optimized away
set_property DONT_TOUCH true [get_nets -hier -filter {MARK_DEBUG == 1}]

## Tell Vivado that our SPI configuration flash bus is 4 bits wide to maximize bitstream loading speed at boot
## It should be about 4x faster than the default 1x configuration; almost instantaneous
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## Make sure Vivado knows about synchronizers we have in the design to avoid timing issues
## If we don't do this, Vivado will think we have timing violations on these paths, when in fact we don't
## The literal purpose of these paths is to fix the timing violations caused by clock domain crossings!
## False-path into the first stage of the HDMI reset synchronizer
set_false_path -to [get_pins lisa_hdmi_output/_reset_hdmi_int_reg/D]
## False-path into the first stage of the I/O board reset synchronizer
set_false_path -to [get_pins io_board/_RESET_int_reg/D]


## The 125MHz sysclk signal
## ADD CREATE_CLOCKS FOR ALL THE OTHER CLOCK SIGNALS TOO!!!!
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports sysclk]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports sysclk]

## Audio and Video Stuff
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports _VSYNC]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports _HSYNC]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports VID]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33} [get_ports {CONT[0]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {CONT[1]}]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {CONT[2]}]
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33} [get_ports {CONT[3]}]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports {CONT[4]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {CONT[5]}]
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports INVID]
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS33} [get_ports TONE]
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33} [get_ports {VC[0]}]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33} [get_ports {VC[1]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {VC[2]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_N]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_P]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD TMDS_33} [get_ports {HDMI_D_N[0]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD TMDS_33} [get_ports {HDMI_D_P[0]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD TMDS_33} [get_ports {HDMI_D_N[1]}]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD TMDS_33} [get_ports {HDMI_D_P[1]}]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD TMDS_33} [get_ports {HDMI_D_N[2]}]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD TMDS_33} [get_ports {HDMI_D_P[2]}]
#set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports HDMI_HPD]
#set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports HDMI_SCL]
#set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports HDMI_SDA]

## Parallel SRAM Interface
set_property -dict {PACKAGE_PIN K6 IOSTANDARD LVCMOS33} [get_ports _CE_SRAM]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports _OE_SRAM]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33} [get_ports _WE_SRAM]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33} [get_ports _UDS_SRAM]
set_property -dict {PACKAGE_PIN L3 IOSTANDARD LVCMOS33} [get_ports _LDS_SRAM]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[1]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[2]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[3]}]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[4]}]
set_property -dict {PACKAGE_PIN K5 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[5]}]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[6]}]
set_property -dict {PACKAGE_PIN L6 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[7]}]
set_property -dict {PACKAGE_PIN L5 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[8]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[9]}]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[10]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[11]}]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[12]}]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[13]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[14]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[15]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[16]}]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[17]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[18]}]
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[19]}]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports {A_SRAM[20]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[0]}]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[1]}]
set_property -dict {PACKAGE_PIN P4 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[2]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[3]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[4]}]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[5]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[6]}]
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[7]}]
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[8]}]
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[9]}]
set_property -dict {PACKAGE_PIN M6 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[10]}]
# Normal SRAM Pin
set_property -dict {PACKAGE_PIN N6 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[11]}]
# GPIO SRAM Pin
#set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[11]}]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[12]}]
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[13]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[14]}]
set_property -dict {PACKAGE_PIN V6 IOSTANDARD LVCMOS33} [get_ports {D_SRAM[15]}]
set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {RAM_SEL[0]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS33} [get_ports {RAM_SEL[1]}]

## Floppy Disk Interface
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[0]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[1]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[3]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[4]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[5]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[6]}]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {ESFLOPPY_COMM_BUS[7]}]
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports RDA_ESFLOPPY]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports WRD_ESFLOPPY]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports SNS_ESFLOPPY]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports _WRQ_ESFLOPPY]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports HDS_ESFLOPPY]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {PH_ESFLOPPY[0]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {PH_ESFLOPPY[1]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {PH_ESFLOPPY[2]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {PH_ESFLOPPY[3]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports MT1_ESFLOPPY]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports MT0_ESFLOPPY]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports _DR1_ESFLOPPY]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports _DR0_ESFLOPPY]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports PWM_ESFLOPPY]
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports LEFT_ESFLOPPY]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports OK_ESFLOPPY]
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports RIGHT_ESFLOPPY]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports RDA_EXTFLOPPY]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports WRD_EXTFLOPPY]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports SNS_EXTFLOPPY]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports _WRQ_EXTFLOPPY]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports HDS_EXTFLOPPY]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {PH_EXTFLOPPY[0]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {PH_EXTFLOPPY[1]}]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {PH_EXTFLOPPY[2]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {PH_EXTFLOPPY[3]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports MT1_EXTFLOPPY]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports MT0_EXTFLOPPY]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports _DR1_EXTFLOPPY]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports _DR0_EXTFLOPPY]
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports PWM_EXTFLOPPY]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports FLOPPY_SRC]

## ProFile Interface
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {ESPROFILE_COMM_BUS[0]}]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports {ESPROFILE_COMM_BUS[1]}]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports {ESPROFILE_COMM_BUS[2]}]
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS33} [get_ports _CMD_ESPROFILE]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports _BSY_ESPROFILE]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports R_W_ESPROFILE]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports _STRB_ESPROFILE]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports _PRES_ESPROFILE]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports _PARITY_ESPROFILE]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports OCD_ESPROFILE]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[0]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[1]}]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[2]}]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[3]}]
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[4]}]
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[5]}]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[6]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports {PD_ESPROFILE[7]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports _CMD_EXTPROFILE]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports _BSY_EXTPROFILE]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports R_W_EXTPROFILE]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports _STRB_EXTPROFILE]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports _PRES_EXTPROFILE]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports _PARITY_EXTPROFILE]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports OCD_EXTPROFILE]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[0]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[1]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[2]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[3]}]
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[4]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[5]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[6]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {PD_EXTPROFILE[7]}]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports HDD_SRC]

## Keyboard Interface
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports KBD_DN]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports KBD_DP]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports KBD]
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS33} [get_ports KBD_SEL]

## Mouse Interface
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports MOUSE_DN]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports MOUSE_DP]
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS33} [get_ports {M_LISA[0]}]
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS33} [get_ports {M_LISA[1]}]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {M_LISA[2]}]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33} [get_ports {M_LISA[3]}]
set_property -dict {PACKAGE_PIN R7 IOSTANDARD LVCMOS33} [get_ports {M_LISA[4]}]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33} [get_ports {M_LISA[5]}]
set_property -dict {PACKAGE_PIN R8 IOSTANDARD LVCMOS33} [get_ports {M_LISA[6]}]
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports MOUSE_SEL]

## GPIO Pins
#set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {GPIO[0]}]
#set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports {GPIO[1]}]
#set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports {GPIO[2]}]
#set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports {GPIO[3]}]
#set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {GPIO[4]}]
#set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {GPIO[5]}]

## Comms With External SCC
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports SCC_C4M]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS33} [get_ports SCC_WR]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33} [get_ports SCC_RD]
set_property -dict {PACKAGE_PIN B6 IOSTANDARD LVCMOS33} [get_ports _SCC_RSIR]
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports SCC_A2]
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports SCC_A1]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports _SCC_CS]
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports _SCC_PSI]
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS33} [get_ports {SCC_D[0]}]
set_property -dict {PACKAGE_PIN E7 IOSTANDARD LVCMOS33} [get_ports {SCC_D[1]}]
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33} [get_ports {SCC_D[2]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports {SCC_D[3]}]
set_property -dict {PACKAGE_PIN C7 IOSTANDARD LVCMOS33} [get_ports {SCC_D[4]}]
set_property -dict {PACKAGE_PIN D8 IOSTANDARD LVCMOS33} [get_ports {SCC_D[5]}]
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33} [get_ports {SCC_D[6]}]
set_property -dict {PACKAGE_PIN A6 IOSTANDARD LVCMOS33} [get_ports {SCC_D[7]}]

## I/O From Internal SCC (Not Implemented In HDL Yet)
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports SYNCA]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports TXDA]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports RTSA]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports DTRA]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports RXDA]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports CTSA]
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports DCDA]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports TRXCA]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports RTXCA]
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports TXDB]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports DTRB]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports RTSB]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports RXDB]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports CTSB_TRXCB]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33} [get_ports INTERNAL_SCC_EN]

## Everything Else
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports _PWRSW]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports ON]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports _RSTSW]
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports _RESET]
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports _NMISW]
set_property -dict {PACKAGE_PIN B7 IOSTANDARD LVCMOS33} [get_ports {SPEED_SEL[0]}]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} [get_ports {SPEED_SEL[1]}]
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} [get_ports CPU_ROM_SEL]
set_property -dict {PACKAGE_PIN F5 IOSTANDARD LVCMOS33} [get_ports IO_ROM_SEL]























connect_debug_port u_ila_0/probe39 [get_nets [list slot1/SDRAM_2MB/R_W_int]]




connect_debug_port u_ila_0/probe12 [get_nets [list {slot1/SDRAM_2MB/state[0]} {slot1/SDRAM_2MB/state[1]} {slot1/SDRAM_2MB/state[2]}]]
connect_debug_port u_ila_0/probe14 [get_nets [list {slot1/SDRAM_2MB/next_state[0]} {slot1/SDRAM_2MB/next_state[1]} {slot1/SDRAM_2MB/next_state[2]}]]
connect_debug_port u_ila_0/probe34 [get_nets [list slot1/SDRAM_2MB/bus_drive]]
connect_debug_port u_ila_0/probe35 [get_nets [list slot1/SDRAM_2MB/cas_falling_edge]]
connect_debug_port u_ila_0/probe41 [get_nets [list slot1/SDRAM_2MB/oe_int]]
connect_debug_port u_ila_0/probe42 [get_nets [list slot1/SDRAM_2MB/R_W]]
connect_debug_port u_ila_0/probe47 [get_nets [list slot1/SDRAM_2MB/we_int]]




connect_debug_port u_ila_0/probe8 [get_nets [list {SPEED_SEL_IBUF[0]}]]
connect_debug_port dbg_hub/clk [get_nets dotck_20M]




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clkdiv_125mhz_to_20mhz/inst/lisa_dotck]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 6 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {CONT_OBUF[0]} {CONT_OBUF[1]} {CONT_OBUF[2]} {CONT_OBUF[3]} {CONT_OBUF[4]} {CONT_OBUF[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {MD_IN[0]} {MD_IN[1]} {MD_IN[2]} {MD_IN[3]} {MD_IN[4]} {MD_IN[5]} {MD_IN[6]} {MD_IN[7]} {MD_IN[8]} {MD_IN[9]} {MD_IN[10]} {MD_IN[11]} {MD_IN[12]} {MD_IN[13]} {MD_IN[14]} {MD_IN[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {MD_OUT[0]} {MD_OUT[1]} {MD_OUT[2]} {MD_OUT[3]} {MD_OUT[4]} {MD_OUT[5]} {MD_OUT[6]} {MD_OUT[7]} {MD_OUT[8]} {MD_OUT[9]} {MD_OUT[10]} {MD_OUT[11]} {MD_OUT[12]} {MD_OUT[13]} {MD_OUT[14]} {MD_OUT[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 3 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {VC_OBUF[0]} {VC_OBUF[1]} {VC_OBUF[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 23 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {cpu_board/UA_CPU[1]} {cpu_board/UA_CPU[2]} {cpu_board/UA_CPU[3]} {cpu_board/UA_CPU[4]} {cpu_board/UA_CPU[5]} {cpu_board/UA_CPU[6]} {cpu_board/UA_CPU[7]} {cpu_board/UA_CPU[8]} {cpu_board/UA_CPU[9]} {cpu_board/UA_CPU[10]} {cpu_board/UA_CPU[11]} {cpu_board/UA_CPU[12]} {cpu_board/UA_CPU[13]} {cpu_board/UA_CPU[14]} {cpu_board/UA_CPU[15]} {cpu_board/UA_CPU[16]} {cpu_board/UA_CPU[17]} {cpu_board/UA_CPU[18]} {cpu_board/UA_CPU[19]} {cpu_board/UA_CPU[20]} {cpu_board/UA_CPU[21]} {cpu_board/UA_CPU[22]} {cpu_board/UA_CPU[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 16 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {cpu_board/UD_CPU_in[0]} {cpu_board/UD_CPU_in[1]} {cpu_board/UD_CPU_in[2]} {cpu_board/UD_CPU_in[3]} {cpu_board/UD_CPU_in[4]} {cpu_board/UD_CPU_in[5]} {cpu_board/UD_CPU_in[6]} {cpu_board/UD_CPU_in[7]} {cpu_board/UD_CPU_in[8]} {cpu_board/UD_CPU_in[9]} {cpu_board/UD_CPU_in[10]} {cpu_board/UD_CPU_in[11]} {cpu_board/UD_CPU_in[12]} {cpu_board/UD_CPU_in[13]} {cpu_board/UD_CPU_in[14]} {cpu_board/UD_CPU_in[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 16 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {cpu_board/UD_CPU_out[0]} {cpu_board/UD_CPU_out[1]} {cpu_board/UD_CPU_out[2]} {cpu_board/UD_CPU_out[3]} {cpu_board/UD_CPU_out[4]} {cpu_board/UD_CPU_out[5]} {cpu_board/UD_CPU_out[6]} {cpu_board/UD_CPU_out[7]} {cpu_board/UD_CPU_out[8]} {cpu_board/UD_CPU_out[9]} {cpu_board/UD_CPU_out[10]} {cpu_board/UD_CPU_out[11]} {cpu_board/UD_CPU_out[12]} {cpu_board/UD_CPU_out[13]} {cpu_board/UD_CPU_out[14]} {cpu_board/UD_CPU_out[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 16 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {cpu_board/vid_addr_counter[0]} {cpu_board/vid_addr_counter[1]} {cpu_board/vid_addr_counter[2]} {cpu_board/vid_addr_counter[3]} {cpu_board/vid_addr_counter[4]} {cpu_board/vid_addr_counter[5]} {cpu_board/vid_addr_counter[6]} {cpu_board/vid_addr_counter[7]} {cpu_board/vid_addr_counter[8]} {cpu_board/vid_addr_counter[9]} {cpu_board/vid_addr_counter[10]} {cpu_board/vid_addr_counter[11]} {cpu_board/vid_addr_counter[12]} {cpu_board/vid_addr_counter[13]} {cpu_board/vid_addr_counter[14]} {cpu_board/vid_addr_counter[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 16 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {cpu_board/vid_shift_reg[0]} {cpu_board/vid_shift_reg[1]} {cpu_board/vid_shift_reg[2]} {cpu_board/vid_shift_reg[3]} {cpu_board/vid_shift_reg[4]} {cpu_board/vid_shift_reg[5]} {cpu_board/vid_shift_reg[6]} {cpu_board/vid_shift_reg[7]} {cpu_board/vid_shift_reg[8]} {cpu_board/vid_shift_reg[9]} {cpu_board/vid_shift_reg[10]} {cpu_board/vid_shift_reg[11]} {cpu_board/vid_shift_reg[12]} {cpu_board/vid_shift_reg[13]} {cpu_board/vid_shift_reg[14]} {cpu_board/vid_shift_reg[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 3 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {lisa_hdmi_output/bit_counter[0]} {lisa_hdmi_output/bit_counter[1]} {lisa_hdmi_output/bit_counter[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 3 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {lisa_hdmi_output/bit_index[0]} {lisa_hdmi_output/bit_index[1]} {lisa_hdmi_output/bit_index[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 16 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {lisa_hdmi_output/byte_counter[0]} {lisa_hdmi_output/byte_counter[1]} {lisa_hdmi_output/byte_counter[2]} {lisa_hdmi_output/byte_counter[3]} {lisa_hdmi_output/byte_counter[4]} {lisa_hdmi_output/byte_counter[5]} {lisa_hdmi_output/byte_counter[6]} {lisa_hdmi_output/byte_counter[7]} {lisa_hdmi_output/byte_counter[8]} {lisa_hdmi_output/byte_counter[9]} {lisa_hdmi_output/byte_counter[10]} {lisa_hdmi_output/byte_counter[11]} {lisa_hdmi_output/byte_counter[12]} {lisa_hdmi_output/byte_counter[13]} {lisa_hdmi_output/byte_counter[14]} {lisa_hdmi_output/byte_counter[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 12 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {lisa_hdmi_output/cx[0]} {lisa_hdmi_output/cx[1]} {lisa_hdmi_output/cx[2]} {lisa_hdmi_output/cx[3]} {lisa_hdmi_output/cx[4]} {lisa_hdmi_output/cx[5]} {lisa_hdmi_output/cx[6]} {lisa_hdmi_output/cx[7]} {lisa_hdmi_output/cx[8]} {lisa_hdmi_output/cx[9]} {lisa_hdmi_output/cx[10]} {lisa_hdmi_output/cx[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 11 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {lisa_hdmi_output/cy[0]} {lisa_hdmi_output/cy[1]} {lisa_hdmi_output/cy[2]} {lisa_hdmi_output/cy[3]} {lisa_hdmi_output/cy[4]} {lisa_hdmi_output/cy[5]} {lisa_hdmi_output/cy[6]} {lisa_hdmi_output/cy[7]} {lisa_hdmi_output/cy[8]} {lisa_hdmi_output/cy[9]} {lisa_hdmi_output/cy[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 4 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {lisa_hdmi_output/end_line_overlap_counter[0]} {lisa_hdmi_output/end_line_overlap_counter[1]} {lisa_hdmi_output/end_line_overlap_counter[2]} {lisa_hdmi_output/end_line_overlap_counter[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 2 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {lisa_hdmi_output/hsync_delay_counter[0]} {lisa_hdmi_output/hsync_delay_counter[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 10 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {lisa_hdmi_output/lisa_x[0]} {lisa_hdmi_output/lisa_x[1]} {lisa_hdmi_output/lisa_x[2]} {lisa_hdmi_output/lisa_x[3]} {lisa_hdmi_output/lisa_x[4]} {lisa_hdmi_output/lisa_x[5]} {lisa_hdmi_output/lisa_x[6]} {lisa_hdmi_output/lisa_x[7]} {lisa_hdmi_output/lisa_x[8]} {lisa_hdmi_output/lisa_x[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 10 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {lisa_hdmi_output/lisa_y[0]} {lisa_hdmi_output/lisa_y[1]} {lisa_hdmi_output/lisa_y[2]} {lisa_hdmi_output/lisa_y[3]} {lisa_hdmi_output/lisa_y[4]} {lisa_hdmi_output/lisa_y[5]} {lisa_hdmi_output/lisa_y[6]} {lisa_hdmi_output/lisa_y[7]} {lisa_hdmi_output/lisa_y[8]} {lisa_hdmi_output/lisa_y[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 4 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {lisa_hdmi_output/start_line_overlap_counter[0]} {lisa_hdmi_output/start_line_overlap_counter[1]} {lisa_hdmi_output/start_line_overlap_counter[2]} {lisa_hdmi_output/start_line_overlap_counter[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 16 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {lisa_hdmi_output/word_index[0]} {lisa_hdmi_output/word_index[1]} {lisa_hdmi_output/word_index[2]} {lisa_hdmi_output/word_index[3]} {lisa_hdmi_output/word_index[4]} {lisa_hdmi_output/word_index[5]} {lisa_hdmi_output/word_index[6]} {lisa_hdmi_output/word_index[7]} {lisa_hdmi_output/word_index[8]} {lisa_hdmi_output/word_index[9]} {lisa_hdmi_output/word_index[10]} {lisa_hdmi_output/word_index[11]} {lisa_hdmi_output/word_index[12]} {lisa_hdmi_output/word_index[13]} {lisa_hdmi_output/word_index[14]} {lisa_hdmi_output/word_index[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list _AS]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list _clr_vid_clk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list _HSYNC_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list cpu_board/_RSTHLT_555]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list _VSYNC_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list CPU_ROM_SEL_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list READ]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list VA_overflow]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list cpu_board/vid_addr_clk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list cpu_board/vid_addr_clr]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list VID_int]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list cpu_board/vid_shift_out]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list cpu_board/vid_shift_out_ff]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list cpu_board/VIDEO]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list io_board/WCNT]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets lisa_dotck_ungated]
