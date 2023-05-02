/**
 * debounces a signal (e.g. a switch)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 22-april-2023
 * @license see 'LICENSE' file
 */


/**
 *                     1       -----
 * debounces a switch:        |
 *                     0 -----
 */
module debounce_switch
#(
	parameter STABLE_TICKS = 50,
	parameter STABLE_TICKS_BITS = $clog2(STABLE_TICKS) + 1
)
(
	input wire in_clk, in_rst,
	input wire in_signal,
	output wire out_debounced
);


// has the signal toggled?
localparam NUM_STEPS = 3;
logic [0 : NUM_STEPS-1] shiftreg;
logic signal_changed;
assign signal_changed = shiftreg[0] ^ shiftreg[1];


// output the debounced signal
logic debounced = 0, debounced_next = 0;
assign out_debounced = debounced;


// count the cycles the signal has been stable
logic [STABLE_TICKS_BITS-1 : 0] stable_counter = 0, stable_counter_next = 0;
always@(stable_counter) begin
	stable_counter_next <= stable_counter + 1'b1;
end


// clock process
integer shift_idx;
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst == 1) begin
		shiftreg <= 0;
		debounced <= 0;
		stable_counter <= 0;
	end
	else if(in_clk == 1) begin
		// write signal in shift register
		shiftreg[0] <= in_signal;
		for(shift_idx=1; shift_idx<NUM_STEPS; ++shift_idx) begin
			shiftreg[shift_idx] <= shiftreg[shift_idx-1];
		end

		// count the cycles the signal has been stable
		if(signal_changed == 1) begin
			stable_counter <= 0;
		end else begin
			stable_counter <= stable_counter_next;
		end

		debounced <= debounced_next;
	end
end


// output sampling process
//always@(stable_counter, debounced, shiftreg[NUM_STEPS-1]) begin
always_comb begin
	// keep value
	debounced_next <= debounced;

	// if the signal has been stable, sample a new value
	if(stable_counter == STABLE_TICKS) begin
		debounced_next <= shiftreg[NUM_STEPS-1];
	end;
end


endmodule
