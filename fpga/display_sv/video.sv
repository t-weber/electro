/**
 * video with parallel interface
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date jan-2021, mar-2024
 * @license see 'LICENSE' file
 *
 * References:
 *	https://www.digikey.com/eewiki/pages/viewpage.action?pageId=15925278
 *	https://academic.csuohio.edu/chu_p/rtl/sopc_vhdl.html
 *	https://www.analog.com/media/en/technical-documentation/user-guides/ADV7513_Programming_Guide.pdf
 */

module video
#(
	// colour channels
	// number of bits in one colour channel
	parameter COLOUR_BITS = 8,
	// number of bits in all colour channels
	parameter PIXEL_BITS = 3 * COLOUR_BITS,

	// rows
	parameter HSYNC_START  = 88,
	parameter HSYNC_STOP   = 88 + 44,
	parameter HSYNC_DELAY  = 88 + 44 + 148,
	parameter HPIX_VISIBLE = 1920,
	parameter HPIX_TOTAL   = HPIX_VISIBLE + HSYNC_DELAY,

	// columns
	parameter VSYNC_START  = 4,
	parameter VSYNC_STOP   = 4 + 5,
	parameter VSYNC_DELAY  = 4 + 5 + 36,
	parameter VPIX_VISIBLE = 1080,
	parameter VPIX_TOTAL   = VPIX_VISIBLE + VSYNC_DELAY,

	// counter bits
	parameter HCTR_BITS = $clog2(HPIX_TOTAL),
	parameter VCTR_BITS = $clog2(VPIX_TOTAL),

	// start address of the display buffer in memory
	parameter MEM_START_ADDR = 0,

	// memory address length
	parameter PIXADDR_BITS = $clog2(VPIX_VISIBLE*HPIX_VISIBLE + MEM_START_ADDR),

	parameter USE_TESTPATTERN = 1
 )
(
	// pixel clock, reset
	// pixel clock frequency = HPIX_TOTAL * VPIX_TOTAL * 60 Hz
	input wire in_clk, in_rst,

	// show test pattern?
	input wire in_testpattern,

	// video interface
	output wire [HCTR_BITS - 1 : 0] out_hpix, out_hpix_raw,
	output wire [VCTR_BITS - 1 : 0] out_vpix, out_vpix_raw,
	output wire out_hsync, out_vsync, out_pixel_enable,
	output wire [PIXEL_BITS - 1 : 0] out_pixel,

	// memory interface
	output wire [PIXADDR_BITS - 1 : 0] out_mem_addr,
	input wire [PIXEL_BITS - 1 : 0] in_mem
);



// current pixel counter in total range
reg [$clog2(HPIX_TOTAL) : 0] h_ctr, h_ctr_next;
reg [$clog2(VPIX_TOTAL) : 0] v_ctr, v_ctr_next;

// current pixel counter in visible range
reg [$clog2(HPIX_VISIBLE) : 0] hpix;
reg [$clog2(VPIX_VISIBLE) : 0] vpix;

// in visible range?
logic visible_range = 1'b0;

// test pattern values
reg [PIXEL_BITS - 1 : 0] pattern;


// row / column counters
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst == 1) begin
		h_ctr <= 0;
		v_ctr <= 0;
	end

	else if(in_clk == 1) begin
		h_ctr <= h_ctr_next;

		// h_ctr is still at its previous value
		if(h_ctr == HPIX_TOTAL - 1)
			v_ctr <= v_ctr_next;
	end
end


always_comb begin
	// pixel counters in visible range?
	visible_range = (
		h_ctr >= HSYNC_DELAY && h_ctr < HPIX_VISIBLE + HSYNC_DELAY &&
		v_ctr >= VSYNC_DELAY && v_ctr < VPIX_VISIBLE + VSYNC_DELAY)
		? 1'b1 : 1'b0;
end


// next column / row
assign h_ctr_next = (h_ctr == HPIX_TOTAL - 1) ? 0 : h_ctr + 1;
assign v_ctr_next = (v_ctr == VPIX_TOTAL - 1) ? 0 : v_ctr + 1;

// current pixel counters
assign hpix = visible_range ? h_ctr - HSYNC_DELAY : 0;
assign vpix = visible_range ? v_ctr - VSYNC_DELAY : 0;

// output pixel counter
assign out_hpix = hpix;
assign out_vpix = vpix;

// output raw pixel counter
assign out_hpix_raw = h_ctr;
assign out_vpix_raw = v_ctr;

// output synchronisation signals
assign out_hsync = (h_ctr >= HSYNC_START && h_ctr < HSYNC_STOP) ? 1'b1 : 1'b0;
assign out_vsync = (v_ctr >= VSYNC_START && v_ctr < VSYNC_STOP) ? 1'b1 : 1'b0;
assign out_pixel_enable = visible_range;

// output pixel
assign out_pixel = in_testpattern ? pattern : in_mem;

// output requested memory address
assign out_mem_addr = (visible_range == 1 && in_testpattern == 0)
	? vpix*HPIX_VISIBLE + hpix + MEM_START_ADDR
	: 0;


// generate test pattern
generate
if(USE_TESTPATTERN) begin
	testpattern
	#(
		.HPIX(HPIX_VISIBLE), .VPIX(VPIX_VISIBLE),
		.COLOUR_BITS(COLOUR_BITS), .PIXEL_BITS(PIXEL_BITS),
		.HCTR_BITS(HCTR_BITS), .VCTR_BITS(VCTR_BITS)
	 )
	testpattern_mod
	(
		.in_hpix(hpix), .in_vpix(vpix),
		.out_pattern(pattern)
	);
end else begin
	assign pattern = 0;
end
endgenerate

endmodule
