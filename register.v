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

//module register_7bit(
//	input [6:0] load,
//	input clk,
//	input load_flag,
//	input rst,
//	output reg [7:0] op
//);

//always @(posedge clk or posedge rst ) begin
//	if(rst)
//		op = 7'b0000000;
//	else if(load_flag)
//		op = load;
//end
//endmodule

module register_4bit(
	input [3:0] load,
	input clk,
	input load_opcode,
	input rst,
	output reg [3:0] op
);

always @(posedge clk or posedge rst ) begin
	if(rst)
		op = 4'b0000;
	else if(load_opcode)
		op = load;
end
endmodule

module register_1bit(
	input load,clk,
	input load_cin,
	input rst,
	output reg op
);

always @(posedge clk or posedge rst ) begin
	if(rst)
		op = 1'b0;
	else if(load_cin)
		op = load;
end
endmodule