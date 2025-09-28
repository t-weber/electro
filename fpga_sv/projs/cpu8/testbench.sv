/**
 * cpu testbench
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date August/Sepember-2025
 * @license see 'LICENSE' file
 */


`timescale 1ns / 1ps
`default_nettype /*wire*/ none

//`define WRITE_DUMP
//`define USE_INTERRUPTS


module cpu_tb();

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
		maxiter = 256;
		$display("Maximum number of clock cycles: %d. Set using +iter=<num> argument.", maxiter);
	end

`ifdef WRITE_DUMP
	$dumpfile("cpu_tb.vcd");
	$dumpvars(0, cpu_tb);
`endif

	for(iter = 0; iter < maxiter; ++iter) begin
		//for(iter_freq = 0; iter_freq < 1000; ++iter_freq) begin
			clock <= ~clock;
			#1;
		//end

`ifdef USE_INTERRUPTS
		// TODO: generate a test interrupt (when enabled)
//		if(iter >= 1650 && iter < 1660)
//			cpuctrl_mod.cpu_irq <= 4'b1000;
//		else
//			cpuctrl_mod.cpu_irq <= 4'b0000;
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
cpuctrl #(
	.MAIN_CLK(1), .SYS_CLK(1)
)
cpuctrl_mod(
	.clk27(clock)
);
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// debug output
// ---------------------------------------------------------------------------
`ifdef DEBUG
always@(posedge clock) begin
	if(cpuctrl_mod.state == cpuctrl_mod.RUN_CPU) begin
		$display("clk=%b, ", clock, "iter=%4d, ", iter,
			"instr=%h, ", cpuctrl_mod.cpu_instr,
`ifdef USE_INTERRUPTS
			"irq=%h, ", cpuctrl_mod.cpu_irq, "irq_end=%h, ", cpuctrl_mod.cpu_irq_ended,
`endif
			"addr=%h, ", cpuctrl_mod.addr_1, /*"fulladdr=%h, ", cpuctrl_mod.cpu_addr,*/
			"mem->cpu=%h, ", cpuctrl_mod.out_data_1, "cpu->mem=%h, ", cpuctrl_mod.in_data_1,
			"valid=%b", cpuctrl_mod.cpu_mem_valid
`ifndef RAM_DISABLE_PORT2
			, ", mem[%h]=%h.", cpuctrl_mod.addr_2, cpuctrl_mod.out_data_2
`endif
		);
	end
end
`endif
// ---------------------------------------------------------------------------


endmodule
