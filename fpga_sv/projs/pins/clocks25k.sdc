# period (ns): 1/50MHz * 1e9
create_clock -name {clk50} -period 20 [ get_ports{clk50} ]
