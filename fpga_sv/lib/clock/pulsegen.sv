/**
 * generates a clock pulse
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-dec-2025
 * @license see 'LICENSE' file
 */


module pulsegen
#(
	// clock frequencies
	parameter longint MAIN_CLK_HZ = 50_000_000,
	parameter longint CLK_HZ      = 10_000
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// output clock edges
	output wire out_pulse_re, out_pulse_fe
);


// timer pulses corresponding to pulse clock
localparam longint WAIT_DELAY = MAIN_CLK_HZ / CLK_HZ;


// rising edge pulse
logic[$clog2(WAIT_DELAY) : 0] wait_ctr_re = 1'b0;
logic pulse_re;
assign out_pulse_re = pulse_re;

always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		wait_ctr_re <= 1'b0;

	// clock
	end else begin
		pulse_re <= 1'b0;
		if(wait_ctr_re == WAIT_DELAY - 2) begin
			// rising edge of pulse clock
			pulse_re <= 1'b1;
			wait_ctr_re <= 1'b0;
		end else begin
			wait_ctr_re <= $size(wait_ctr_re)'(wait_ctr_re + 1'b1);
		end
	end
end


// falling edge pulse
logic[$clog2(WAIT_DELAY) : 0] wait_ctr_fe = 1'b0;
logic fsm_fe = 1'b0;
logic pulse_fe;
assign out_pulse_fe = pulse_fe;

always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		wait_ctr_fe <= 1'b0;
		fsm_fe = 1'b0;

	// clock
	end else begin
		pulse_fe <= 1'b0;
		wait_ctr_fe <= wait_ctr_fe + 1'b1;
		if(fsm_fe == 1'b0) begin
			// offset timer start to falling edge of pulse clock
			if(wait_ctr_fe == WAIT_DELAY/2 - 1) begin
				fsm_fe <= 1'b1;
				wait_ctr_fe <= 1'b0;
			end
		end else begin
			if(wait_ctr_fe == WAIT_DELAY - 2) begin
				// falling edge of pulse clock
				pulse_fe <= 1'b1;
				wait_ctr_fe <= 1'b0;
			end
		end
	end
end


endmodule
