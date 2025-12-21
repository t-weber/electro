/**
 * video testpattern
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date may-2024
 * @license see 'LICENSE' file
 */

module testpattern
#(
	// number of bits in the colour channels
	parameter RED_BITS   = 5,
	parameter GREEN_BITS = 6,
	parameter BLUE_BITS  = 5,

	// number of bits in all colour channels
	parameter PIXEL_BITS = RED_BITS + GREEN_BITS + BLUE_BITS,

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


wire [RED_BITS - 1 : 0] red;
wire [GREEN_BITS - 1 : 0] green;
wire [BLUE_BITS - 1 : 0] blue;


assign red =
	in_vpix <= VPIX/2 && in_hpix <= HPIX/3                       ? {RED_BITS{1'b1}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3 ? {RED_BITS{1'b0}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX*2/3                      ? {RED_BITS{1'b0}} :
	in_vpix > VPIX/2 && in_hpix <= HPIX/3                        ? {RED_BITS{1'b1}} :
	in_vpix > VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3  ? {RED_BITS{1'b0}} :
	in_vpix > VPIX/2 && in_hpix > HPIX*2/3                       ? {RED_BITS{1'b1}}
		: {RED_BITS{1'b0}};

assign green =
	in_vpix <= VPIX/2 && in_hpix <= HPIX/3                       ? {GREEN_BITS{1'b0}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3 ? {GREEN_BITS{1'b1}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX*2/3                      ? {GREEN_BITS{1'b0}} :
	in_vpix > VPIX/2 && in_hpix <= HPIX/3                        ? {GREEN_BITS{1'b0}} :
	in_vpix > VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3  ? {GREEN_BITS{1'b1}} :
	in_vpix > VPIX/2 && in_hpix > HPIX*2/3                       ? {GREEN_BITS{1'b1}}
		: {GREEN_BITS{1'b0}};

assign blue =
	in_vpix <= VPIX/2 && in_hpix <= HPIX/3                       ? {BLUE_BITS{1'b0}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3 ? {BLUE_BITS{1'b0}} :
	in_vpix <= VPIX/2 && in_hpix > HPIX*2/3                      ? {BLUE_BITS{1'b1}} :
	in_vpix > VPIX/2 && in_hpix <= HPIX/3                        ? {BLUE_BITS{1'b1}} :
	in_vpix > VPIX/2 && in_hpix > HPIX/3 && in_hpix <= HPIX*2/3  ? {BLUE_BITS{1'b1}} :
	in_vpix > VPIX/2 && in_hpix > HPIX*2/3                       ? {BLUE_BITS{1'b1}}
		: {BLUE_BITS{1'b0}};


// pixel output
assign out_pattern = { red, green, blue };


endmodule
