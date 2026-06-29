module input_registers(

    input clk,
    input rst,

    input load_A,
    input load_B,

    input [31:0] A_in,
    input [31:0] B_in,

    output [31:0] regA,
    output [31:0] regB

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

endmodule

module result_reg(

    input clk,
    input rst,
    input load_en,

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

    input clk,
    input rst,
    input load_en,

    input C,
    input N,
    input V,
    input Z,

    output reg C_out,
    output reg N_out,
    output reg V_out,
    output reg Z_out

);

always @(posedge clk or posedge rst)
begin

    if(rst)
    begin
        C_out <= 0;
        N_out <= 0;
        V_out <= 0;
        Z_out <= 0;
    end

    else if(load_en)
    begin
        C_out <= C;
        N_out <= N;
        V_out <= V;
        Z_out <= Z;
    end

end

endmodule