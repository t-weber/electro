/**
 * cpu testbench
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 24-aug-2025, 13-sep-2025
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://github.com/YosysHQ/picorv32/tree/main/picosoc
 *   - https://github.com/grughuhler/picorv32_tang_nano_unified/tree/main
 */


`timescale 1ns / 1ps
`default_nettype /*wire*/ none

//`define WRITE_DUMP
//`define USE_INTERRUPTS


module rv_tb();

// ---------------------------------------------------------------------------
// create clock
// ---------------------------------------------------------------------------
logic clock = 1'b0;
integer iter, maxiter/*, iter_freq*/;

initial begin
`ifndef USE_INTERRUPTS
	$display("Disabling interrupts.");
`endif

	if($value$plusargs("iter=%d", maxiter)) begin
		$display("Maximum number of clock cycles: %d", maxiter);
	end else begin
		maxiter = 3000;
		$display("Maximum number of clock cycles: %d. Set using +iter=<num> argument.", maxiter);
	end

`ifdef WRITE_DUMP
	$dumpfile("rv_tb.vcd");
	$dumpvars(0, rv_tb);
`endif

	for(iter = 0; iter < maxiter; ++iter) begin
		//for(iter_freq = 0; iter_freq < 1000; ++iter_freq) begin
			clock <= ~clock;
			#1;
		//end

`ifdef USE_INTERRUPTS
		// TODO: generate a test interrupt (when enabled)
//		if(iter >= 1650 && iter < 1660)
//			main_mod.cpu_irq <= 4'b1000;
//		else
//			main_mod.cpu_irq <= 4'b0000;
`endif
	end

`ifdef WRITE_DUMP
	$dumpflush();
`endif
end
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// main module
// ---------------------------------------------------------------------------
rv_main #(
	.MAIN_CLK(1), .SLOW_CLK(1)
)
main_mod(
	.clk27(clock)
);
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// debug output
// ---------------------------------------------------------------------------
`ifdef DEBUG
always@(posedge clock) begin
	if(main_mod.state == main_mod.RUN_CPU) begin
		$display("clk=%b, ", clock, "iter=%4d, ", iter,
`ifdef USE_INTERRUPTS
			"irq=%h, ", main_mod.cpu_irq, "irq_end=%h, ", main_mod.cpu_irq_ended,
`endif
			"addr=%h, ", main_mod.addr_1, /*"fulladdr=%h, ", main_mod.cpu_addr,*/
			"byte=%h, ", main_mod.cpu_bytesel,
			"mem->cpu=%h, ", main_mod.out_data_1, "cpu->mem=%h, ", main_mod.in_data_1,
			"valid=%b, ", main_mod.cpu_mem_valid,
			"mem[%h]=%h.", main_mod.addr_2, main_mod.out_data_2);
	end
end
`endif
// ---------------------------------------------------------------------------


endmodule
