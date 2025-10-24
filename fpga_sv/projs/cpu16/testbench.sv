/**
 * cpu testbench
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date August/Sepember-2025
 * @license see 'LICENSE' file
 */


`timescale 1ns / 1ps
`default_nettype /*wire*/ none

//`define WRITE_DUMP
//`define SIM_INTERRUPT


module cpu_tb();

// ---------------------------------------------------------------------------
// create clock
// ---------------------------------------------------------------------------
logic clock = 1'b0;
integer iter, maxiter;

initial begin
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
		clock <= ~clock;
		#1;

`ifdef SIM_INTERRUPT
		// generate a test interrupt
		if(iter >= 1000 && iter < 1010)
			cpuctrl_mod.cpu_irq <= 1'b1;
		else
			cpuctrl_mod.cpu_irq <= 1'b0;
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
			"pc=%h, ", cpuctrl_mod.cpu_pc,
			"instr=%h, ", cpuctrl_mod.cpu_instr,
`ifdef SIM_INTERRUPT
			"irq=%h, ", cpuctrl_mod.cpu_irq,
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
