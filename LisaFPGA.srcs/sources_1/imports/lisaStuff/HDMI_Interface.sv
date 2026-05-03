`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/20/2025 01:23:33 AM
// Design Name: 
// Module Name: HDMI_Interface
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


module HDMI_Interface (
    input logic sysclk,
    input logic _reset,
    input logic DOTCK,
    input logic framerate_sel, // 0 for 1080p30, 1 for 1080p60
    input logic VA_overflow, // Replaces VSYNC; active high during vertical blanking
    input logic _clr_vid_clk, // Replaces _HSYNC; active low during horizontal blanking
    input logic VID,
    input logic [5:0] CONT,
    input logic TONE,
    input logic [2:0] VC,
    input logic CPU_ROM_SEL,
    input logic blank_video, // When high, force the video output to black
    input logic scanlines, // When high, put scanlines on the video output to make it look cool
    output logic tmds_clock,
    output logic [2:0] tmds
    );

    logic clk_pixel, clk_pixel_1080p30, clk_pixel_1080p60;
    logic clk_pixel_x5, clk_pixel_x5_1080p30, clk_pixel_x5_1080p60;
    logic clk_feedback_in, clk_feedback_out;
    logic clk_audio_unbuffered, clk_audio;

    // Instantiate the MMCM for our 1080p30 and 1080p60 pixel clock and 5x pixel clock
    hdmi_clock_divider hdmi_clock_generator (
        .sysclk(sysclk),
        .clk_pixel_x5_1080p60(clk_pixel_x5_1080p60),
        .clk_pixel_x5_1080p30(clk_pixel_x5_1080p30),
        .clk_pixel_1080p60(clk_pixel_1080p60),
        .clk_pixel_1080p30(clk_pixel_1080p30),
        .clkfb_in(clk_feedback_in),
        .clkfb_out(clk_feedback_out)
    );
    // Give it a feedback path through a BUFG
    BUFG hdmi_clk_feedback (
        .I(clk_feedback_out),
        .O(clk_feedback_in)
    );
    // Next, we need to synchronize our framerate selector signal into the pixel clock and pixel clock x5 domains so we can feed it to other parts of our design
    (* ASYNC_REG = "TRUE" *) logic framerate_sel_int_pixel, framerate_sel_sync_pixel;
    (* ASYNC_REG = "TRUE" *) logic framerate_sel_int_pixel_x5, framerate_sel_sync_pixel_x5;
    always_ff @(posedge clk_pixel) begin
        framerate_sel_int_pixel <= framerate_sel;
        framerate_sel_sync_pixel <= framerate_sel_int_pixel;
    end
    always_ff @(posedge clk_pixel_x5) begin
        framerate_sel_int_pixel_x5 <= framerate_sel;
        framerate_sel_sync_pixel_x5 <= framerate_sel_int_pixel_x5;
    end
    // Now instantiate two BUFGMUXes to mux the pixel clocks and the x5 pixel clocks
    // DON'T use the synchronized framerate_sel here since they depend on the output of the BUFGMUX in the first place
    BUFGMUX bufgmux_clk_pixel (
        .I0(clk_pixel_1080p30),
        .I1(clk_pixel_1080p60),
        .S(framerate_sel),
        .O(clk_pixel)
    );
    BUFGMUX bufgmux_clk_pixel_x5 (
        .I0(clk_pixel_x5_1080p30),
        .I1(clk_pixel_x5_1080p60),
        .S(framerate_sel),
        .O(clk_pixel_x5)
    );
    // Finally, we need to determine the audio clock threshold depending on which video mode is selected
    // This ensures that we're always generating a 48KHz audio clock regardless of the pixel clock
    /*logic [11:0] audio_clk_threshold;
    always_ff @(posedge DOTCK) begin
        if (framerate_sel_sync == 1'b0) begin
            // 1080p30 requires a 74.25MHz pixel clock, so the toggle threshold for 48KHz audio is 74250000 / (2 * 48000) = 772-ish
            audio_clk_threshold <= 772;
        end else begin
            // 1080p60 requires a 148.5MHz pixel clock, so the toggle threshold for 48KHz audio is 148500000 / (2 * 48000) = 1546-ish
            audio_clk_threshold <= 1546;
        end
    end*/

    // Finally, pick the video ID code sent to the HDMI interface based on our framerate
    logic [6:0] video_id_code;
    always_ff @(posedge clk_pixel) begin
        if (framerate_sel_sync_pixel == 1'b0) begin
            video_id_code <= 7'd34; // Code 34 for 1080p30
        end else begin
            video_id_code <= 7'd16; // Code 16 for 1080p60
        end
    end

    // Synchronise the reset signal (from the DOTCK domain) to the HDMI pixel clock domain
    // Otherwise we have tons of metastability issues`
    (* ASYNC_REG = "TRUE" *) logic _reset_hdmi_int, _reset_hdmi;
    // We use a two-stage synchronizer here
    always_ff @(posedge clk_pixel) begin
        _reset_hdmi_int <= _reset;
        _reset_hdmi <= _reset_hdmi_int;
    end

    // We need to synchronize blank_video too; it's the ON signal, which is in the COPCK_2x domain
    (* ASYNC_REG = "TRUE" *) logic blank_video_int, blank_video_sync;
    always_ff @(posedge clk_pixel) begin
        blank_video_int <= blank_video;
        blank_video_sync <= blank_video_int;
    end

    // Now generate the audio clock by dividing the pixel clock down to 48KHz using a counter
    // We can't use an MMCM because they can only go down to 6MHz or so
    logic [11:0] counter;
    // Clock this off the 1080p30 clock; this way we don't have to worry about the threshold changing when we shift between 1080p30 and 1080p60
    always_ff @(posedge clk_pixel_1080p30, negedge _reset_hdmi) begin
        if (!_reset_hdmi) begin
            counter <= 12'd0;
            clk_audio_unbuffered <= 1'b0;
        end else begin
            if (counter == 12'd772) begin // Toggle threshold for 48KHz audio is 74250000 / (2 * 48000) = 772-ish
                counter <= 12'd0;
                clk_audio_unbuffered <= ~clk_audio_unbuffered;
            end else begin
                counter <= counter + 1'd1;
            end
        end
    end

    // But clk_audio_unbuffered is a clock, and it's not on a clock net right now, which causes clock skew if we use it as-is
    // This isn't a theoretical problem; the audio actually gets garbled sometimes between synthesis runs if we don't fix the skew
    // So we need to get it on a real clock net there, which we can do with a BUFG
    BUFG buf_audio (
        .I(clk_audio_unbuffered),
        .O(clk_audio)
    );

    logic [15:0] audio_sample_word;

    // Now let's do the audio sample generation
    // We take our input audio square wave on TONE and volume on VC (3 bits)
    // And then we convert it to two 16-bit audio samples (stereo)
    // Both channels will be the same since the Lisa is mono
    // We need to convert the square wave to a PCM value, and scale it linearly based on VC
    // VC = 000 = mute, VC = 111 = max volume
    // So when TONE is high, output max_volume, when TONE is low, output 0
    // max_volume = (VC / 7) * 65535
    // So final output = TONE ? max_volume : 0
    // Before we do any of that though, synchronize both VC and TONE to the audio clock domain to avoid metastability issues
    (* ASYNC_REG = "TRUE" *) logic TONE_int, TONE_sync;
    (* ASYNC_REG = "TRUE" *) logic [2:0] VC_int, VC_sync;
    always_ff @(posedge clk_audio) begin
        TONE_int <= TONE;
        TONE_sync <= TONE_int;
        VC_int <= VC;
        VC_sync <= VC_int;
    end

    // LOS's volume levels are 0 for off (duh), 3 for Soft, 4, 5, and 6 for the in between levels, and 7 for Loud
    // But then after you select it, it remaps it to 1-5 from the 3-7, not sure why, maybe it maps it back when a sound actually plays
    // MacWorks Plus uses 0 for volume slider levels 0 and 1, 1 for volume slider levels 2 and 3, 2 for volume slider levels 4 and 5, and 3 for volume slider levels 6 and 7
    // MWP never goes above 3 oddly enough
    logic [15:0] max_volume;
    assign max_volume = (VC_sync == 3'd0) ? 16'd0 :
                        (VC_sync == 3'd1) ? 16'd9362 :
                        (VC_sync == 3'd2) ? 16'd18724 :
                        (VC_sync == 3'd3) ? 16'd28086 :
                        (VC_sync == 3'd4) ? 16'd37448 :
                        (VC_sync == 3'd5) ? 16'd46810 :
                        (VC_sync == 3'd6) ? 16'd56172 :
                                       16'd65535;
    always_ff @(posedge clk_audio) begin
        audio_sample_word <= TONE_sync ? max_volume : 0; //-max_volume;
    end

    logic [23:0] rgb = 24'd0;
    logic [11:0] cx;
    logic [10:0] cy;

    // We'll use the full vertical resolution (actually a little more), and less of the horizontal resolution
    // The Lisa is 720x364, so we'll center that in 1920x1080, but each Lisa pixel is 3 pixels high and 2 pixels wide
    // So we'll actually use 1440x1092 (720*2 x 364*3) centered in 1920x1080
    // This gives us a border of 240 pixels on the left and right, and we'll just crop 12 pixels off the bottom
    // The Lisa framebuffer is a 32K 1 bit per pixel bitmap
    (* ram_style = "block" *)
    // The framebuffer needs to be 32760 bytes (720*364/8) for the H ROMs
    // And it needs to be 32832 bytes (608*432/8) for the 3A ROMs
    // But we'll make it even bigger (33000 bytes) to account for the fact that the 3A ROMs capture an extra few bytes at the end of the frame
    logic [7:0] lisa_framebuffer [0:32999];
    logic [9:0] lisa_x;
    logic [9:0] lisa_y;
    logic [15:0] word_index;
    logic [2:0] bit_index;
    logic pixel;
    logic [15:0] byte_counter;
    logic [2:0] bit_counter;
    logic [7:0] current_byte;
    logic [3:0] end_line_overlap_counter;
    logic [3:0] start_line_overlap_counter;
    logic [1:0] hsync_delay_counter;
    logic prev_clr_vid_clk;
    logic [3:0] hsync_delay_counter_threshold;
    logic [3:0] start_line_overlap_counter_threshold;
    logic [3:0] end_line_overlap_counter_threshold;
    always_ff @(negedge DOTCK) begin
        // First, check the state of CPU_ROM_SEL and set the frame bounds accordingly
        if (CPU_ROM_SEL == 1'b0) begin
            // H ROMs; set the start and end line overlap counters for H ROM timing, as well as the start-of-frame hsync delay counter
            // Wait 2 lines after VSYNC is over before starting to capture lines
            // We really shouldn't be waiting at all here, but 364*3=1092 which is a bit bigger than 1080
            // This means 4 lines will get cut off the bottom of the frame, so to better center it, we wait 2 lines before starting to capture
            // This way, we lose 2 lines at the top and 2 lines at the bottom instead of all 4 at the bottom
            hsync_delay_counter_threshold <= 2'd2;
            start_line_overlap_counter_threshold <= 4'd9; // Wait 9 DOTCKs after HSYNC is over before starting to capture pixels
            end_line_overlap_counter_threshold <= 4'd9; // Keep capturing pixels for 9 DOTCKs after HSYNC starts
        end else begin
            // 3A ROMs; set the start and end line overlap counters for 3A ROM timing, and the the hsync delay counter is zero
            // No delay after VSYNC is over before starting to capture lines; 432*2=864 which fits within 1080 just fine
            hsync_delay_counter_threshold <= 2'd0;
            start_line_overlap_counter_threshold <= 4'd9; // Wait 9 DOTCKs after HSYNC is over before starting to capture pixels
            end_line_overlap_counter_threshold <= 4'd9; // Keep capturing pixels for 9 DOTCKs after HSYNC starts
        end
        prev_clr_vid_clk <= _clr_vid_clk;
        if (!_reset) begin
            bit_counter <= 0;
            byte_counter <= 0;
            current_byte <= 8'd0;
            start_line_overlap_counter <= 0;
            end_line_overlap_counter <= 0;
            hsync_delay_counter <= 0;
        end else begin
            if (VA_overflow == 1'b1) begin
                bit_counter <= 0;
                byte_counter <= 0;
                current_byte <= 8'd0;
                hsync_delay_counter <= 0;
                start_line_overlap_counter <= 0;
                end_line_overlap_counter <= 0;
            end else if ((_clr_vid_clk == 1'b1 || end_line_overlap_counter != end_line_overlap_counter_threshold) && hsync_delay_counter == hsync_delay_counter_threshold) begin
                if (_clr_vid_clk == 1'b0 && end_line_overlap_counter != end_line_overlap_counter_threshold) begin
                    end_line_overlap_counter <= end_line_overlap_counter + 1;
                end else if (_clr_vid_clk == 1'b1) begin
                    end_line_overlap_counter <= 4'd0;
                end
                if (start_line_overlap_counter != start_line_overlap_counter_threshold) begin
                    if (_clr_vid_clk == 1'b1) begin
                        start_line_overlap_counter <= start_line_overlap_counter + 1;
                    end
                end else begin
                    if (bit_counter == 3'd7) begin
                        lisa_framebuffer[byte_counter] <= {VID, current_byte[7:1]};
                        byte_counter <= byte_counter + 1;
                        bit_counter <= 0;
                        current_byte <= 8'd0;
                    end else begin
                        current_byte <= {VID, current_byte[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
            end else begin
                start_line_overlap_counter <= 4'd0;
                if (hsync_delay_counter != hsync_delay_counter_threshold && prev_clr_vid_clk && !_clr_vid_clk) begin
                    hsync_delay_counter <= hsync_delay_counter + 1;
                end
                if (bit_counter == 3'd7) begin
                    lisa_framebuffer[byte_counter] <= {VID, current_byte[7:1]};
                    byte_counter <= byte_counter + 1;
                    bit_counter <= 0;
                    current_byte <= 8'd0;
                end
            end
        end
    end

    // Now that we have the Lisa's display neatly in our framebuffer, we need to read it out and display it in 1080p HDMI

    // The way we do this will differ a bit depending on whether we're using H ROMs or 3A ROMs
    // The H ROMs capture a 720x364 image, where each Lisa pixel is 2 HDMI pixels wide and 3 HDMI pixels high
    // The 3A ROMs capture a 608x432 image, where each Lisa pixel is 2 HDMI pixels wide and 2 HDMI pixels high
    // To get things properly centered on the display, the H image will start at (240,0) and end at (1680,1092) in HDMI coordinates
    // And the 3A image will start at (352, 108) and end at (1568, 972) in HDMI coordinates
    // Interestingly enough, the final row (431) of the 3A image seems like it only gets partially drawn
    // The VSROM draws about an 1/8th of it and then goes straight into VSYNC, so it's like it doesn't even exist
    // Because of that, we'll actually only draw 431 rows of the 3A image, not the full 432, meaning it's actually 608x431
    // And thus it ends at (1568, 970) instead of (1568, 972)

    // I used to do all this in an always_comb block, but it wouldn't meet timing, so now I've pipelined it into a few stages

    // Before we do any of that though, we need to make a LUT for division by 3
    // Hardware dividers take tons of hardware resources and are too slow to meet timing at 148.5MHz, so a LUT is the solution
    (* rom_style = "distributed" *) logic [9:0] div3_lut [0:1079];

    initial begin
        integer i;
        for (i = 0; i <= 1079; i = i + 1) begin
            div3_lut[i] = i / 3;
        end
    end

    // We also need LUTs for mod 2 and mod 3 operations so that we can insert scanlines (blank lines) every 2 or 3 lines, depending on ROM type
     (* rom_style = "distributed" *) logic [1:0] mod2_lut [0:1079];
     (* rom_style = "distributed" *) logic [1:0] mod3_lut [0:1079];
     initial begin
         integer j;
         for (j = 0; j <= 1079; j = j + 1) begin
             mod2_lut[j] = j % 2;
             mod3_lut[j] = j % 3;
         end
     end

    // First up, we compute the Lisa pixel coordinates from the HDMI pixel coordinates
    // Each Lisa pixel is 2x3 HDMI pixels
    always_ff @(posedge clk_pixel) begin
        if (CPU_ROM_SEL == 1'b0) begin
            // If we have H ROMs, then each Lisa pixel is 2x3 HDMI pixels
            lisa_x <= (cx - 240) >> 1; // Remove the start offset of 240 HDMI pixels and divide by 2, gives us Lisa pixel x coordinate 0-719
            lisa_y <= div3_lut[cy]; // Divide by 3 using our LUT, gives us Lisa pixel y coordinate 0-363
        end else begin
            // If we have 3A ROMs, then each Lisa pixel is 2x2 HDMI pixels
            lisa_x <= (cx - 352) >> 1; // Remove the start offset of 352 HDMI pixels and divide by 2, gives us Lisa pixel x coordinate 0-607
            lisa_y <= (cy - 108) >> 1; // Remove the start offset of 108 HDMI pixels and divide by 2, gives us Lisa pixel y coordinate 0-431 (or really 0-430 since last line is cut off)
        end
    end


    // Next, we use the Lisa pixel coordinates to compute our bit index into the framebuffer
    // Which we then use to determine which word and bit within that word we need to read from the framebuffer
    // Make sure to use a DSP for the multiplications here to help with timing
    (* use_dsp = "yes" *) logic [15:0] word_index_int;
    logic [15:0] lisa_x_shifted;
    logic [2:0] bit_index_int;
    always_ff @(posedge clk_pixel) begin
        if (CPU_ROM_SEL == 1'b0) begin
            // H ROMs
            // The easy-to-understand way to do this is:
            // word_index <= (lisa_y * 720 + lisa_x) >> 3; // Combine the x and y and divide by 8 to get word (byte) index
            // bit_index  <= (lisa_y * 720 + lisa_x) & 7; // Modulo 8 to get bit index within the byte
            // But this is pretty expensive (huge multiplier for lisa_y * 720) and fails timing at 1080p60, so we'll simplify it a bit
            // 720 / 8 = 90, so we can do:
            word_index_int <= lisa_y * 90; // Go ahead and do the >> 3 for 720 to get 90, combine with lisa_y to get word (byte) index of the column
            lisa_x_shifted <= lisa_x >> 3; // Also do the division by 8 for lisa_x here too
            // We'll add in the row's lisa_x >> 3 in the next stage of the pipeline
            bit_index_int <= lisa_x[2:0]; // The lower 3 bits of lisa_x give us the bit index within the byte, no multiplication needed
        end else begin
            // 3A ROMs
            // Same deal for the 3A ROM version; this is the easy-to-understand way:
            // word_index <= (lisa_y * 608 + lisa_x) >> 3; // Combine the x and y and divide by 8 to get word (byte) index
            // bit_index  <= (lisa_y * 608 + lisa_x) & 7; // Modulo 8 to get bit index within the byte
            // But 608 / 8 = 76, so we can do:
            word_index_int <= lisa_y * 76; // Combine the y * 76 and x / 8 to get word (byte) index of the column
            lisa_x_shifted <= lisa_x >> 3; // Divide lisa_x by 8 here too
            bit_index_int <= lisa_x[2:0]; // The lower 3 bits of lisa_x give us the bit index within the byte without any multiplication
        end
        // Now in the next pipeline stage, add lisa_x_shifted to the intermediate word index to account for how far we are into the line
        word_index <= word_index_int + lisa_x_shifted;
        // The bit index was already done in the previous stage, so just pass it along
        bit_index <= bit_index_int;
    end

    logic [7:0] pixel_word;

    // Pipeline the read address for better timing
    logic [15:0] word_index_stage3, word_index_stage4;
    logic [2:0] bit_index_stage3, bit_index_stage4;
    logic in_scanline_stage4, in_scanline_stage5;

    always_ff @(posedge clk_pixel) begin
        // In the third stage, we just pass the values along
        word_index_stage3 <= word_index;
        bit_index_stage3 <= bit_index;
        
        // In the fourth stage, we read the pixel word from the framebuffer
        word_index_stage4 <= word_index_stage3;
        bit_index_stage4 <= bit_index_stage3;
        pixel_word <= lisa_framebuffer[word_index_stage3];
        // Also, if scanlines are on, figure out if we're in a scanline or not in this stage and set a flag accordingly
        if (scanlines) begin
            if (CPU_ROM_SEL == 1'b0) begin
                // For the H ROMs, we want a scanline every 3 lines, so check if mod3_lut[cy] == 2 (the last line in each 3 line group)
                in_scanline_stage4 <= (mod3_lut[cy] == 2);
            end else begin
                // For the 3A ROMs, we want a scanline every 2 lines, so check if mod2_lut[cy] == 1 (the last line in each 2 line group)
                in_scanline_stage4 <= (mod2_lut[cy] == 1);
            end
        end else begin
            in_scanline_stage4 <= 1'b0;
        end
        in_scanline_stage5 <= in_scanline_stage4;
        
        // And finally, in the fifth stage, we extract the pixel bit, but override it to 0 if we're in a scanline
        pixel <= in_scanline_stage5 ? 1'b0 : pixel_word[bit_index_stage4];
    end

    // Now we can finally generate the RGB output based on the pixel value
    // But we need to delay cx and cy by 5 clock cycles to match the pixel signal
    logic [11:0] cx1, cx2, cx3, cx4, cx5, cx6;
    logic [10:0] cy1, cy2, cy3, cy4, cy5, cy6;
    always_ff @(posedge clk_pixel) begin
        cx1 <= cx;
        cx2 <= cx1;
        cx3 <= cx2;
        cx4 <= cx3;
        cx5 <= cx4;
        cx6 <= cx5;
        cy1 <= cy;
        cy2 <= cy1;
        cy3 <= cy2;
        cy4 <= cy3;
        cy5 <= cy4;
        cy6 <= cy5;
    end

    // Note: The "brightest" I've seen anything be able to go on the Lisa is an 0x11 on the CONT value (MacWorks Plus)
    // So maybe make 0x11 full white and scale down from there, just so things are brighter on HDMI?
    // Unless I find some other OS that goes brighter of course!

    // We need to synchronize CONT to the pixel clock domain before we can use it to adjust the brightness of the output
    (* ASYNC_REG = "TRUE" *) logic [5:0] CONT_int, CONT_sync;
    always_ff @(posedge clk_pixel) begin
        CONT_int <= CONT;
        CONT_sync <= CONT_int;
    end

    // Now generate the RGB value
    always @(posedge clk_pixel) begin
        // Check the ROM revision; the active area of the frame depends on this
        if (CPU_ROM_SEL == 1'b0) begin
            // H ROM active area: (240,0) to (1680,1092)
            if (cx6 >= 240 && cx6 < 1680 && cy6 < 1092) begin
                // Figure out if the pixel is black or white, taking CONT into account
                // No need to worry about INVID since it's already handled on the CPU board
                // If the Lisa is off (blank_video), force black output
                rgb <= blank_video_sync ? 24'h000000 : (pixel ? {(6'h3f - CONT_sync), 2'b00, (6'h3f - CONT_sync), 2'b00, (6'h3f - CONT_sync), 2'b00} : 24'h000000);
            end else begin
                // If we're outside the active area, output a dark gray border
                rgb <= 24'h202020;
            end
        end else begin
            // 3A ROM active area: (352,108) to (1568,972) or really (1568,970) because of the missing last line
            if (cx6 >= 352 && cx6 < 1568 && cy6 >= 108 && cy6 < 970) begin
                // Figure out if the pixel is black or white, taking CONT into account
                // No need to worry about INVID since it's already handled on the CPU board
                // If the Lisa is off (blank_video), force black output
                rgb <= blank_video_sync ? 24'h000000 : (pixel ? {(6'h3f - CONT_sync), 2'b00, (6'h3f - CONT_sync), 2'b00, (6'h3f - CONT_sync), 2'b00} : 24'h000000);
            end else begin
                // If we're outside the active area, output a dark gray border
                rgb <= 24'h202020;
            end
        end
    end

    // Either 1080p30 or 1080p60 depending on how we instantiated the HDMI interface
    hdmi #(.VIDEO_REFRESH_RATE(60.0), .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16)) hdmi(
        .video_id_code(video_id_code),
        .clk_pixel_x5(clk_pixel_x5), // Input clocks
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        //.reset(~_reset_hdmi), // Reset signal, active high
        .rgb(rgb), // RGB pixel value
        .audio_sample_word({audio_sample_word, audio_sample_word}), // Audio samples (stereo)
        .tmds(tmds), // outputs to HDMI port
        .tmds_clock(tmds_clock),
        .cx(cx), // x and y coordinates of current pixel
        .cy(cy)
    );

endmodule