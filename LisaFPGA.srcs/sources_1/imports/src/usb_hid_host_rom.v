module usb_hid_host_rom(clk, adr, data);
    input clk;
    input [13:0] adr;
    output [3:0] data;
    reg [3:0] data; 
    reg [3:0] mem [0:535];
    initial $readmemh("usb_hid_host_rom.mem", mem);
    always @(posedge clk) data <= mem[adr];
endmodule
