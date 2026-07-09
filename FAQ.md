# LisaFPGA Frequently Asked Questions and Troubleshooting

Below are some questions I get a lot and some troubleshooting tips I give when people are trying to get their boards going. I'll be expanding this section as I get more questions from people!

If your question isn't answered here, feel free to email me at [alexelectronicsguy@gmail.com](mailto:alexelectronicsguy@gmail.com)!

## How compatible is the LisaFPGA design with the original Lisa hardware?
Unless there's some bug that I haven't found yet, it should be 100% compatible by nature of being a 1:1 recreation of the original hardware (or at least as close as I could get). From all the testing I've done so far, it is indeed 100% compatible.

The 100% compatibility falls apart a bit when you start overclocking your LisaFPGA board thanks to clocking differentials between most of the system and some of its peripherals, but the only incompatibility this introduces is an issue where overly conservative COP timeouts will break things. This isn't a problem in all but one of the Lisa's OSes, and I have a patch for the one where it is a problem.

## How much power does the LisaFPGA desktop board consume? Can I power it off a USB power bank?
When in the standard configuration that most people will be using (max overclock, USB keyboard/mouse, Floppy Emu), the board uses about 2.8W of power, which will give you between 14 and 18 hours of battery life if you power it from a standard 10,000mAh USB power bank. Not sure why you would want to do this, but I think it's pretty cool, so I figured I'd mention it!

## My board doesn't do anything when I hit the Lisa power button (no power LED or anything). What's going on?
The FPGA probably didn't get programmed at power-on. I've seen this happen very, very occasionally on my boards, but it's so infrequent that I can't reproduce it enough to figure out what's wrong or devise a fix. The solution is simple: just power-cycle the board or hit the PROGRAM button and wait for the DONE LED to light up.

## The power LED comes on when I hit the Lisa's power button, but I don't get any video output over HDMI. Perhaps the monitor even says that the input format is unsupported. What's going on?
Some cheaper monitors (and especially cheap capture devices) can be kind of picky about the framerate that the board outputs and will only display either 30FPS or 60FPS, but not both. Try moving the HDMI FRAMERATE jumper from whatever position it's currently in to the other position and see if that fixes things. If both positions work, then put the jumper in the 60FPS position for a better experience.

There's also the possibility that your monitor just doesn't support 1080p, and if that's the case, then you'll need to switch to a 1080p-capable monitor. Most monitors won't have a problem with that though.

## Why does my board keep crashing and rebooting whenever I have a real floppy drive plugged in?
Real 400K and 800K drives (especially 400K drives) can draw quite a bit of current sometimes, and a lot of computers' USB ports can't sustain that level of current consumption and shut down when the floppy drive tries to do something. The solution here is to stop powering your LisaFPGA board from your computer (or from a low-end phone charger or something) and start powering it from something that can deliver more power. I've had good success with USB-C MacBook chargers, but that's almost certainly overkill. A reasonably solid phone charger would probably be fine.

## I can't boot an OS; they all just keep crashing during boot! What do I do?
Some people have had strange issues when using cheap off-brand microSD cards with their ESProFiles where your OS will try to boot, but then randomly crash in a way that makes it seem as if the Lisa itself has a hardware fault. If you see an error 10707 or 10738 in LOS (or you really get any errors whatsoever when booting the images that I give you in ```images.zip```), then you're probably experiencing this. To fix it, upgrade to a name-brand SD card; I normally use [these cards](http://amazon.com/dp/B08T6QSBPJ) from PNY, but pretty much anything from the big manufacturers should work.

## My USB keyboard and/or mouse don't work with LisaFPGA, or partially work but act weird. What's going on?
LisaFPGA's USB code can be a bit picky about keyboards and mice. There are certain peripherals that just won't work quite right, and the only solution here is to try another keyboard or mouse if you encounter a problem. I've had the best results with late 2000s and early 2010s peripherals, particularly those from Dell and HP, but plenty of other brands/models will work too. Modern gaming peripherals probably won't work, and neither will any keyboard that has a built-in USB hub.

## MacWorks Plus randomly turns the whole computer off whenever the system tries to boot! Why?
This happens whenever you run stock (unpatched) MacWorks Plus on an overclocked Lisa. There's a timing issue where it fails to communicate with the COP properly at higher clock speeds, but works fine at stock speeds. Luckily, I've devised a patch for the problem, and if you use the MacWorks Plus image provided in ```images.zip```, then the patch is pre-applied.

If you want to patch your existing MacWorks Plus disks, simply open them in a hex editor and find the value:

```007C 0300 207C 00FC DD81 243C 0000 0108```

Then replace it with:

```007C 0300 207C 00FC DD81 243C 7000 0000```

The 7000 0000 in place of the 0000 0108 increases the COP timeout to be large enough to avoid timing out at these higher clock speeds.

## The ```program_board.sh``` script failed in the middle of programming my board! What do I do?
Just turn the board off and back on again and then run the script a second time. It should succeed the second time around; I've seen this happen on rare occasions and I'm not sure why.

## Does LisaFPGA support MacWorks Plus II?
Not at the moment because MacWorks Plus II requires a physical PFG module that plugs into the Lisa's SCC socket. We don't have an SCC socket since the SCC is inside the FPGA, so no PFG either. But I'm hoping to implement the PFG inside the FPGA at some point in the future to solve this problem!
