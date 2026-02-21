/**
 * generates a simple rectangular audio signal
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 15-feb-2026
 * @license see 'LICENSE' file
 *
 * reference for wave form:
 *   - https://www.analog.com/media/en/technical-documentation/data-sheets/ssm2603.pdf, p. 16
 */

module audio
#(
	parameter TONE_BITS   = 16,     // number of bits for the tone frequency
	parameter FRAME_BITS  = 32,     // number of bits in a sample frame
	parameter SAMPLE_BITS = 16,     // number of sample bits (for encoding the amplitude)
	parameter SAMPLE_FREQ = 44_100  // number of sample per second (*2 channels)
 )
(
	input wire in_reset,
	input wire in_bitclk,
	input wire in_sampleclk,

	input wire[TONE_BITS - 1 : 0] in_tone_hz,

	output wire out_data,           // current sample bit
	output wire out_samples_end     // for debugging
);


// counters
logic [$clog2(FRAME_BITS - 1) : 0] bit_ctr = 1'b0;
logic [$clog2(SAMPLE_FREQ - 1) : 0] sec_ctr = 1'b0;


// sample bit output
logic [FRAME_BITS - 1 : 0] amp, next_amp;
assign out_data = amp[0];


// clock for tone generation
logic tone_clk;
clkgen_var #(.MAIN_HZ(SAMPLE_FREQ), .HZ_BITS(TONE_BITS))
tone_clkgen(.in_clk(in_sampleclk), .in_reset(in_reset),
	.in_clk_hz(in_tone_hz), .in_clk_shift(1'b0), .in_clk_init(1'b0),
	.out_clk(tone_clk));


always_ff@(posedge in_bitclk, posedge in_reset) begin
	if(in_reset == 1'b1) begin
		bit_ctr <= 1'b0;
		amp <= 1'b0;

	end else begin
		if(bit_ctr < FRAME_BITS - 1'b1)
			bit_ctr <= bit_ctr + 1'b1;
		else
			bit_ctr <= 1'b0;

		amp <= next_amp;
	end
end



always_ff@(negedge in_sampleclk, posedge in_reset) begin
	if(in_reset == 1'b1) begin
		sec_ctr <= 1'b0;
	end else begin
		if(sec_ctr < SAMPLE_FREQ - 1'b1)
			sec_ctr <= sec_ctr + 1'b1;
		else
			sec_ctr <= 1'b0;
	end
end


always_comb begin
	next_amp = amp;
	
	if(bit_ctr == 1'b0) begin
		// set new output amplitude
		next_amp = { (FRAME_BITS - SAMPLE_BITS)'((1'b0)), tone_clk, 2'b0 };
	end else begin
		// shift output amplitude bits
		next_amp = amp >> 1'b1; //{ 1'b0, amp[FRAME_BITS - 1 : 1] };
	end
end


endmodule
