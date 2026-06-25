module Register(
	input [31:0] load,
	input clk,
	input rst,
	output reg [31:0] op
);

always @(posedge clk or posedge rst ) begin
	if(rst)
		op = 32'h0000000;
	else
		op = load;
end
endmodule