# LisaFPGA Desktop PCB Rev. 3 Changelog
- First public release version of the LisaFPGA board
- Swapped RX/TX and DSR/DTR on the CP2102N to SCC serial link; both pairs were connected backwards
- Fixed CP2102N/Serial B mux connections; they were all messed up thanks to the above
- Added a framerate (30FPS or 60FPS) select jumper for the HDMI output
- Added pullups on all jumpers to give them default states in case the user doesn't have a jumper installed
- Replaced all LED pots with properly-valued resistors based on Rev. 2 brightness testing
- Corrected orientation of all silkscreens for aesthetic purposes
- Increased the size of the ESFloppy OLED from 0.96" to 1.3", the same size as the Floppy Emu
- Removed the PSU disconnect jumper for the 12V supply added on Rev. 2