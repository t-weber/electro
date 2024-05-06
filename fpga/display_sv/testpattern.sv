/**
 * video testpattern
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date jan-2021, mar-2024
 * @license see 'LICENSE' file
 */

module testpattern
#(
	// colour channels
	// number of bits in one colour channel
	parameter COLOUR_BITS = 8,
	// number of bits in all colour channels
	parameter PIXEL_BITS = 3 * COLOUR_BITS,

	// rows and columns
	parameter HPIX = 1920,
	parameter VPIX = 1080,

	// counter bits
	parameter HCTR_BITS = $clog2(HPIX),
	parameter VCTR_BITS = $clog2(VPIX)
 )
(
	input wire [HCTR_BITS - 1 : 0] in_hpix,
	input wire [VCTR_BITS - 1 : 0] in_vpix,

	output wire [PIXEL_BITS - 1 : 0] out_pattern
);


assign out_pattern = {PIXEL_BITS{  // repeat to fill pixel bits
	COLOUR_BITS'(in_hpix * in_vpix + 1'b1)}};


endmodule
