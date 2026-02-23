/**
 * rpll test
 * @author Tobias Weber
 * @date 22-feb-2026
 * @license see 'LICENSE' file
 */

`default_nettype none

module rpll_test
(
	// main clock
	input wire clk27,

	// keys and leds
	input  wire [1:0] key,
	output wire [5:0] led
);


localparam longint MAIN_HZ   = 27_000_000;
localparam longint SLOW_HZ   =          2;

localparam int     PLL_NUM   =          1;
localparam int     PLL_DENOM =          3;
localparam longint PLL_HZ    = MAIN_HZ * PLL_NUM / PLL_DENOM;
localparam int     PLL_SDIV  =          4;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst = 1'b0;

//debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
//	.in_signal(~key[1]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// clocks
// ----------------------------------------------------------------------------
wire pll_clk, pll_clk_p, pll_clk_div, pll_clk_div3, pll_lock;

rPLL #(.FCLKIN("27"), .DEVICE("GW2AR-18C"), //.DEVICE("GW2A-18C"),
	// static clock parameters
	// (use dynamic values by setting the respective DYN_*_SEL paramters to "true")
	.IDIV_SEL(PLL_DENOM - 1), .FBDIV_SEL(PLL_NUM - 1), .ODIV_SEL(64),
	// static duty and phase parameters
	.DUTYDA_SEL("1000"), .PSDA_SEL("0000"), .DYN_SDIV_SEL(PLL_SDIV))
rpll_clk (.RESET(rst), .RESET_P(rst),
	.CLKIN(clk27), .CLKFB(1'b0),
	.CLKOUT(pll_clk), .LOCK(pll_lock),
	.CLKOUTD(pll_clk_div), .CLKOUTD3(pll_clk_div3), .CLKOUTP(pll_clk_p),
	// dynamic clock values
	.IDSEL(6'h0), .FBDSEL(6'h0), .ODSEL(6'h0),
	// dynamic duty and phase values
	.DUTYDA(4'h0), .PSDA(4'h0), .FDLY(4'h0)
);


wire slow_clk, slow_clk2, slow_clk2p, slow_clk3, slow_clk4;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_HZ), .CLK_HZ(SLOW_HZ))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk), .out_re());

clkpulsegen #(.MAIN_CLK_HZ(PLL_HZ), .CLK_HZ(SLOW_HZ))
clk_slow2 (.in_clk(pll_clk), .in_rst(rst), .out_clk(slow_clk2), .out_re());

clkpulsegen #(.MAIN_CLK_HZ(PLL_HZ), .CLK_HZ(SLOW_HZ))
clk_slow2p (.in_clk(pll_clk_p), .in_rst(rst), .out_clk(slow_clk2p), .out_re());

clkpulsegen #(.MAIN_CLK_HZ(PLL_HZ/PLL_SDIV), .CLK_HZ(SLOW_HZ))
clk_slow3 (.in_clk(pll_clk_div), .in_rst(rst), .out_clk(slow_clk3), .out_re());

clkpulsegen #(.MAIN_CLK_HZ(PLL_HZ/3), .CLK_HZ(SLOW_HZ))
clk_slow4 (.in_clk(pll_clk_div3), .in_rst(rst), .out_clk(slow_clk4), .out_re());
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// outputs
// ----------------------------------------------------------------------------
assign led[0] = ~slow_clk;
assign led[1] = ~slow_clk2;
assign led[2] = ~slow_clk2p;
assign led[3] = ~slow_clk3;
assign led[4] = ~slow_clk4;
assign led[5] = ~pll_lock;
// ----------------------------------------------------------------------------


endmodule
