module top_module(
    input clk,rst,
    input [31:0] A_in,B_in,
    input [3:0] opcode,
    input cin,
    output [31:0] result,
    output [6:0]flags
);

//enable signals 
wire load_A;
wire load_B, load_cin;
wire load_opcode; 
wire load_result;
wire load_flags;

//output wires from the registers A and B
wire [31:0] regA;
wire [31:0] regB;
wire [3:0] rego; 
wire regCin; 
// o/p regs 
wire [31:0] alu_result;
wire [6:0] alu_flags; 

ALU alu1(
    .A(regA),.B(regB),.Opcode(reg0),.Cin(regCin),.Y(alu_result),.Carry(alu_flags[0]),.Overflow(alu_flags[2]),.Negative(alu_flags[1]),
    .Zero(alu_flags[3]),.AgreaterB(alu_flags[5]),.AequalB(alu_flags[6]),.AlesserB(alu_flags[4])
);

 control_unit ctrlpath(
    .clk(clk),.rst(rst),
    .load_A(load_A),.load_B(load_B),.load_opcode(load_opcode),.result_load(load_result),.flag_load(load_flags),.load_cin(load_cin)
);

input_registers inputstage(

    .clk(clk),.rst(rst),.load_A(load_A),.load_B(load_B),.load_opcode(load_opcode),.load_cin(load_cin),.cin(cin),
    .A_in(A_in),.B_in(B_in),.Opcode_in(opcode),.regcin(regCin),
    .regA(regA),.regB(regB), .regOpcode(rego)
);


result_reg outputstage1(

   .clk(clk),.rst(rst), .load_en(load_result),
   .res_in(alu_result),
  .result_out(result)
);

flag_register outputstage2(
    .clk(clk), .rst(rst),.load_en(load_flags),.C(alu_flags[0]),.N(alu_flags[1]),.V(alu_flags[2]),.Z(alu_flags[3]),.less(alu_flags[4]),.great(alu_flags[5]),.equal(alu_flags[6]),
 .flags(flags)
);


endmodule