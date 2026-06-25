module bus(
	input bus_a_b,
	input[31:0] load,
	input clk,
	input load_en,
	input rst,
	output[31:0] regA,regB
);

wire [31:0] wireA,wireB;

assign wireA = load_en & ~(bus_a_b);
assign wireB = load_en % bus_a_b;

register regA(.load(load),.clk(clk),.rst(rst),.load_en(wireA),.op(regA));
register regB(.load(load),.clk(clk),.rst(rst),.load_en(wireB),.op(regB));

endmodule




 

	