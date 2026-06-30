module input_registers(

    input clk,rst,load_A,load_B,load_opcode,load_cin,cin,
    input [31:0] A_in,B_in,
    input [3:0]Opcode_in, 
    output regcin,
    output [31:0] regA,regB,
    output [3:0] regOpcode
);
register registerA(
    .load(A_in),
    .clk(clk),
    .rst(rst),
    .load_en(load_A),
    .op(regA)
);

register registerB(
    .load(B_in),
    .clk(clk),
    .rst(rst),
    .load_en(load_B),
    .op(regB)
);

register_4bit reg_opcode(
	.load(Opcode_in),
	.clk(clk),
	.load_opcode(load_opcode),
	.rst(rst),
	.op(regOpcode)
);

register_1bit reg_cin(
.load(cin),.clk(clk),
.load_cin(load_cin),
.rst(rst),
.op(regcin)
);
endmodule

module result_reg(

    input clk,rst, load_en,
    input [31:0] res_in,
    output [31:0] result_out
);

register result(
    .load(res_in),
    .clk(clk),
    .rst(rst),
    .load_en(load_en),
    .op(result_out)
);
endmodule

module flag_register(
    input clk, rst,load_en,C,N,V,Z,less,great,equal,
    output reg [6:0]flags
);

always @(posedge clk or posedge rst)
begin

    if(rst)
    begin
       flags<=7'b0000000;  
    end

    else if(load_en)
    begin
       flags[0]<= C;
        flags[1] <= N;
        flags[2] <= V;
        flags[3] <= Z;
        flags[4]<=less; 
        flags[5]<=great; 
        flags[6]<=equal; 
    end

end

endmodule