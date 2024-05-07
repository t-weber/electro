/**
 * debounces a signal (e.g. a button)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 22-april-2023
 * @license see 'LICENSE' file
 */


/**
 *                     1       -----
 * debounces a button:        |     |
 *                     0 -----       -----
 */
module debounce_button
#(
	parameter STABLE_TICKS = 50,
	parameter STABLE_TICKS_BITS = $clog2(STABLE_TICKS) + 1
)
(
	input wire in_clk, in_rst,
	input wire in_signal,
	output wire out_debounced
);


// button states
typedef enum bit [1:0] { NotPressed, Pressed, Released } t_btnstate;
t_btnstate btnstate = NotPressed, btnstate_next = NotPressed;

// cycle counter
logic [STABLE_TICKS_BITS-1 : 0] stable_counter = 0, stable_counter_next = 0;

// output the debounced signal
logic debounced = 0, debounced_next = 0;
assign out_debounced = debounced;


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst == 1) begin
		btnstate <= NotPressed;
		debounced <= 0;
		stable_counter <= 0;
	end
	else if(in_clk == 1) begin
		btnstate <= btnstate_next;
		stable_counter <= stable_counter_next;
		debounced <= debounced_next;
	end
end


// debouncing process
always_comb begin
	// keep values
	btnstate_next = btnstate;
	stable_counter_next = stable_counter;
	debounced_next = 0;

	case(btnstate)
		NotPressed:
			begin
				// button being pressed?
				if(in_signal)
					stable_counter_next = stable_counter + 1'b1;
				else
					stable_counter_next = 0;

				if(stable_counter == STABLE_TICKS) begin
					stable_counter_next = 0;
					btnstate_next = Pressed;
				end
			end

		Pressed:
			begin
				// button being released?
				if(!in_signal)
					stable_counter_next = stable_counter + 1'b1;
				else
					stable_counter_next = 0;

				if(stable_counter == STABLE_TICKS) begin
					stable_counter_next = 0;
					btnstate_next = Released;
				end
			end

		Released:
			begin
				stable_counter_next = 0;
				btnstate_next = NotPressed;
				debounced_next = 1;
			end
	endcase
end


endmodule
