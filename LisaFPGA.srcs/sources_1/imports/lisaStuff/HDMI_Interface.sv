/*module HDMI_Interface(
    input  logic sysclk,
    input  logic _reset,
    input  logic DOTCK,
    input  logic _VSYNC,
    input  logic _HSYNC,
    input  logic VID,
    output logic tmds_clock,
    output logic [2:0] tmds
);

    // ----------------------------------------------------------------
    // HDMI PLL: generate pixel clocks
    // ----------------------------------------------------------------
    logic clk_pixel;
    logic clk_pixel_x5;
    logic clk_audio;

    //hdmi_pll_xilinx pll(
    //    .clk_in1(sysclk),
    //    .clk_out1(clk_pixel),
    //    .clk_out2(clk_pixel_x5)
    //);

    HDMI_MMCM_Mode2_59Hz hdmi_clockgen (
        .sysclk(sysclk),
        .clk_pixel(clk_pixel),
        .clk_pixel_x5(clk_pixel_x5)
    );

    //HDMI_MMCM_Mode34_30Hz hdmi_clockgen (
    //    .sysclk(sysclk),
    //    .clk_pixel(clk_pixel),
    //    .clk_pixel_x5(clk_pixel_x5)
    //);

    // Dummy audio
    logic [10:0] counter = 1'd0;
    always_ff @(posedge clk_pixel) begin
        counter <= counter == 11'd1546 ? 1'd0 : counter + 1'd1;
    end
    assign clk_audio = clk_pixel && (counter == 11'd1546);

    logic [15:0] audio_sample_word [1:0];
    assign audio_sample_word = '{16'd0, 16'd0}; // silence

    // ----------------------------------------------------------------
    // Framebuffer (double-buffered)
    // ----------------------------------------------------------------
    // Each buffer: 32K bytes = Lisa’s 720*364/8 = ~32K
    logic [7:0] buf0 [0:32759];
    logic [7:0] buf1 [0:32759];

    (* MARK_DEBUG = "TRUE" *) logic active_buf;     // 0 = buf0 is displayed, 1 = buf1 is displayed
    (* MARK_DEBUG = "TRUE" *) logic write_buf_sel;  // opposite of active_buf
    (* MARK_DEBUG = "TRUE" *) logic swap_request;   // handshake for VSYNC swap

    // ----------------------------------------------------------------
    // Video capture domain (DOTCK, negedge)
    // ----------------------------------------------------------------
    (* MARK_DEBUG = "TRUE" *) logic [14:0] byte_counter;
    (* MARK_DEBUG = "TRUE" *) logic [2:0]  bit_counter;
    (* MARK_DEBUG = "TRUE" *) logic [7:0]  current_byte;

    always_ff @(negedge DOTCK) begin
        if (!_reset) begin
            bit_counter  <= 0;
            byte_counter <= 0;
            current_byte <= 8'd0;
            swap_request <= 0;
        end else begin
            if (_VSYNC == 1'b0) begin
                // VSYNC low: restart and request buffer swap
                bit_counter  <= 0;
                byte_counter <= 0;
                current_byte <= 8'd0;
                swap_request <= 1;
            end else if (_HSYNC == 1'b0) begin
                swap_request <= 0;
                // Active video region
                current_byte <= {current_byte[6:0], VID};
                if (bit_counter == 3'd7) begin
                    if (write_buf_sel == 1'b0)
                        buf0[byte_counter] <= {current_byte[6:0], VID};
                    else
                        buf1[byte_counter] <= {current_byte[6:0], VID};

                    byte_counter <= byte_counter + 1;
                    bit_counter  <= 0;
                    current_byte <= 0;
                end else begin
                    bit_counter <= bit_counter + 1;
                end
            end else begin
                swap_request <= 0;
                // hblank, still advance bits (just like active branch above?)
                if (bit_counter == 3'd7) begin
                    if (write_buf_sel == 1'b0)
                        buf0[byte_counter] <= {current_byte[6:0], VID};
                    else
                        buf1[byte_counter] <= {current_byte[6:0], VID};

                    byte_counter <= byte_counter + 1;
                    bit_counter  <= 0;
                    current_byte <= 0;
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Buffer swap synchronizer (DOTCK → clk_pixel)
    // -------------------------------------MARK_DEBUG---------------------------------
    (* MARK_DEBUG = "TRUE" *) logic swap_request_sync1, swap_request_sync2;
    always_ff @(posedge clk_pixel) begin
        if (!_reset) begin
            active_buf    <= 1'b0;
            write_buf_sel <= 1'b1;
            swap_request_sync1 <= 1'b0;
            swap_request_sync2 <= 1'b0;
        end
        swap_request_sync1 <= swap_request;
        swap_request_sync2 <= swap_request_sync1;
        if (swap_request_sync1 && !swap_request_sync2) begin
            // swap buffers
            active_buf    <= ~active_buf;
            write_buf_sel <= active_buf; // opposite
        end
    end

    // ----------------------------------------------------------------
    // HDMI readout (clk_pixel domain)
    // ----------------------------------------------------------------
    (* MARK_DEBUG = "TRUE" *) logic [23:0] rgb;
    (* MARK_DEBUG = "TRUE" *) logic [11:0] cx;
    (* MARK_DEBUG = "TRUE" *) logic [10:0] cy;

    //(* MARK_DEBUG = "TRUE" *) logic [9:0] lisa_x, lisa_y;
    (* MARK_DEBUG = "TRUE" *) logic [18:0] fb_index;
    (* MARK_DEBUG = "TRUE" *) logic [14:0] word_index;
    (* MARK_DEBUG = "TRUE" *) logic [2:0]  bit_index;
    (* MARK_DEBUG = "TRUE" *) logic pixel;

    always_comb begin
        // Scale mapping: 1920x1080 -> 720x364 doubled/tripled
        //lisa_x     = (cx - 240) >> 1;  // 0–719
        //lisa_y     = cy / 3;           // 0–363
        //fb_index   = lisa_y * 720 + lisa_x; // 0..262143
        //word_index = fb_index >> 3;
        //bit_index  = fb_index & 7;
        fb_index = (cy * 720) + cx;
        word_index = fb_index >> 3;
        bit_index  = fb_index & 7;

        if (active_buf == 1'b0)
            pixel = buf0[word_index][bit_index];
        else
            pixel = buf1[word_index][bit_index];
    end

    always_ff @(posedge clk_pixel) begin
        //if (cx >= 240 && cx < 1680 && cy < 1092) begin
        if (cy < 364) begin
            rgb <= pixel ? 24'h000000 : 24'hFFFFFF;
        end else begin
            rgb <= 24'h202020; // border
        end
    end

    // ----------------------------------------------------------------
    // HDMI IP Core
    // ----------------------------------------------------------------
    hdmi #(
        .VIDEO_ID_CODE(2), //2
        .VIDEO_REFRESH_RATE(59.94), //59.94
        .AUDIO_RATE(48000),
        .AUDIO_BIT_WIDTH(16)
    ) hdmi_inst (
        .clk_pixel_x5(clk_pixel_x5),
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .reset(~_reset),
        .rgb(rgb),
        .audio_sample_word(audio_sample_word),
        .tmds(tmds),
        .tmds_clock(tmds_clock),
        .cx(cx),
        .cy(cy)
    );

endmodule*/



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


module HDMI_Interface(
    input logic sysclk,
    input logic _reset,
    input logic DOTCK,
    input logic VA_overflow, // Replaces VSYNC; active high during vertical blanking
    input logic _clr_vid_clk, // Replaces _HSYNC; active low during horizontal blanking
    input logic VID,
    input logic [5:0] CONT,
    input logic TONE,
    input logic [2:0] VC,
    input logic CPU_ROM_SEL,
    output logic tmds_clock,
    output logic [2:0] tmds
    );

    // Synchronise the reset signal (from the DOTCK domain) to the HDMI pixel clock domain
    // Otherwise we have tons of metastability issues`
    logic _reset_hdmi_int, _reset_hdmi;
    // We use a two-stage synchronizer here
    always_ff @(posedge clk_pixel) begin
        _reset_hdmi_int <= _reset;
        _reset_hdmi <= _reset_hdmi_int;
    end
    
    logic clk_pixel;
    logic clk_pixel_x5;
    logic clk_audio;

    hdmi_pll_xilinx pll(.clk_in1(sysclk), .clk_out1(clk_pixel), .clk_out2(clk_pixel_x5));

    /*HDMI_MMCM_Mode16_60Hz hdmi_clockgen (
        .sysclk(sysclk),
        .clk_pixel(clk_pixel),
        .clk_pixel_x5(clk_pixel_x5)
    );*/

    logic [10:0] counter = 1'd0;
    always_ff @(posedge clk_pixel)
    begin
        counter <= counter == 11'd1546 ? 1'd0 : counter + 1'd1;
    end
    assign clk_audio = clk_pixel && counter == 11'd1546;

    (* MARK_DEBUG = "TRUE" *) logic [15:0] audio_sample_word;

    // Now let's do the audio sample generation
    // We take our input audio square wave on TONE and volume on VC (3 bits)
    // And then we convert it to two 16-bit audio samples (stereo)
    // Both channels will be the same since the Lisa is mono
    // We need to convert the square wave to a PCM value, and scale it linearly based on VC
    // VC = 000 = mute, VC = 111 = max volume
    // So when TONE is high, output max_volume, when TONE is low, output 0
    // max_volume = (VC / 7) * 65535
    // So final output = TONE ? max_volume : 0

    // LOS's volume levels are 0 for off (duh), 3 for Soft, 4, 5, and 6 for the in between levels, and 7 for Loud
    // But then after you select it, it remaps it to 1-5 from the 3-7, not sure why, maybe it maps it back when a sound actually plays
    // MacWorks Plus uses 0 for volume slider levels 0 and 1, 1 for volume slider levels 2 and 3, 2 for volume slider levels 4 and 5, and 3 for volume slider levels 6 and 7
    // MWP never goes above 3 oddly enough
    logic [15:0] max_volume;
    assign max_volume = (VC == 3'd0) ? 16'd0 :
                        (VC == 3'd1) ? 16'd9362 :
                        (VC == 3'd2) ? 16'd18724 :
                        (VC == 3'd3) ? 16'd28086 :
                        (VC == 3'd4) ? 16'd37448 :
                        (VC == 3'd5) ? 16'd46810 :
                        (VC == 3'd6) ? 16'd56172 :
                                       16'd65535;
    always_ff @(posedge clk_audio) begin
        audio_sample_word <= TONE ? max_volume : 0; //-max_volume;
    end

    logic [23:0] rgb = 24'd0;
    (* MARK_DEBUG = "TRUE" *) logic [11:0] cx;
    (* MARK_DEBUG = "TRUE" *) logic [10:0] cy;

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
    (* MARK_DEBUG = "TRUE" *) logic [9:0] lisa_x, lisa_y;
    (* MARK_DEBUG = "TRUE" *) logic [15:0] word_index;
    (* MARK_DEBUG = "TRUE" *) logic [2:0] bit_index;
    (* MARK_DEBUG = "TRUE" *) logic pixel;
    // Missing one single column of pixels on tghe right of the frame
    // Left side of the frame has 3? (maybe 2 maybe 4) extra columns of black pixels
    (* MARK_DEBUG = "TRUE" *) logic [15:0] byte_counter;
    (* MARK_DEBUG = "TRUE" *) logic [2:0] bit_counter;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] current_byte;
    (* MARK_DEBUG = "TRUE" *) logic [3:0] end_line_overlap_counter;
    (* MARK_DEBUG = "TRUE" *) logic [3:0] start_line_overlap_counter;
    (* MARK_DEBUG = "TRUE" *) logic [1:0] hsync_delay_counter;
    (* MARK_DEBUG = "TRUE" *) logic prev_clr_vid_clk;

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
            start_line_overlap_counter_threshold <= 4'd11; // Wait 11 DOTCKs after HSYNC is over before starting to capture pixels
            end_line_overlap_counter_threshold <= 4'd11; // Keep capturing pixels for 11 DOTCKs after HSYNC starts
        end else begin
            // 3A ROMs; set the start and end line overlap counters for 3A ROM timing, and the the hsync delay counter is zero
            // No delay after VSYNC is over before starting to capture lines; 432*2=864 which fits within 1080 just fine
            hsync_delay_counter_threshold <= 2'd0;
            start_line_overlap_counter_threshold <= 4'd11; // Wait 11 DOTCKs after HSYNC is over before starting to capture pixels
            end_line_overlap_counter_threshold <= 4'd11; // Keep capturing pixels for 11 DOTCKs after HSYNC starts
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

    // I used to do all this in an always_comb block, but it wouldn't meet timing, so now I've pipelined it into 3 stages

    // First up, we compute the Lisa pixel coordinates from the HDMI pixel coordinates
    // Each Lisa pixel is 2x3 HDMI pixels
    always_ff @(posedge clk_pixel) begin
        if (CPU_ROM_SEL == 1'b0) begin
            // If we have H ROMs, then each Lisa pixel is 2x3 HDMI pixels
            lisa_x <= (cx - 240) >> 1; // Remove the start offset of 240 HDMI pixels and divide by 2, gives us Lisa pixel x coordinate 0-719
            lisa_y <= cy / 3; // Divide by 3, gives us Lisa pixel y coordinate 0-363
        end else begin
            // If we have 3A ROMs, then each Lisa pixel is 2x2 HDMI pixels
            lisa_x <= (cx - 352) >> 1; // Remove the start offset of 352 HDMI pixels and divide by 2, gives us Lisa pixel x coordinate 0-607
            lisa_y <= (cy - 108) >> 1; // Remove the start offset of 108 HDMI pixels and divide by 2, gives us Lisa pixel y coordinate 0-431 (or really 0-430 since last line is cut off)
        end
    end

    // Next, we use the Lisa pixel coordinates to compute our bit index into the framebuffer
    // Which we then use to determine which word and bit within that word we need to read from the framebuffer
    always_ff @(posedge clk_pixel) begin
        if (CPU_ROM_SEL == 1'b0) begin
            // H ROMs
            word_index <= (lisa_y * 720 + lisa_x) >> 3; // Combine the x and y and divide by 8 to get word (byte) index
            bit_index  <= (lisa_y * 720 + lisa_x) & 7; // Modulo 8 to get bit index within the byte
        end else begin
            // 3A ROMs
            word_index <= (lisa_y * 608 + lisa_x) >> 3; // Combine the x and y and divide by 8 to get word (byte) index
            bit_index  <= (lisa_y * 608 + lisa_x) & 7; // Modulo 8 to get bit index within the byte
        end
    end

    (* MARK_DEBUG = "TRUE" *) logic [7:0] pixel_word; // For debugging, remove once HDMI is working

    // Finally, we read the proper byte from the framebuffer and extract the pixel bit
    // This is identical for both H and 3A ROMs
    always_ff @(posedge clk_pixel) begin
        pixel_word <= lisa_framebuffer[word_index];
        pixel <= lisa_framebuffer[word_index][bit_index];
end

    // Now we can finally generate the RGB output based on the pixel value
    // But we need to delay cx and cy by 3 clock cycles to match the pixel signal
    (* MARK_DEBUG = "TRUE" *) logic [11:0] cx1, cx2, cx3;
    (* MARK_DEBUG = "TRUE" *) logic [10:0] cy1, cy2, cy3;
    always_ff @(posedge clk_pixel) begin
        cx1 <= cx;
        cx2 <= cx1;
        cx3 <= cx2;
        cy1 <= cy;
        cy2 <= cy1;
        cy3 <= cy2;
    end

    // Note: The "brightest" I've seen anything be able to go on the Lisa is an 0x11 on the CONT value (MacWorks Plus)
    // So maybe make 0x11 full white and scale down from there, just so things are brighter on HDMI?
    // Unless I find some other OS that goes brighter of course!

    // Now generate the RGB value
    always @(posedge clk_pixel) begin
        // Check the ROM revision; the active area of the frame depends on this
        if (CPU_ROM_SEL == 1'b0) begin
            // H ROM active area: (240,0) to (1680,1092)
            if (cx3 >= 240 && cx3 < 1680 && cy3 < 1092) begin
                // Figure out if the pixel is black or white, taking CONT into account
                // No need to worry about INVID since it's already handled on the CPU board
                rgb <= pixel ? {(6'h3f - CONT), 2'b00, (6'h3f - CONT), 2'b00, (6'h3f - CONT), 2'b00} : 24'h000000;
            end else begin
                // If we're outside the active area, output a dark gray border
                rgb <= 24'h202020;
            end
        end else begin
            // 3A ROM active area: (352,108) to (1568,972) or really (1568,970) because of the missing last line
            if (cx3 >= 352 && cx3 < 1568 && cy3 >= 108 && cy3 < 970) begin
                // Figure out if the pixel is black or white, taking CONT into account
                // No need to worry about INVID since it's already handled on the CPU board
                rgb <= pixel ? {(6'h3f - CONT), 2'b00, (6'h3f - CONT), 2'b00, (6'h3f - CONT), 2'b00} : 24'h000000;
            end else begin
                // If we're outside the active area, output a dark gray border
                rgb <= 24'h202020;
            end
        end
    end

    // 1920x1080 @ 60Hz
    hdmi #(.VIDEO_ID_CODE(16), .VIDEO_REFRESH_RATE(60.0), .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16)) hdmi(
        .clk_pixel_x5(clk_pixel_x5), // Input clocks
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .reset(~_reset_hdmi), // Reset signal, active high
        .rgb(rgb), // RGB pixel value
        .audio_sample_word({audio_sample_word, audio_sample_word}), // Audio sample, ignore for now
        .tmds(tmds), // outputs to HDMI port
        .tmds_clock(tmds_clock),
        .cx(cx), // x and y coordinates of current pixel
        .cy(cy)
    );

endmodule