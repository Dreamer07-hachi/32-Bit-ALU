module register(
	input [31:0] load,
	input clk,
	input load_en,
	input rst,
	output reg [31:0] op
);

always @(posedge clk or posedge rst ) begin
	if(rst)
		op = 32'h0000000;
	else if(load_en)
		op = load;
end
endmodule