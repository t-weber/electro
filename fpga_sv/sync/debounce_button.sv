/**
 * debounces a signal (e.g. a button), creates a single pulse, and toggles a state
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

	output wire out_debounced,  // single pulse
	output wire out_toggled     // toggled state
);


// button states
typedef enum bit [1:0] { NotPressed, Pressed, Released } t_btnstate;
t_btnstate btnstate = NotPressed, btnstate_next = NotPressed;

// cycle counter
logic [STABLE_TICKS_BITS-1 : 0] stable_counter = 0, stable_counter_next = 0;

// output the debounced signal
logic debounced = 1'b0, debounced_next = 1'b0;
assign out_debounced = debounced;

// output the toggled state
logic toggled = 1'b0, toggled_next = 1'b0;
assign out_toggled = toggled;


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst == 1'b1) begin
		btnstate <= NotPressed;
		debounced <= 1'b0;
		toggled <= 1'b0;
		stable_counter <= 0;
	end
	else begin
		btnstate <= btnstate_next;
		debounced <= debounced_next;
		toggled <= toggled_next;
		stable_counter <= stable_counter_next;
	end
end


// debouncing process
always_comb begin
	// default values
	btnstate_next = btnstate;
	debounced_next = 1'b0;
	toggled_next = toggled;
	stable_counter_next = stable_counter;

	unique case(btnstate)
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
				debounced_next = 1'b1;
				toggled_next = ~toggled;
			end

			default: begin end
	endcase
end


endmodule
