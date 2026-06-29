module top_module(

    input clk,
    input rst,
    input start,

    input [31:0] A_in,
    input [31:0] B_in,

    input [3:0] opcode,
    input cin,

    output [31:0] result,
    output C,
    output N,
    output V,
    output Z,
    output done

);

// FSM Signals
wire load_A;
wire load_B;
wire result_load;
wire flag_load;

// Register Outputs
wire [31:0] regA;
wire [31:0] regB;

// ALU Outputs
wire [31:0] alu_result;
wire carry;
wire negative;
wire overflow;
wire zero;

control_unit CU(

    .clk(clk),
    .rst(rst),
    .start(start),
    .load_A(load_A),
    .load_B(load_B),
    .result_load(result_load),
    .flag_load(flag_load),
    .done(done)

);

input_registers INPUTS(

    .clk(clk),
    .rst(rst),

    .load_A(load_A),
    .load_B(load_B),

    .A_in(A_in),
    .B_in(B_in),

    .regA(regA),
    .regB(regB)

);

ALU alu1(

    .A(regA),
    .B(regB),

    .Opcode(opcode),
    .Cin(cin),

    .Y(alu_result),

    .Carry(carry),
    .Overflow(overflow),
    .Negative(negative),
    .Zero(zero)

);

result_reg RESULT(

    .clk(clk),
    .rst(rst),

    .load_en(result_load),

    .res_in(alu_result),

    .result_out(result)

);

flag_register FLAGS(

    .clk(clk),
    .rst(rst),

    .load_en(flag_load),

    .C(carry),
    .N(negative),
    .V(overflow),
    .Z(zero),

    .C_out(C),
    .N_out(N),
    .V_out(V),
    .Z_out(Z)

);

endmodule