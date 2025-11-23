/**
 * temperature sensor
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 23-nov-2025
 * @license see 'LICENSE' file
 * @references
 *   - [hw] https://www.mouser.com/datasheet/2/758/DHT11-Technical-Data-Sheet-Translated-Version-1143054.pdf
 */

module temperature
#(
	parameter MAIN_CLK = 50_000_000
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// temperature sensor serial data
	inout wire inout_dat
);


// ----------------------------------------------------------------------------
// wait timers
// ----------------------------------------------------------------------------
localparam WAIT_RESET  = MAIN_CLK/1000*100;  // 100 ms
localparam WAIT_START0 = MAIN_CLK/1000*20;   // 20 ms [hw, p. 6]

logic [$clog2(WAIT_RESET /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;


always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1) begin
		wait_ctr <= 1'b0;
	end else begin
		// timer register
		if(wait_ctr == wait_ctr_max) begin
			// reset timer counter
			wait_ctr <= $size(wait_ctr)'(1'b0);
		end else begin
			// next timer counter
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
		end
	end
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// state machine
// ----------------------------------------------------------------------------
typedef enum { Reset, Start0, StartZ } t_state;
t_state state = Reset, next_state = Reset;


always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1) begin
		state <= Reset;
	end else begin
		state <= next_state;
	end
end


always_comb begin
	next_state = state;
	wait_ctr_max = WAIT_RESET;

	unique case(state)
		Reset: begin
			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = Start0;
		end

		// send part 1 of the start signal: pull data line low
		Start0: begin
			wait_ctr_max = WAIT_START0;
			if(wait_ctr == wait_ctr_max)
				next_state = StartZ;
		end

		// send part 2 of the start signal: leave data line to default pull-up
		StartZ: begin
		end

		default: begin
			next_state = Reset;
		end
	endcase
end
// ----------------------------------------------------------------------------


// TODO: track response


// ----------------------------------------------------------------------------
// input / output
// ----------------------------------------------------------------------------
assign inout_dat = (state == Start0 ? 1'b0 : 1'bz);
// ----------------------------------------------------------------------------


endmodule
