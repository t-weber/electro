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
	parameter longint MAIN_CLK     = 50_000_000,
	parameter int     DATA_BITS    = 8,
	parameter bit     USE_CHECKSUM = 1'b1
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// temperature (integer and decimal)
	output wire [DATA_BITS - 1 : 0] out_temp,
	output wire [DATA_BITS - 1 : 0] out_temp_dec,

	// humidity (integer and decimal)
	output wire [DATA_BITS - 1 : 0] out_humid,
	output wire [DATA_BITS - 1 : 0] out_humid_dec,

	// temperature sensor serial data
	inout wire inout_dat
);


// ----------------------------------------------------------------------------
// wait timers
// ----------------------------------------------------------------------------
localparam longint WAIT_RESET    = MAIN_CLK;                // 1 s
localparam longint WAIT_START0   = MAIN_CLK * 20 / 1_000;   // 20 ms [hw, p. 6]
localparam longint WAIT_FINISHED = MAIN_CLK * 500 / 1_000;  // 500 ms

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
// track response, poll inout_dat every us
// ----------------------------------------------------------------------------
localparam longint POLLING_CLK     = 1_000_000;  // 1 us
localparam int     START_SIGNAL_US = 70;         // max. 80 us [hw, p. 6]
localparam int     ZERO_SIGNAL_US  = 35;         // max. 28 us at 'z' meaning '0' and 70 us meaning '1' [hw, pp. 7, 8]
localparam int     ZERO_BIT_US     = 40;         // max. 50 us at '0' [hw, pp. 7, 8]

logic poll_clk;
logic cur_dat = 1'b0, last_dat = 1'b0;
logic [7 : 0] dat0_us = 1'b0;   // number of us that the signal has been at '0'
logic [7 : 0] dat1_us = 1'b0;   // number of us that the signal has been at '1' (i.e. 'z')

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(POLLING_CLK), .CLK_INIT(1'b1))
	poll_clk_mod(.in_clk(in_clk), .in_rst(in_rst), .out_clk(poll_clk));

always_ff@(posedge poll_clk) begin
	last_dat <= cur_dat;
	cur_dat <= inout_dat;

	if(dat_posedge)
		dat1_us <= 1'b0;
	else if(cur_dat == 1'b1)
		dat1_us <= dat1_us + 1'b1;

	if(dat_negedge)
		dat0_us <= 1'b0;
	else if(cur_dat == 1'b0)
		dat0_us <= dat0_us + 1'b1;
end

logic dat_posedge = (last_dat == 1'b0 && cur_dat == 1'b1);
logic dat_negedge = (last_dat == 1'b1 && cur_dat == 1'b0);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// state machine
// ----------------------------------------------------------------------------
typedef enum
{
	Reset,
	SendStart0, SendStartZ,
	ReceiveStart0, ReceiveStartZ,
	ReceiveBitWait, ReceiveBit,
	Verify, Finished
} t_state;
t_state state = Reset, next_state = Reset;


// the sensor's data register
localparam NUM_BITS = 40;
logic [NUM_BITS - 1 : 0] data = 1'b0, next_data = 1'b0;
logic [NUM_BITS - 1 : 0] final_data = 1'b0, next_final_data = 1'b0;
logic [$clog2(NUM_BITS) : 0] bit_ctr = 1'b0, next_bit_ctr = 1'b0;


// checksum calculation
logic checksum_ok;
generate if(USE_CHECKSUM) begin
	logic [DATA_BITS + 1 : 0] checksum;
	assign checksum =
		data[NUM_BITS - 1 - 0*DATA_BITS -: DATA_BITS] +
		data[NUM_BITS - 1 - 1*DATA_BITS -: DATA_BITS] +
		data[NUM_BITS - 1 - 2*DATA_BITS -: DATA_BITS] +
		data[NUM_BITS - 1 - 3*DATA_BITS -: DATA_BITS];

	assign checksum_ok = (checksum[DATA_BITS - 1 : 0] == data[NUM_BITS - 1 - 4*DATA_BITS -: DATA_BITS]);
end else begin
	assign checksum_ok = 1'b1;
end
endgenerate


always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1) begin
		state <= Reset;
		data <= 1'b0;
		final_data <= 1'b0;
		bit_ctr <= 1'b0;
	end else begin
		state <= next_state;
		data <= next_data;
		final_data <= next_final_data;
		bit_ctr <= next_bit_ctr;
	end
end


always_comb begin
	next_state = state;
	next_data = data;
	next_final_data = final_data;
	next_bit_ctr = bit_ctr;
	wait_ctr_max = WAIT_RESET;

	unique case(state)
		Reset: begin
			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = SendStart0;
		end

		// send part 1 of the start signal: pull data line low
		SendStart0: begin
			wait_ctr_max = WAIT_START0;
			if(wait_ctr == wait_ctr_max)
				next_state = SendStartZ;
		end

		// send part 2 of the start signal: leave data line to default pull-up
		// and wait for it to be pulled down by the sensor
		SendStartZ: begin
			next_data = 1'b0;
			next_bit_ctr = 1'b0;

			if(dat_negedge)
				next_state = ReceiveStart0;
		end

		// receive the sensor's start signal: 0 (START_SIGNAL_US) [hw, p. 6]
		ReceiveStart0: begin
			if(dat_posedge && dat0_us >= START_SIGNAL_US)
				next_state = ReceiveStartZ;
		end

		// receive the sensor's start signal: 1 (START_SIGNAL_US) [hw, p. 6]
		ReceiveStartZ: begin
			if(dat_negedge && dat1_us >= START_SIGNAL_US)
				next_state = ReceiveBitWait;
		end

		ReceiveBitWait: begin
			if(dat_posedge && dat0_us >= ZERO_BIT_US)
				next_state = ReceiveBit;
		end

		ReceiveBit: begin
			if(dat_negedge) begin
				if(dat1_us < ZERO_SIGNAL_US) begin
					// received '0'
					next_data[NUM_BITS - 1 - bit_ctr] = 1'b0;
				end else begin
					// received '1'
					next_data[NUM_BITS - 1 - bit_ctr] = 1'b1;
				end

				// next bit
				next_bit_ctr = bit_ctr + 1'b1;
				next_state = ReceiveBitWait;

				// all bits received?
				if(bit_ctr == NUM_BITS - 1'b1)
					next_state = Verify;
			end
		end

		Verify: begin
			if(checksum_ok)
				next_final_data = data;
			next_state = Finished;
		end

		Finished: begin
			// wait before next read
			wait_ctr_max = WAIT_FINISHED;
			if(wait_ctr == wait_ctr_max)
				next_state = SendStart0;
		end

		default: begin
			next_state = Reset;
		end
	endcase
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// input / output
// ----------------------------------------------------------------------------
assign inout_dat     = (state == SendStart0 ? 1'b0 : 1'bz);

assign out_humid     = final_data[NUM_BITS - 1 - 0*DATA_BITS -: DATA_BITS];
assign out_humid_dec = final_data[NUM_BITS - 1 - 1*DATA_BITS -: DATA_BITS];

assign out_temp      = final_data[NUM_BITS - 1 - 2*DATA_BITS -: DATA_BITS];
assign out_temp_dec  = final_data[NUM_BITS - 1 - 3*DATA_BITS -: DATA_BITS];
// ----------------------------------------------------------------------------


endmodule
