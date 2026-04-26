## The XDC file for the LisaFPGA Desktop board. There are a whole lot of pins defined in here!
## As well as some allowing of combinatorial loops, which we have to do thanks to the Lisa's architecture.

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {cpu_board/BD_out[*]}]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/_BUST_latched]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets cpu_board/_BUST_latched_inferred_i_1]
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

## Tell Vivado that our SPI configuration flash bus is 4 bits wide to maximize bitstream loading speed at boot
## It should be about 4x faster than the default 1x configuration; almost instantaneous
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## Make sure Vivado knows about synchronizers we have in the design to avoid timing issues
## If we don't do this, Vivado will think we have timing violations on these paths, when in fact we don't
## The literal purpose of these paths is to fix the timing violations caused by clock domain crossings!
## False-path into the first stage of the HDMI reset synchronizer
## The whole point of the synchronizer is to get reset from the DOTCK domain into the clk_pixel domain
## So we need to tell Vivado to relax and ignore the timing violations on the synchronizer's first stage since we're already handling it
set_false_path -to [get_cells lisa_hdmi_output/_reset_hdmi_int_reg]
## False-path into the first stage of the I/O board reset synchronizer
set_false_path -to [get_cells io_board/_RESET_int_reg]
## False-path into the first stage of the USB reset synchronizer
set_false_path -to [get_cells usbrst_sync_reg]
## False-path into the first stage of the I/O board AS synchronizer
set_false_path -to [get_cells io_board/_AS_sync_reg]
## False-path into the INTIO synchronizer on the I/O board; ignore it because the synchronizer once again handles the DOTCK-to-C16M CDC
set_false_path -to [get_cells io_board/_INTIO_sync_reg]
## Another false path for A and BD_in on the I/O board
## They're not synchronized but we don't care because AS is, and AS is what controls when the data gets latched
set_false_path -from [get_ports {io_board/A[*]}] -to [get_cells {io_board/A_latched_reg[*]}]
set_false_path -from [get_ports {io_board/BD_in[*]}] -to [get_cells {io_board/RD_in_reg[*]}]

## Here's another false path for the system ON signal
## This goes into the DOTCK BUFGCTRL and serves as the clock enable
## The signal comes from the COP, but the timing analyzer thinks it's heading to the DOTCK domain, when in reality it's just enabling the clock
set_false_path -to [get_pins lisa_dotck_bufg/CE0]
## Same for C16M
set_false_path -to [get_pins C16M_bufg/CE0]

## Another ON-related false path: the blank_video signal that goes into the HDMI_Interface
## This blanks the video when Lisa is off and is literally just the ON signal, but once again we have a CDC issue between COPCK and clk_pixel
## There's a synchronizer on the HDMI_Interface side, but we still need to declare the false path to avoid timing violations
set_false_path -to [get_cells lisa_hdmi_output/blank_video_int_reg]

## Jeez, these COP-related signals sure suck; here's another false path from the COP
## This is for the NMI that runs from the COP (COPCK_2x domain) to the 68K (DOTCK domain)
set_false_path -through [get_nets io_board/cop421/core_b/io_g_b/_NMI_COP] -to [get_cells {cpu_board/M68K/rIpl_reg[*]}]

# The interrupt line going from the floppy disk controller to the 68K has the same problem; it crosses from the C16M to the DOTCK domain
set_false_path -through [get_cells {io_board/lower_FDC_latch/Q_reg[7]}] -to [get_cells {cpu_board/M68K/rIpl_reg[*]}]

## This false path is for the _RSTSW signal going to the CPU board; it consists of both the RSTSW and the rising edge of ON
## So obviously the CDC of ON is the problem here; I have a synchronizer to fix it though, so we just need to declare the false path here
set_false_path -through [get_nets cpu_board/_RSTSW] -to [get_cells {cpu_board/rst_counter_reg[*]}]
## Another one for the same _RSTSW signal, just to a different destination on the CPU board
set_false_path -through [get_nets cpu_board/_RSTSW] -to [get_cells cpu_board/fast_reset_reg]
## And another...
set_false_path -through [get_nets cpu_board/_RSTSW] -to [get_cells cpu_board/_RSTHLT_555_reg]

## Here's a false path between the 6522 and the COP for our extended-length DDRA data strobe signal
## I'm synchronizing this signal into the COPCK_2x domain, so we just need to declare a false path into the synchronizer
set_false_path -to [get_cells io_board/KBD_via_DDRA_extended_int_reg]

## The CONT register on the I/O board is clocked by the DOTCK, but we read the contrast in the 1080p30/60 domain
## We don't really care about this CDC violation though since worst case, there's a tiny video glitch for a pixel or two during a single frame
## So declare a false path for it
set_false_path -from [get_cells {io_board/CONT_reg[*]}] -to [get_cells {lisa_hdmi_output/rgb_reg[*]}]

## There's an annoying DRC rule during implementation that gives us an error if we try to drive 3 or more MMCMs from one IBUF
## You can do it, but the MMCMs have to placed in certain places relative to the IBUF, which doesn't work out for us
## So to get around this, we tell Vivado to ignore the rule for our sysclk
## This would be bad for a clock that was actively clocking a ton of logic, but since we're only using this clock to feed MMCMs, it's fine
## The MMCMs will get rid of any skew that would be generated by this violation anyway
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sysclk_ibuf]
## Yet another annoying rule exists for the BUFGMUX/BUFGCTRL primitives used for clock muxing
## If you daisy-chain muxes, they have to be placed adjacent to each other in the same CMT column, but we have 3 of them and it's impossible
## So we again tell Vivado to ignore the rule for our dot clock nets; it's fine once again since nobody cares if the intermediate clocks have skew
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets dotck_A]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets dotck_B]

## Based on the pins we used for our HDMI output, the OSERDES primitives for TMDS encoding are in a particular part of the FPGA
## And to avoid violating some design rules, we have to put the MMCM that feeds the OSERDES in that same part (X0Y2)
## But by default, Vivado tries to put the primary clock divider MMCM there instead, so force it into X0Y0 and put our HDMI MMCM in X0Y2
set_property LOC MMCME2_ADV_X0Y2 [get_cells lisa_hdmi_output/hdmi_clock_generator/inst/mmcm_adv_inst]
set_property LOC MMCME2_ADV_X0Y0 [get_cells primary_clock_divider/inst/mmcm_adv_inst]

## We also need to declare some false paths related to our clock muxing
## This is because only one of the clocks is actually active at a time, so timing analysis between the 4 dot clocks is pointless
set_false_path -from [get_clocks dotck_80M_dotck_mmcm] -to [get_clocks dotck_20M_dotck_mmcm]
set_false_path -from [get_clocks dotck_80M_dotck_mmcm] -to [get_clocks dotck_40M_dotck_mmcm]
set_false_path -from [get_clocks dotck_80M_dotck_mmcm] -to [get_clocks dotck_60M_dotck_mmcm]
set_false_path -from [get_clocks dotck_20M_dotck_mmcm] -to [get_clocks dotck_80M_dotck_mmcm]
set_false_path -from [get_clocks dotck_20M_dotck_mmcm] -to [get_clocks dotck_40M_dotck_mmcm]
set_false_path -from [get_clocks dotck_20M_dotck_mmcm] -to [get_clocks dotck_60M_dotck_mmcm]
set_false_path -from [get_clocks dotck_40M_dotck_mmcm] -to [get_clocks dotck_80M_dotck_mmcm]
set_false_path -from [get_clocks dotck_40M_dotck_mmcm] -to [get_clocks dotck_20M_dotck_mmcm]
set_false_path -from [get_clocks dotck_40M_dotck_mmcm] -to [get_clocks dotck_60M_dotck_mmcm]
set_false_path -from [get_clocks dotck_60M_dotck_mmcm] -to [get_clocks dotck_80M_dotck_mmcm]
set_false_path -from [get_clocks dotck_60M_dotck_mmcm] -to [get_clocks dotck_20M_dotck_mmcm]
set_false_path -from [get_clocks dotck_60M_dotck_mmcm] -to [get_clocks dotck_40M_dotck_mmcm]

## It's also impossible to go between the 1080p30 and 1080p60 pixel clocks (and x5 pixel clocks), so set false paths for them too
set_false_path -from [get_clocks clk_pixel_1080p30] -to [get_clocks clk_pixel_1080p60]
set_false_path -from [get_clocks clk_pixel_1080p60] -to [get_clocks clk_pixel_1080p30]
set_false_path -from [get_clocks clk_pixel_x5_1080p30] -to [get_clocks clk_pixel_x5_1080p60]
set_false_path -from [get_clocks clk_pixel_x5_1080p60] -to [get_clocks clk_pixel_x5_1080p30]

## Another HDMI-related thing: we need to set false paths for the select signals going into the HDMI clock muxes
## We don't care about the timing on this signal since it's only used to select which clock goes to the HDMI output
## And this will only be changed very occasionally by the user
## Plus, it doesn't matter if it glitches and takes a few cycles to stabilize; who cares if a single frame gets corrupted during the switch
set_false_path -to [get_pins lisa_hdmi_output/bufgmux_clk_pixel/CE0]
set_false_path -to [get_pins lisa_hdmi_output/bufgmux_clk_pixel/CE1]
set_false_path -to [get_pins lisa_hdmi_output/bufgmux_clk_pixel_x5/CE0]
set_false_path -to [get_pins lisa_hdmi_output/bufgmux_clk_pixel_x5/CE1]

## Create a constraint for our 48KHz audio clock
## This is important because we generate it in the logic world, and then move it to a clock net with a BUFG
create_generated_clock -name clk_audio -source [get_pins lisa_hdmi_output/hdmi_clock_generator/CLKOUT3] -period 20833.333 [get_pins lisa_hdmi_output/buf_audio/O]

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
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports SCANLINES]
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
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {GPIO[0]}]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports {GPIO[1]}]
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports {GPIO[2]}]
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports {GPIO[3]}]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {GPIO[4]}]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {GPIO[5]}]

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

connect_debug_port u_ila_0/probe3 [get_nets [list io_board/DIS]]





connect_debug_port u_ila_0/probe0 [get_nets [list {io_board/PD_out[0]} {io_board/PD_out[1]} {io_board/PD_out[2]} {io_board/PD_out[3]} {io_board/PD_out[4]} {io_board/PD_out[5]} {io_board/PD_out[6]} {io_board/PD_out[7]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list {io_board/pp_via/addr[0]} {io_board/pp_via/addr[1]} {io_board/pp_via/addr[2]} {io_board/pp_via/addr[3]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list {io_board/SD_in[0]} {io_board/SD_in[1]} {io_board/SD_in[2]} {io_board/SD_in[3]} {io_board/SD_in[4]} {io_board/SD_in[5]} {io_board/SD_in[6]} {io_board/SD_in[7]}]]
connect_debug_port u_ila_0/probe9 [get_nets [list _BSY]]
connect_debug_port u_ila_0/probe10 [get_nets [list io_board/_CMD]]
connect_debug_port u_ila_0/probe11 [get_nets [list io_board/_CMD_ungated]]
connect_debug_port u_ila_0/probe12 [get_nets [list io_board/_PARITY]]
connect_debug_port u_ila_0/probe13 [get_nets [list _ProFile_EN]]
connect_debug_port u_ila_0/probe14 [get_nets [list io_board/_ProFile_EN]]
connect_debug_port u_ila_0/probe15 [get_nets [list io_board/_PSTRB]]
connect_debug_port u_ila_0/probe17 [get_nets [list io_board/DR_W]]
connect_debug_port u_ila_0/probe18 [get_nets [list io_board/OCD]]
connect_debug_port u_ila_0/probe19 [get_nets [list io_board/OCD_ungated]]
connect_debug_port u_ila_0/probe20 [get_nets [list io_board/PR_W_ungated]]

