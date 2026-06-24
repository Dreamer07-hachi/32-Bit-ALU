`timescale 1ns / 1ps

module ALU(
input wire[31:0]  A,B ,
output wire [31:0] Y,
input wire Cin, 
input wire [3:0]Opcode,
output wire Carry, Overflow, Negative, Zero, AgreaterB, AequalB,AlesserB
    );
    

wire [31:0]S; //o/p from brent kung adder

wire [31:0]S_0100; //o/p from AND
wire [31:0]S_0101; //o/p from OR
wire [31:0]S_010; //AND'/ OR
wire [31:0]S_0110; //o/p from XOR
wire [31:0]S_0111; //o/p from NOT
wire [31:0]S_011; //xor'/not
wire [31:0]S_001; //o/p from SLL/SLR
wire [31:0]S_101; //o/p from ROL/ROR

wire overflow,carry; 

topmodule brentkungadder(
.A(A),.B(B), .S(S),.P(S_0110),.G(S_0100),  .Cin(Cin), .Overflow(overflow),
.Mode(Opcode[0]), .Mode_1(Opcode[3]), .Carry(carry)
);
   
 barrel_shifter sllslr(
	.A(A),.B(B),
	.opcode(Opcode[0]),
	.otp(S_001)
);    

 bidirectional_rotator_32bit_structural rorrol(
    .A(A),
    .B(B[4:0]),
    .opcode(Opcode[0]),
    .otp(S_101)
);

 notgate n(
	.A(A),
	.Y(S_0111)
);

 orgate o(
	.A(A),.B(B),
	.Y(S_0101)
);

mux2isto1 #(
    .width(32)
)s010(
	.i0(S_0100),.i1(S_0101),
	.sel(Opcode[0]),
	.y(S_010)
);
   
mux2isto1 #(
    .width(32)
)s011(
	.i0(S_0110),.i1(S_0111),
	.sel(Opcode[0]),
	.y(S_011)
);

mux8isto1_32bit op(
    . i0(S), .i1(S_001),. i2(S_010), .i3(S_011), .i4(S), .i5(S_101), .i6(32'd0), .i7(A),   // 8 discrete 32-bit inputs
    .sel({Opcode[3],Opcode[2],Opcode[1]}),                               // 3-bit select line
    .y(Y)                                // 32-bit output
);
   assign Zero = ~|Y;
   assign Negative = Y[31]; 

    


   wire x = Opcode[1]|Opcode[2]; 
   
   assign Carry = carry& (~x); 
   assign Overflow = overflow& (~x); 
    comp p3(
   .c(carry),.z(Zero),.n(Negative),.v(overflow),
   .opcode(Opcode),
   .equalto(AequalB), .Agreater(AgreaterB),.Alesser(AlesserB)
    ); 
    
endmodule







module mux8isto1_32bit (
    input wire [31:0] i0, i1, i2, i3, i4, i5, i6, i7,   // 8 discrete 32-bit inputs
    input wire [2:0] sel,                               // 3-bit select line
    output wire [31:0] y                                // 32-bit output
);

    wire [31:0] stage1_0, stage1_1, stage1_2, stage1_3;
    wire [31:0] stage2_0, stage2_1;

//8-->4
    mux2isto1 #(.width(32)) m1_0 (.i0(i0), .i1(i1), .sel(sel[0]), .y(stage1_0));
    mux2isto1 #(.width(32)) m1_1 (.i0(i2), .i1(i3), .sel(sel[0]), .y(stage1_1));
    mux2isto1 #(.width(32)) m1_2 (.i0(i4), .i1(i5), .sel(sel[0]), .y(stage1_2));
    mux2isto1 #(.width(32)) m1_3 (.i0(i6), .i1(i7), .sel(sel[0]), .y(stage1_3));

//4-->2

    mux2isto1 #(.width(32)) m2_0 (.i0(stage1_0), .i1(stage1_1), .sel(sel[1]), .y(stage2_0));
    mux2isto1 #(.width(32)) m2_1 (.i0(stage1_2), .i1(stage1_3), .sel(sel[1]), .y(stage2_1));

//2-->1
    mux2isto1 #(.width(32)) m3_0 (.i0(stage2_0), .i1(stage2_1), .sel(sel[2]), .y(y));

endmodule
