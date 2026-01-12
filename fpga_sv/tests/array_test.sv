/**
 * array test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 11-jan-2026
 * @license see 'LICENSE' file
 */

// iverilog -g2012 -o array_test array_test.sv

module array_test();

localparam NUM = 4;
localparam BITS = 8;

logic [0 : NUM - 1][BITS - 1 : 0] arr;
assign arr = { 8'h1, 8'h2, 8'h3, 8'h4 };

// wrong index order
logic [BITS - 1 : 0][0 : NUM - 1] arr2;
assign arr2 = { 8'h1, 8'h2, 8'h3, 8'h4 };

// wrong element size
logic [0 : NUM - 1][BITS - 1 : 0] arr3;
assign arr3 = { 4'h1, 4'h2, 4'h3, 4'h4 };

// casted element size
logic [0 : NUM - 1][BITS - 1 : 0] arr4;
assign arr4 = { BITS'(4'h1), BITS'(6'h2), BITS'(8'h3), BITS'(10'h4) };

initial begin
 for(int i = 0; i < NUM; ++i)
  $display("arr[%1d] = %d", i, arr[i],
   ", arr2[%1d] = %d", i, arr2[i],
   ", arr3[%1d] = %d", i, arr3[i],
   ", arr4[%1d] = %d", i, arr4[i]);
end


endmodule
