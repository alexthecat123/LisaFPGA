# LisaFPGA
The Apple Lisa computer implemented inside an FPGA!

<img width="1280" height="720" alt="IMG_4056" src="https://github.com/user-attachments/assets/5dabf7c8-afa6-4504-9d14-0c4098c217ed" />

# Start Here
Here are some links to different parts of this document depending on what you want to do:
- [I bought a board and want to learn how to use it.](#using-it)
- [I need to update my board's firmware.](#programmingupdating-the-firmware)
- [I want to buy a board or fabricate my own PCBs.](#buying-or-building-a-board)
- [I want to learn how to build the LisaFPGA code from source.](#building-the-code-yourself)
- [I need troubleshooting help.](https://github.com/alexthecat123/LisaFPGA/FAQ.md)

# Table of Contents
- [Introduction](#introduction)
- [Hardware](#hardware)
- [Buying or Building a Board](#buying-or-building-a-board)
- [Programming/Updating the Firmware](#programmingupdating-the-firmware)
- [Using It](#using-it)
- [Building the Code Yourself](#building-the-code-yourself)
- [Dev Notes](#dev-notes)
- [Future Enhancements](#future-enhancements)
- [Contact Me!](#contact-me)
- [Changelog](#changelog)
- [Appendix - Jumpers, Switches, Buttons, and LEDs](#appendix---jumpers-switches-buttons-and-leds)

# Introduction
Ever since taking an introductory FPGA class 2 years ago during undergrad, I've had a fascination with FPGAs and their incredible versatility. I wanted to do some sort of project that furthered my knowledge of FPGAs, so I decided to do something that fused FPGAs with another big interest of mine, the Lisa. And now, 9 months later, we have a fully functional Lisa running inside an FPGA, complete with a ton of modernizations that make it easier to use in the 21st century!

## Features
- Hardware emulation of a Lisa 1 or 2/5.
- Low ~2.8W power consumption; can run for about 14-18 hours off a standard 10,000mAh USB power bank.
- All the same I/O as the original Lisa, minus the expansion slots.
- 2MB of RAM, configurable at runtime to anything from 512K up to 2MB.
- On-the-fly overclocking up to 3.75x the original Lisa's speed.
- Video and audio output over 1080p HDMI.
- Onboard speaker if your HDMI monitor doesn't have one.
- USB keyboard/mouse support (although you can use original Lisa ones too if you want).
- Onboard ProFile hard disk emulation thanks to an integrated [ESProFile](https://github.com/alexthecat123/ESProFile).
- Onboard ESP32-based floppy drive emulation (NOTE: THIS DOESN'T WORK YET).
- External ProFile and floppy drive support as well.
- Serial B can be rerouted to the USB-C port so you can communicate with the Lisa directly over USB.
- On-the-fly ROM switching between H (rectangular pixels) and 3A (square pixels) CPU board ROMs.
- Supports Twiggy drives with an optional breakout board. Note that this is CURRENTLY UNTESTED as I don't have a set of Twiggy drives, but I'm working on borrowing a Lisa 1 for testing in the near future.
- Fully open-source; feel free to modify the design however you want!

# Hardware
The LisaFPGA hardware consists of a custom 6-layer PCB based around a Xilinx Artix 7 100T FPGA. The PCB is powered via USB-C and has onboard switching regulators for generating the rather absurd number of voltages that we need. In addition to the 5V from USB, we need -12V, -5V, 1V, 1.8V, 3.3V, and 12V. That's a LOT of regulators!!!

There's also an onboard CH334 USB hub that breaks the USB-C connection out into 4 separate USB-C interfaces. One goes to an FT232 for programming the FPGA over JTAG, two go to the two ESP32s (ESProFile and the yet-to-be-developed floppy emulator), and the final one goes to a CP2102N that allows for Serial B to be rerouted over the USB-C port.

The Lisa's RAM is NOT housed within the FPGA; it's stored in an external 2MB SRAM IC that sits next to the FPGA on the board.

No separate control ICs are necessary for either the HDMI port or the USB keyboard/mouse ports; they simply connect straight to the FPGA and the FPGA implements all of the necessary hardware internally.

The onboard speaker uses the exact same audio amplifier circuit as the original Lisa (minus the output transistors), so it should work and sound as similar to the original machine as possible.

Rev. 3 of the board also contains a socket for a real 8530 SCC chip for controlling the serial ports. This is because a SystemVerilog SCC core didn't exist at the time at which the board was designed. But one exists now, so the socket is empty on Rev. 3 boards and nonexistent on subsequent revisions!

The hardware is way too complicated to cover in detail here, but feel free to check out the schematics in the ```hardware``` directory for more info.

For more info on the actual HDL code running on the FPGA, check the [Dev Notes](#dev-notes) section later on.

# Buying or Building a Board
## Buying a Board
I offer LisaFPGA boards for sale through both [MacEffects](https://maceffects.com/products/lisafpga) and [Joe's Computer Museum](https://jcm-1.com/product/lisafpga/). The boards are listed for $350 apiece on both sites; the choice of who to buy from purely comes down to who you prefer to do business with.

These boards are pretty popular and there's a several-week lead time on each batch that I fabricate, so there's a good chance that they'll frequently be out of stock, especially at first. Hopefully this will get better as we get later into 2026 and demand starts to drop!

If you bought a board and you see a big empty socket near the top-center, then don't worry; you have a Rev. 3 board where it's empty by design! You're not missing any parts, and future revisions get rid of the socket entirely.

## Building Your Own
If you want to fabricate/assemble your own batch of boards through a PCB manufacturing service, then that's absolutely an option as well! It isn't particularly hard, and I'll walk you through it here. Just keep in mind that it's very expensive to purchase these boards in small quantities thanks to the large fixed production costs, which go down a lot when you buy in bulk. So you'll probably be looking at $500-ish apiece with a minimum order quantity of 2 ($1000 total) if you fabricate your own versus $350 if you just buy one from one of my bulk orders.

I use [JLCPCB](https://jlcpcb.com/) for all of my PCB orders, and I'd highly recommend that you do the same. Especially for this project; the entire bill of materials is tailored to what JLC normally stocks, and the PCB's trace spacings/widths for impedance matching were designed to match one of JLC's board stackups.

Let's walk through the whole process now, for both the main LisaFPGA board and the Twiggy breakout (if applicable for you).

### LisaFPGA Main Board
Go to [the JLCPCB site](https://jlcpcb.com/), click Order Now, and then click the Add Gerber File button. Select the Gerber files for the LisaFPGA board that you want to fabricate; this is going to be the zip file in the ```hardware/lisafpga_desktop/rev_X``` directory, where ```X``` is the revision number of the board that you want to make. You probably want to pick the board with the latest revision!

Once you've uploaded the Gerbers, it should look like this:

<img width="1728" height="935" alt="SCR-20260602-ukkw" src="https://github.com/user-attachments/assets/3716745b-c7d9-4011-b9b3-84aaa1c7e64e" />

Now there are a few options that we need to change before we move on to the next screen: three optional and two required.
- Optionally increase the quantity to more than 5 if you're rich and want tons and tons of these things.
- Optionally change the board color to something other than green.
- Optionally expedite the PCB fabrication time, although this is really expensive and not at all worth it in my opinion.
- Change Specify Stackup to Yes and then choose JLC06161H-3313. If it warns you that the thickness isn't exactly 1.6mm, then just proceed; that's perfectly fine.
- Choose 0.25mm/(0.35/0.4mm) for the Min Via Hole Size/Diameter.

Leave everything else at the defaults unless you know what you're doing. Once you've made all these changes, the settings should look like this:

<img width="1728" height="935" alt="SCR-20260602-uoky" src="https://github.com/user-attachments/assets/573a64da-3e47-408b-a740-e3f478e50d0f" />

That's all of the configuration for the PCB fabrication itself; now we just need to tell them how to assemble all of the components onto the board. Start by scrolling down to the bottom of the page and turning on the switch for PCB Assembly.

Now make the following changes to the PCB assembly settings:
- Change the PCBA Type to Standard.
- Change the Assembly Side to Both Sides.
- Set the PCBA Qty to however many of the boards you actually want them to assemble. The minimum is 2 and the maximum is however many boards you asked them to manufacture earlier. Any boards that you asked them to manufacture but not assemble will just be shipped to you bare.

Once again, leave everything else alone unless you know what you're doing. At this point, the page should look like this:

<img width="1728" height="929" alt="SCR-20260603-bawz" src="https://github.com/user-attachments/assets/daead7f9-f5a7-4db4-bdba-d49ce25d373b" />

Now hit Next and you'll see a preview of the bare board. I have no clue what the purpose of this page is given that we already had a preview on the last page; just hit Next again to move to a page that asks you to upload BOM and CPL files that contain info about what components are on the board and where they go.

<img width="1728" height="925" alt="SCR-20260603-bbxu" src="https://github.com/user-attachments/assets/db68b64c-2fe8-4446-95df-70601f68d9af" />

Go ahead and upload those two files as requested; they're both in the ```hardware/lisafpga_desktop/rev_X``` directory, with the BOM file literally having "bom" in the name, and the CPL file having "pick_and_place" in the name. Once they're uploaded, hit the Process BOM & CPL button to move on.

Once the BOM and pick-and-place files have been processed, you'll be presented with a list of all of the components on the board, how many are required for your order, their total cost, and whether or not their stock of any part is too low (inventory shortage).

<img width="1728" height="894" alt="SCR-20260603-bedw" src="https://github.com/user-attachments/assets/c1ce6908-89e9-46ea-b65f-b9bed0b7a506" />

First, just go through the list and make sure that any parts that do NOT have an inventory shortage have their boxes checked. All of them should be checked by default, but I've noticed that the J20/SW13/etc one sometimes needs to be checked manually.

If there is an inventory shortage of any part, just click the part and you'll see some detailed info about it. Then go to the Search Part tab to find a suitable replacement, select it, and proceed with the replacement part.

<img width="1237" height="651" alt="SCR-20260603-bgbd" src="https://github.com/user-attachments/assets/b61d94d4-00ef-4b15-9437-af1577d965d0" />

<img width="1168" height="788" alt="SCR-20260603-bgec" src="https://github.com/user-attachments/assets/be5a2983-8e5e-4501-a4ca-2b7d9919eccd" />

Once you've confirmed that all of your parts are the way they should be, hit Next and you'll come to a 3D rendering of the board with all of the components populated on it. Everything should be okay, but just take a minute or two to pan across the board (both top and bottom) to make sure that all the components look to be installed properly; it's always a good idea with such an expensive order. Don't worry about the crystal on the bottom of the board underneath the FPGA being on there backwards; I think it's just by nature of the footprint being mirrored on the bottom of the board and their engineers catch and correct this every time.

<img width="1728" height="826" alt="SCR-20260603-bhra" src="https://github.com/user-attachments/assets/7953f3fc-03ad-4cc4-b2e2-3c7459219da9" />

After you're content with the placement of everything, hit Next again. If a popup appears saying something about confirming parts placement, just hit okay; this means that you'll get an email after their engineers have reviewed your layout where you'll need to confirm any changes that they made to the component placement. This is really easy though; you just click the link in the email, look at the 3D view of the boards, and then choose the Yes option.

Once you've dismissed that popup (if it appeared), you'll get to see how much the whole order costs. Get ready for an expensive shock! Read over the summary, choose literally anything for the Product Description, optionally choose to expedite assembly if it lets you and you want to, and then hit Save to Cart.

<img width="1728" height="878" alt="SCR-20260603-bjdd" src="https://github.com/user-attachments/assets/bc544d14-377d-40a8-98fa-f96b40136631" />

After it's in your cart, you can proceed to checkout as you would on any other website. Just be warned: once you proceed to checkout, your cart will be emptied, so you'll lose your entire order and have to start over if you start to check out, change your mind, and then head back to your cart. Pretty annoying; I've done this more times than I'd care to admit!

These are 6-layer boards with quite a lot of components on them, so they're not particularly quick or simple to fabricate and assemble. Give JLC about 2 weeks (or maybe a little more) to finish making them and putting them together, and then another week for shipping after that.

Once you have the boards in the mail, there's one other thing you'll need: [some jumpers](https://www.amazon.com/California-JOS-Standard-Circuit-Connection/dp/B0BRK36G33) for all of the configuration jumper blocks on the board. Head on down to the [Appendix](#appendix---jumpers-switches-buttons-and-leds) to learn how to install and configure them.

Note that, if you have a Rev. 3 board with a big DIP-40 socket at U28, you should NOT install anything into the socket because it will cause signal contention with the FPGA. The socket is left over from when I was going to use a real external SCC chip for controlling the serial ports, but now the SCC is implemented inside the FPGA and the socket isn't needed anymore. Revisions after Rev. 3 don't even have it.

### Twiggy Breakout Board
If you're one of the lucky few people who happens to own a set of Twiggy drives that you'd like to connect to your LisaFPGA board, then you'll want to fabricate some Twiggy breakouts too. Luckily, these are really cheap!

Note that the Twiggy breakouts are currently untested since I'm not lucky enough to own any Twiggy drives. But I'll be borrowing someone's Lisa 1 in the near future to get some test data and fix anything that's broken. Just keep in mind that the current board revision may not work; use it at your own risk!

The process is nearly identical to the process for the main LisaFPGA boards, except that you should use the files in ```hardware/twiggy_breakout/rev_X```, where X is the latest version number that's available in the directory. 

The nice thing about the Twiggy breakouts is that you don't need to select a bunch of custom options like you did for the main LisaFPGA boards. They're really simple and can be manufactured using the default settings on everything. The only things that you may be interested in changing are:
- The number of PCBs you want manufactured.
- The color of the PCBs.
- How many of the PCBs you want them to assemble.

You'll also need the appropriate IDC cables to connect the breakout to the LisaFPGA board and to your drives. Here are the cables you need and Amazon links to each one:
- [1x 6-pin (2x3)](https://www.amazon.com/FOCMKEAS-Connector-Ribbon-Length-2-54mm/dp/B0F3DHFFT5)
- [1x 20-pin (2x10)](https://www.amazon.com/FOCMKEAS-Connector-Ribbon-Length-2-54mm/dp/B0F3DDQTPK)
- [2x 26-pin (2x13)](https://www.amazon.com/FOCMKEAS-Connector-Ribbon-Length-2-54mm/dp/B0F3DFR3ZY)

Note that each of those links is for five cables, so you only need to order one of each, despite the fact that you need two of the 26-pin cables.

Alternatively, if you want to build your own cables, [here's a DigiKey list](https://www.digikey.com/en/mylists/list/7JY9404QK4) with all the parts in it to build a set.

# Programming/Updating the Firmware
This section applies to both people who bought a ready-to-go board AND people who fabricated their own boards.

If you bought a ready-to-go board, you don't need to do this immediately because the board will come pre-programmed, but you'll probably want to do it in the future when I release updates for the FPGA, ESProFile, and yet-to-be-implemented ESFloppy firmware.

If you fabricated your own boards, then of course they'll come blank, so you'll need to program everything before the board can be used.

Either way, the process is identical, automated, and works on both macOS and Linux. The automated process does NOT work on Windows, so if you're running Windows, then this is your cue to finally make the switch to Linux!

All you've got to do is open a Terminal on either macOS or Linux, use the ```cd``` command to move to the LisaFPGA directory, and then run the program_board.sh script.

So assuming the LisaFPGA repo is in my Downloads folder, here's what this looks like:
```
cd ~/Downloads/LisaFPGA-main/
./program_board.sh
```

Of course, make sure that you have your board plugged into your computer and powered on before you run the script! This script will automatically install all the necessary dependencies and do the following things to your board:
- Programs the FT232H with the proper identity information to appear as a USB-to-JTAG interface.
- Programs the CP2102N USB to serial chip with the name "LisaFPGA Serial B" to make it easy to identify when connecting to the Lisa's serial port.
- Downloads the latest ESProFile firmware from its GitHub repo and uploads it to the onboard ESProFile.
- Writes placeholder ESFloppy firmware to the onboard ESFloppy that displays a "this feature unimplemented" message on the OLED.
- Writes the LisaFPGA FPGA bitstream into the FPGA's configuration flash.

If the script fails while programming any component of the board, just turn the board off and back on and then run the script again. I've seen this happen on rare occasions.

Once the script says that it's done, turn your board off and back on again, and it should be ready to use. To learn how to use it, keep on reading!

# Using It
## Initial Setup
### Required Parts
Using your LisaFPGA board is really easy! All you'll need to get up and running is:
- A USB-C cable and a computer, power brick, or USB power bank to supply power. You can get about 14-18 hours of battery life off a standard 10,000mAh power bank, depending on usage, what peripherals you have connected, and the quality of your power bank.
- A USB keyboard and mouse (or a real Lisa keyboard and mouse).
- An HDMI cable and an HDMI-compatible display of some kind.
- A microSD card for ESProFile hard disk emulation; any size is fine.
- (Optional) A real 400K or 800K floppy drive, Twiggy drive, or Floppy Emu if you want floppy disk capabilities. The onboard floppy emulator should hopefully remove the need for this once I get it going in the future.

### Configuring the ESProFile SD Card
This is really easy; just format the card as FAT32, extract the ```images.zip``` archive found in this repo, and copy all of the extracted files into the root of the card. This will set your ESProFile up with Tom Stepleton's Selector boot picker that lets you choose which OS to boot into when you start up the Lisa, as well as ready-to-go disk images for a variety of Lisa OSes.

Once your SD card is ready to go, stick it into the ESPROFILE SD slot at the top-right corner of the board.

<img width="1280" height="720" alt="IMG_4065" src="https://github.com/user-attachments/assets/ada1b77f-0277-4f4a-ba29-44deb718ee32" />

For more info on ESProFile, go check out [its GitHub repo](https://github.com/alexthecat123/ESProFile). Same goes for the Selector boot picker; it's got a whole user's manual [right here](https://github.com/stepleton/cameo/blob/master/aphid/selector/MANUAL.md)!

### Connecting Power and Peripherals
Plug your USB-C power cable into the USB port marked USB IN on the left edge of the board. The HDMI cable to your monitor goes into the HDMI port on the top edge of the board near the left.

Your keyboard and mouse ports (both USB and Lisa) are on the bottom edge of the board, also on the left. Plug your keyboard and mouse into the appropriate set of ports depending on whether you're using Lisa or USB peripherals. If you're using Lisa peripherals, then it obviously matters which one you plug the keyboard into and which one you plug the mouse into, but for USB it doesn't; plug either peripheral into either port.

Keep in mind that the board can be a bit picky when it comes to USB keyboard and mouse selection; there are certain ones that just won't work at all or will act weird. If this happens to you, just try another keyboard or mouse. I've had the best results with late 2000's and early 2010's peripherals, particularly the generic Dell and HP keyboards and mice that shipped with their machines, but plenty of other brands/models will work too. Modern gaming peripherals probably won't work, and neither will any keyboard that has a built-in USB hub.

<img width="1280" height="720" alt="IMG_4058" src="https://github.com/user-attachments/assets/a411373a-036a-49b3-bb60-b7b184c80f47" />

At this point, the board should be ready to turn on! But don't do that just yet; go read the [Appendix](#appendix---jumpers-switches-buttons-and-leds) to learn what all of the configuration jumpers and switches do so that you can set them to your liking before powering the board on.

## Turning Everything On
### Turning on the Board
To power up the board, flip on the POWER switch near the left edge of the board. It's right next to the USB-C port. You should see a few things happen here:
- A red power LED next to the power switch should come on immediately.
- ESProFile's status LED will light up red once it comes out of reset.
- The DONE LED will light up green after a few seconds once the FPGA has loaded its bitstream from SPI flash.
- Your monitor will display a black screen (the Lisa's actual display area) with a grey border around it.
- ESProFile's status LED will turn green once it detects the SD card, loads the default disk image, and presents itself as ready for the Lisa.
- Depending on your USB configuration, the ACT LEDs may or may not light up.

If the DONE LED never lights up, hit the PROGRAM button right next to it and wait a few seconds, or just power-cycle the whole board. I've seen this happen very occasionally.

If you don't get any HDMI output, or your display says that the current resolution isn't supported, try moving the HDMI FRAMERATE jumper to whatever position it's not in right now. Some displays are picky about this and can only display one framerate. If it works in both positions, you want to go with the 60FPS position!

There's also the possibility that your monitor just doesn't support 1080p, and if that's the case, then you'll need to switch to a 1080p-capable monitor. Most monitors won't have a problem with that though.

Once all of those things have happened, the board is ready for use! 

### Turning on the Lisa
To turn the Lisa on, just hit the LISA POWER button on the bottom edge of the board. You'll see a green power LED illuminate right below this button, and your display should come to life as the Lisa completes its self-test.

<img width="1920" height="1080" alt="H_ROM_Testing" src="https://github.com/user-attachments/assets/247ea3dc-d48e-480d-93f2-de24beb8214e" />

If your HDMI monitor has speakers, then you'll be able to hear it play the Lisa's audio and can disable the onboard speaker by moving the SPKR SEL jumper to the EXT position. Otherwise, you'll want the SPKR SEL jumper in the INT position to enable the onboard speaker.

The RESET and NMI buttons work just like their corresponding buttons on the back of a real Lisa; don't press them unless you know what you're doing because RESET will immediately reboot the computer without saving your work and NMI will do unpredictable things depending on the Lisa's state.

At this point, you can use the system just like a real Lisa!

## Day-to-Day Use
### Picking ESProFile Disk Images
When the Lisa boots from ESProFile, it boots into a program called the Selector that lets you pick which disk image you want to boot into. To boot into an image, use the arrow keys to highlight the particular image that you'd like, and then hit the ```B``` key to start booting. Go read [the Selector manual](https://github.com/stepleton/cameo/blob/master/aphid/selector/MANUAL.md) for details about all of the other (really awesome) features.

<img width="3840" height="2160" alt="SCR-20260607-mitb" src="https://github.com/user-attachments/assets/e5f613b6-99d7-4bf6-a1cc-1fb74f5144ee" />

Keep in mind that your image selection will persist until ESProFile is reset; simply turning the Lisa off and back on again will NOT bring you back to the Selector. To reset ESProFile and get back to the Selector, turn the Lisa off and then hit the RESET button right underneath the ESPROFILE text on the PCB. Once the ESProFile activity LED turns green again, you'll be ready to boot back into the Selector!

### ESFloppy - The Onboard Floppy Emulator
All of the hardware needed for an onboard ESP32-based floppy disk emulator is already populated on the board, but I don't have the code written to actually get the emulator working yet. So for now, it just doesn't do anything. If you press any of the ESFloppy interface buttons (LEFT, SEL, or RIGHT), the OLED display (which will display the available floppy disk images) will simply light up for a few seconds to tell you that the emulator is currently unimplemented, and the ESFloppy status LED right below the OLED will light up green.

### Using External Hard/Floppy Drives
To attach an external hard drive or Sony floppy drive, simply plug it into its corresponding port (the SONY FLOPPY DRIVE port for a floppy drive or the PROFILE CONNECTOR port for a ProFile) and flip the HARD DRIVE SOURCE and/or FLOPPY DRIVE SOURCE switches to the EXT position depending on which device you just connected. For floppy drives, make sure that the I/O ROM SEL switch is in the A8 position if you're using a Sony drive or if no drive is connected, or the 40 position if you're using Twiggy drives. Speaking of Twiggies, connecting a set of Twiggy drives to your LisaFPGA board requires some extra steps; read the next section to learn more.

### Twiggy-Specific Stuff
If you have a Twiggy breakout and a set of Twiggy drives, then you'll need to connect some cables up to the breakout board to prepare it for your Twiggies. These cables are:
- A 20-pin cable that carries most of the drive signals from the LisaFPGA board to the breakout (the same cable that connects to Sony drives).
- A 6-pin cable that carries some auxiliary Twiggy-specific signals that don't fit on the 20-pin Sony connector.
- Two 26-pin cables that go from the breakout to your Twiggy drives.

Connecting the 20-pin cable is easy; just plug one end into the SONY FLOPPY DRIVE connector on the LisaFPGA board and the other end into the SONY IN connector on the breakout.

The 6-pin cable is a bit less elegant because I'm an idiot. For the sake of saving space, I made the auxiliary Twiggy connector a 4-pin connector (2x2), but clearly I wasn't thinking straight because this allows you to easily plug it in backwards. Plus, they don't even make 4-pin ribbon cable connectors!!! So the solution is to use a 6-pin connector and install it with 2 of the holes sticking up above the connector and the other 4 actually plugged in. Plug one end of this cable into the TWIG connector on the main LisaFPGA board and the other end into the AUX IN connector on the Twiggy breakout. For the sake of ensuring that the cable orientation is correct, make sure to plug in the connector with the red stripe facing down towards the board on both ends.

To make matters worse, I didn't account for the width of the connector given that I originally planned on only using a 4-pin cable, so you'll need to bend the 4-pin header on both PCBs upward to get the cable to seat properly. If you bought a board from JCM or MacEffects, I will have already done this for you. Sorry that I'm such an idiot!!!

The 26-pin cables are a lot easier; stick one end of the first cable into the UPPER TWIGGY connector on the breakout board, and the other end into the connector on the back of your upper Twiggy drive. Then repeat for the LOWER TWIGGY connector and your lower Twiggy drive.

Make sure you have the I/O ROM SELECT switch on the LisaFPGA board set to the 40 position if you plan on using Twiggy drives.

If you're using Twiggies, then a computer's USB port will DEFINITELY not provide enough current to power the board, and you'll get brownouts left and right. Power the board from an actual USB-C power brick if you're using Twiggies!

This photo shows how everything should be connected, minus the actual Twiggy drives since I'm not lucky enough to own any!

<img width="1280" height="720" alt="IMG_4167" src="https://github.com/user-attachments/assets/786e75c6-ae5c-4997-86b9-a9ec33790e6a" />

### Using the Serial Ports
The two serial ports (Serial A and Serial B) along the top edge of the board work just like they do on a real Lisa; simply plug in your serial device and you'll be up and running! Just make sure that, if you're using the physical Serial B port, you have the SERIAL B SOURCE switch set to the RS232B position.

Alternatively, you have the option of routing Serial B through an onboard USB-to-serial adapter and over to the board's USB-C port. This way, you can plug the board into your computer via USB and connect straight to the Lisa in your favorite terminal software (or whatever else you want to use) for the sake of transferring files, logging into a UNIX session, and so on. To switch into this mode, just flip the SERIAL B SOURCE switch into the USB position.

The USB-to-serial interface's hardware handshaking (RTS and CTS) lines are wired up to the corresponding lines within the Lisa, so you'll have full hardware flow control over the USB link!

## Compatibility Notes
### What if my software needs a 2/10 in order to run?
LisaFPGA emulates a Lisa 1 or 2/5 by default (depending on the position of the I/O ROM SEL switch), but there's a way to trick software into thinking that it's running on a 2/10 if you ever need to do this. The main situation in which this is useful is when you want to run Xenix from a 10MB hard drive, but run into the stupid limitation where it forbids you from going above 5MB on a Lisa 2/5.

Tricking software into thinking it's running on a 2/10 is as simple as changing the reported I/O ROM revision from A8 to 88. No need to change any of the I/O board logic; we can leave that in the 2/5 configuration and just spoof the ROM revision.

If you short GPIO0 on the GPIO header to 3V3, it'll spoof the I/O ROM revision to 88 and make everything think that it's running on a 2/10! Given that very few people will probably ever use this, I decided to stick it on the GPIO header as opposed to an actual jumper.

### OS Notes
Most of these notes aren't specific to LisaFPGA (they apply on real Lisas too), but I figured I'd include them since there are some mistakes people make when trying to load certain OSes that will make them fail to boot.
- LOS 1.0 hangs or errors out very early in boot unless you have the 40 I/O board ROMs selected. And even if you do have the 40 ROMs selected, it'll still hang on the desktop unless you have a real set of Twiggy drives connected.
- GEM will refuse to boot with more than 1MB of RAM. Make sure to have your RAM size jumpers set to either 512KB or 1MB in order to get it to boot.
- Xenix requires a 5MB hard disk on a Lisa 2/5 and a 10MB hard disk on a 2/10. LisaFPGA emulates a Lisa 2/5, so you have to use a 5MB Xenix image or else it won't work right, although I did devise a way to get around this and use 10MB images, [as discussed earlier](#what-if-my-software-needs-a-210-in-order-to-run).
- MacWorks Plus II requires a PFG module in order to function, which plugs into the SCC socket of an original Lisa. But we don't have an SCC socket since the SCC is implemented inside the FPGA, so there's no way to connect a PFG and thus no way to run MacWorks Plus II. But I'm hoping to implement a PFG internally to solve this problem in the future.

## Software Compatibility
LisaFPGA should be 100% compatible with the original Lisa hardware, at least when operating at stock (non-overclocked) speeds.

Once you start overclocking, timing differentials open up between the main system and some of its peripherals (namely the COP421) that can cause issues under certain very specific circumstances, but otherwise the compatibility remains.

Every single piece of Lisa software I can get my hands on will run on the Lisa in both stock and overclocked configurations, with one exception.

This exception is MacWorks Plus, which works great at stock speeds but breaks when overclocked thanks to the aforementioned timing differentials. Luckily, I've devised a patch for this that's applied to the MacWorks Plus images in the ```images.zip``` archive.

If you want to patch your existing MacWorks Plus disks manually, simply open them in a hex editor and find the value:
```007C 0300 207C 00FC DD81 243C 0000 0108```
Then replace it with:
```007C 0300 207C 00FC DD81 243C 7000 0000```
The 7000 0000 in place of the 0000 0108 increases the COP timeout to be large enough to avoid timing out at these higher clock speeds.

# Building the Code Yourself
Most people (even those who are fabricating their own boards) won't need to do this because I provide a ready-to-go bitstream file in this repo, but if you want to experiment with modifying the LisaFPGA codebase in any way, then you'll need to actually build the entire project from source.

Keep in mind that this is NOT the code that runs on ESProFile and ESFloppy. The source code for the two emulators can be found in their own respective repos if you want to build any of that: [here](https://github.com/alexthecat123/ESProFile) for ESProFile and [here](https://github.com/alexthecat123/ESFloppy) for ESFloppy (once I have it working).

When you plug the LisaFPGA board into your computer, you'll see two ESP32-S3 devices show up, one for each emulator. These are the targets that you'll want to upload the ESProFile/ESFloppy code to if you're making any changes to them.

For ESProFile, make sure that the ```#include "PinDefs_ESProFile.h"``` line in ```ESProFile.ino``` is commented out and that the line ```#include "PinDefs_LisaFPGA.h"``` is commented in. This will ensure that ESProFile uses the pin assignments for the LisaFPGA board as opposed to the standalone ESProFile board. This step is done automatically if you run the ```program_board.sh``` script.

Anyway, back to the LisaFPGA codebase. Given that the build process is relatively complex, I've made a video going through the whole thing instead of typing it all out. You can watch it [here](https://youtu.be/xozBZ3tEeNQ).

Keep in mind that the video provides a simplified explanation of what you need to do in order to get things to compile; if you're planning on doing any development of your own, you're probably going to want to have some FPGA-related experience apart from this simple "how to get it to compile" tutorial.

# Dev Notes
## Directory Structure
All of the LisaFPGA source code can be found in the ```LisaFPGA.srcs/sources_1``` directory. Vivado arranges source files in a really annoying way, so you can find them in a combination of all the subdirectories of that directory, although most of them are in ```LisaFPGA.srcs/sources_1/imports/lisaStuff```. I'd suggest just using the Sources hierarchy viewer in Vivado to find and edit files because of how horrible this structure is.

The results of a design run (synthesis/implementation/bitstream generation) will be placed in the ```LisaFPGA.runs/synth_1``` and ```LisaFPGA.runs/impl_1``` directories for synthesis and implementation, respectively. The final bitstream file that goes into your FPGA is ```LisaFPGA.runs/impl_1/top.bit```.

All of the PCB designs are in the ```hardware``` directory. The ```lisafpga_desktop/rev_X``` subdirectories contain the design files for various revisions of the LisaFPGA PCB, and the ```twiggy_breakout/rev_X``` subdirectories contain the various versions of the Twiggy drive breakout board. Full EasyEDA projects, schematics, Gerbers, BOMs, and pick-and-place files can be found in each of these directories.

There are various helper tools in the ```tools``` directory for dealing with ROM files, all written by Claude because I didn't feel like wasting time.
- ```tools/romtool.py``` takes high and low 8-bit ROM files and fuses them into a single 16-bit ROM file, or takes a 16-bit file and splits it into high and low 8-bit ROMs.
- ```tools/bin2hex.py``` takes a standard binary ROM file and converts it into the ASCII format that the SystemVerilog ```$readmemh()``` macro expects. This is what you'll want to use if you want to replace my existing Lisa ROM files with those of your own.
- ```tools/hex2bin.py``` does the opposite of ```bin2hex.py```; it takes an ASCII ```$readmemh()```-style ROM file and converts it back to binary again.


## SystemVerilog Module Structure
The top-level SystemVerilog module in this design, ```top.sv```, can best be described as an equivalent of the Lisa motherboard, essentially instantiating and connecting all of the other components together. Obviously there's more going on in ```top.sv``` than on the original Lisa motherboard (clock muxing, HDMI, USB, and so on), but it's still the same general idea.

The ```top.sv``` module instantiates several other modules that implement the main functionality of the design. They are:
- ```CPU_board.sv``` - The Lisa's CPU board.
- ```mem_board_2mb.sv``` - A 2MB RAM board that interfaces to the physical SRAM IC, runtime-configurable anywhere from 512KB to 2MB.
- ```IO_board.sv``` - The Lisa 1 and Lisa 2/5 I/O board.
- ```Lite_Adapter.sv``` - The Lisa Lite adapter that's present in the 2/5; generates the PWM signal needed to run the Sony floppy drive's motor.
- ```HDMI_Interface.sv``` - The module that takes the Lisa's video signal and spits out a corresponding HDMI signal.
- ```usb_hid_host.sv``` - Two of these are instantiated; they handle comms with the USB keyboard and mouse.
- ```usb_keyboard_interface.sv``` - Takes USB keyboard data from one of the ```usb_hid_host.sv``` modules and converts it to the Lisa keyboard protocol.
- ```usb_mouse_interface.sv``` - Same as ```usb_keyboard_interface.sv```, except for the USB mouse.

There are plenty of other sub-modules instantiated within these modules (like the 68K CPU, 6522 VIAs, COP421, and so on), but there are too many of those to list each one. Those should be pretty self-explanatory since they match the structure of the original Lisa.

All of the Lisa's clocks are generated in ```top.sv``` by the ```dotck_mmcm``` (generates the four DOTCKs for the four different overclocks) and ```clock_divider``` (generates all of the other clocks) MMCMs. These take a 125MHz clock from the LisaFPGA board as an input.

Another MMCM called ```hdmi_clock_divider``` exists inside of ```HDMI_Interface.sv``` to generate the dot and audio clocks needed by the 1080p HDMI module.

## The LisaFPGA Identity Register
Some software might be interested in seeing whether it's running on a real Lisa or a LisaFPGA board, and I implemented a register that allows you to determine just that!

In the stock Lisa, the Error Status Register on the CPU board (address ```0x00FCF801``` in the boot-configuration memory map) is only 8 bits wide, with the top 8 bits of the bus being left unused. I've extended this register to be a full 16 bits wide, with the high 8 bits being the identity register.

The format of the identity register is as follows:
| [7:5]             | [4:3] | [2]        | [1:0] |
| ----------------- | ----- | ---------- | ----- |
| LisaFPGA_Identity |   0   | Board_Type | Speed |

- ```LisaFPGA_Identity``` is a "magic number" of ```110``` that identifies the board as a LisaFPGA board.
- ```Board_Type``` is ```1``` for a LisaFPGA desktop board (the standalone LisaFPGA board) or ```0``` for a LisaFPGA motherboard replacement (the upcoming version that will replace the motherboard of a real Lisa).
- ```Speed``` is a 2-bit value representing the current speed of the Lisa. The values and corresponding speeds are as follows:
    | Speed[1:0] | CPU Speed | DOTCK Speed |
    | ---------- | --------- | ----------- |
    | 2'b00      | 5MHz      | 20MHz       |
    | 2'b01      | 10MHz     | 40MHz       |
    | 2'b10      | 15MHz     | 60MHz       |
    | 2'b11      | 18.75MHz  | 75MHz       |

# Future Enhancements
There are a couple of things that I'd like to (and/or need to) do before I can call the project completely finished:
- Get the onboard ESFloppy floppy emulator working, and maybe even emulating Twiggy drives.
- Design a version of the board that's a drop-in replacement for an original Lisa motherboard. That way, you can replace the entire card cage of a real Lisa with a LisaFPGA board!

# Contact Me!
Feel free to email me at [alexelectronicsguy@gmail.com](mailto:alexelectronicsguy@gmail.com) if you need help, find any bugs, or have any questions/comments!

# Changelog
6/6/2026 - Initial LisaFPGA core v1.0 release and v3 PCB release.
6/23/2026 - LisaFPGA core v1.1 - Replaced external SCC with an internal SystemVerilog implementation for the sake of cost savings, easier parts sourcing, and reduced PCB complexity.
6/28/2026 - LisaFPGA core v1.2 - Fixed issues where marginal SRAM chips would sometimes fail at a 75MHz DOTCK and moved the VIAs from the E clock with clock enables to the DOTCK with clock enables to improve timing stability.
7/6/2026 - LisaFPGA core v1.3 - Improved USB keyboard keymappings to better match the original Lisa keyboard; changes courtesy of RebeccaRGB.

# Appendix - Jumpers, Switches, Buttons, and LEDs
There are quite a lot of switches, jumpers, buttons, and LEDs on the LisaFPGA board. Here's a table explaining what each one does, along with longer explanations whenever necessary.

| Name                           | Type     | Function |
| ------------------------------ | -------- | -------- |
| POWER                          | Switch/LED | A switch next to the USB-C port that turns the entire board on and off, and a corresponding power indicator LED. |
| LISA POWER                     | Button/LED | The Lisa's soft power switch and corresponding power LED. |
| RESET                          | Button   | The reset button that you'd find on the back of a real Lisa. Don't press this during normal use unless you know what you're doing; it'll reboot the computer and you'll lose any unsaved work! |
| NMI                            | Button   | The NMI button that you'd find on the back of a Lisa 2/10. Pressing this will lead to unpredictable results depending on the state of the Lisa, so once again, only hit it if you know what you're doing! |
| HDMI FRAMERATE                 | Jumper   | Picks whether HDMI outputs video at 30FPS or 60FPS; certain monitors only support one or the other. |
| INVERSE VIDEO                  | Jumper   | Inverts the Lisa's video signal (white becomes black, black becomes white) when set to INV, and video is untouched when set to REG. |
| SCANLINES                      | Jumper   | Inserts simulated scanlines into the video output when ON, and video is untouched when OFF. |
| SPKR SEL                       | Jumper   | Picks whether audio comes out of the board's speaker (INT) or an external speaker on the SPKR header (EXT). Audio is always sent over HDMI regardless. |
| KEYBOARD SELECT                | Switch   | Selects whether the Lisa gets keyboard input from a real Lisa keyboard (LISA) or a USB keyboard (USB). |
| MOUSE SELECT                   | Switch   | Same as KEYBOARD SELECT, but for the mouse. |
| SERIAL B SOURCE                | Switch   | Selects whether the Lisa's Serial B port is connected to the physical DB25 port (RS232B) or the onboard USB-to-serial interface that routes the serial port over the USB-C connector (USB). |
| HARD DRIVE SOURCE              | Switch   | Selects whether the Lisa uses the onboard ESProFile emulator (ESPROFILE) or an external ProFile on the PROFILE CONNECTOR port (EXT) as its hard drive. |
| FLOPPY DRIVE SOURCE            | Switch   | Same as HARD DRIVE SOURCE, except for the floppy drive. The onboard ESFloppy emulator hasn't been implemented yet, so you should always flip this to the EXT position for now. |
| RAM SIZE 0, RAM SIZE 1         | Jumpers  | These jumpers set how much RAM is visible to the Lisa, from 512KB to 2MB, in increments of 512KB. Check below this table for info on the mapping between jumper settings and RAM sizes. |
| CPU ROM SELECT                 | Switch   | Selects between "rectangular pixels" (H) and "square pixels" (3A) Lisa CPU board ROMs. The H ROMs will work in every OS, but will look a bit weird in MacWorks. So you can switch over to the 3A ROMs for better-looking video, but only while running MacWorks; the 3A ROMs don't work in any other OS. |
| I/O ROM SELECT                 | Switch   | Selects between the Twiggy (40) and Sony 400K/800K (A8) I/O board ROMs that drive the floppy disk controller. If you don't plan on connecting a floppy drive, then put this in the A8 position. |
| SPEED SELECT 0, SPEED SELECT 1 | Switches | These two switches let you set the Lisa's clock to one of four speeds: stock and then three overclocked speeds. See the table below for the switch configs and their corresponding speeds. |
| ESProFile RESET                | Button   | Resets the ESP32 that controls the ESProFile hard disk emulator. Hit this whenever you're finished with your current disk image and want to return to the Selector. Make sure that the Lisa is shut down first though! |
| ESProFile BOOT                 | Button   | Puts ESProFile's ESP32 into bootloader mode when pressed in conjunction with the ESProFile RESET button. This only needs to be done if you accidentally brick your ESP32. |
| ESProFile Status LED           | LED      | An RGB LED below the ESProFile BOOT button that indicates the current status of ESProFile. Red means it's either initializing or something's wrong, green means everything is good, and blinking indicates disk activity. |
| ESFloppy RESET                 | Button   | Same as ESProFile RESET, but for ESFloppy. |
| ESFloppy BOOT                  | Button   | Same as ESProFile BOOT, but for ESFloppy. |
| ESFloppy OLED Display          | OLED     | A 1.3" OLED display that will allow the user to pick floppy images once I get the floppy emulator working. |
| ESFloppy Activity LED          | LED      | A green LED right below the OLED to indicate drive activity on ESFloppy. |
| ESFloppy LEFT, SEL, and RIGHT  | Buttons  | Buttons that will allow for navigation of ESFloppy menus once I get it working. |
| BITMODE                        | Jumper   | Determines whether the FPGA gets its bitstream from SPI flash or JTAG. Unless there's some reason why you want to forbid it from loading the LisaFPGA code from flash at power-on, you'll always want this to be in the SPI position. |
| PROGRAM                        | Button   | Makes the FPGA reload its bitstream from SPI flash, erasing the Lisa design from its memory and reloading it again. Don't press this while you're using the Lisa unless it's hung or you know what you're doing; you'll lose any unsaved work! |
| DONE                           | LED      | Lights up whenever the FPGA is done loading its bitstream from flash. Essentially, it's off when the Lisa design hasn't been loaded yet and on once it has been loaded and is ready for use. |
| ACT LEDs                       | LEDs     | USB activity LEDs for JTAG, ESProFile, ESFloppy, Serial B, and overall activity. Each device's LED will light up when it's properly enumerated over USB; they won't light up if you're powering the board from something that's not a computer. |

## RAM Size Jumper Settings
| RAM SIZE 1 | RAM SIZE 0 | Amount of RAM |
| ---------- | ---------- | ------------- |
| OFF        | OFF        | 512KB         |
| OFF        | ON         | 1MB           |
| ON         | OFF        | 1.5MB         |
| ON         | ON         | 2MB           |

## Speed Select Switch Settings
| SPEED SELECT 1 | SPEED SELECT 0 | CPU Clock Speed |
| -------------- | -------------- | --------------- |
| OFF            | OFF            | 5MHz (Stock)    |
| OFF            | ON             | 10MHz           |
| ON             | OFF            | 15MHz           |
| ON             | ON             | 18.75MHz        |
