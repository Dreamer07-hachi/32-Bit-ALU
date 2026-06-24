module brentkungadder(
input wire[31:0] A,B, 
output wire[31:0] S, 
input Cin, 
output Cout,
output Overflow,
output wire [31:0] P,G
);
wire [31:0]C;


preprocessing p(
.A(A), .B(B), .G(G), .P(P)
);


wire [15:0] G1; 
wire [15:0] P1; 

dot d3(
    .G_lower(Cin),
    .G_upper(G[0]),
    .G_output(C[0]),
    .P_lower(1'b0),
    .P_upper(P[0]),
    .P_output()
);

dot d2(
    .G_lower(G[0]),
    .G_upper(G[1]),
    .G_output(G1[0]),
    .P_lower(P[0]),
    .P_upper(P[1]),
    .P_output(P1[0])
);

assign C[1] = G1[0] | (P1[0] & Cin);

genvar i; 

generate 
    for(i=2;i<32;i=i+2)begin : level1
    dot d1(
    .G_lower(G[i]),
    .G_upper(G[i+1]),
    .G_output(G1[i/2]),
    .P_lower(P[i]),
    .P_upper(P[i+1]),
    .P_output(P1[i/2])
);
    end
endgenerate

wire [7:0] G2; 
wire [7:0] P2; 

dot d(
    .G_lower(G1[0]),
    .G_upper(G1[1]),
    .G_output(G2[0]),
    .P_lower(P1[0]),
    .P_upper(P1[1]),
    .P_output(P2[0])
);

assign C[3]= G2[0] | (P2[0] & Cin); 

genvar j; 
generate
    for(j=2; j<16;j=j+2)begin : level2
    dot d6(
    .G_lower(G1[j]),
    .G_upper(G1[j+1]),
    .G_output(G2[j/2]),
    .P_lower(P1[j]),
    .P_upper(P1[j+1]),
    .P_output(P2[j/2])
);
    end
endgenerate

wire [3:0] G3; 
wire [3:0] P3;

dot d7(
    .G_lower(G2[0]),
    .G_upper(G2[1]),
    .G_output(G3[0]),
    .P_lower(P2[0]),
    .P_upper(P2[1]),
    .P_output(P3[0])
);

assign C[7]=G3[0] | (P3[0] & Cin); 

genvar k; 
generate
    for(k=2; k<8;k=k+2)begin : level3
    dot d6765(
    .G_lower(G2[k]),
    .G_upper(G2[k+1]),
    .G_output(G3[k/2]),
    .P_lower(P2[k]),
    .P_upper(P2[k+1]),
    .P_output(P3[k/2])
);
    end
endgenerate

wire [1:0] G4; 
wire [1:0] P4;

dot d17(
    .G_lower(G3[0]),
    .G_upper(G3[1]),
    .G_output(G4[0]),
    .P_lower(P3[0]),
    .P_upper(P3[1]),
    .P_output(P4[0])
);

assign C[15]=G4[0] | (P4[0] & Cin); 

dot d127(
    .G_lower(G3[2]),
    .G_upper(G3[3]),
    .G_output(G4[1]),
    .P_lower(P3[2]),
    .P_upper(P3[3]),
    .P_output(P4[1])
);

wire G5; 
wire P5;

dot t127(
    .G_lower(G4[0]),
    .G_upper(G4[1]),
    .G_output(G5),
    .P_lower(P4[0]),
    .P_upper(P4[1]),
    .P_output(P5)
);

assign C[31] = G5 | (P5 & Cin);

dot bk_l4 (
    .G_lower(C[15]),   .G_upper(G3[2]), 
    .P_lower(1'b0),    .P_upper(P3[2]), 
    .G_output(C[23]),  .P_output()
);

genvar il;
generate
    for (il = 1; il <= 3; il = il + 1) begin : level3_back
        wire c_in_lookahead;
        assign c_in_lookahead = (il == 1) ? C[7] : 
                                 (il == 2) ? C[15] : C[23];
        dot bkl3 (
            .G_lower(c_in_lookahead), .G_upper(G2[2*il]), 
            .P_lower(1'b0),            .P_upper(P2[2*il]), 
            .G_output(C[8*il + 3]),    .P_output()
        );
    end
endgenerate

genvar im;
generate
    for (im = 1; im <= 7; im = im + 1) begin : level2_back
        wire c_in_lookahead;
        assign c_in_lookahead = (im == 1) ? C[3]  : (im == 2) ? C[7]  :
                                 (im == 3) ? C[11] : (im == 4) ? C[15] :
                                 (im == 5) ? C[19] : (im == 6) ? C[23] : C[27];
        dot bkl2 (
            .G_lower(c_in_lookahead), .G_upper(G1[2*im]), 
            .P_lower(1'b0),            .P_upper(P1[2*im]), 
            .G_output(C[4*im + 1]),    .P_output()
        );
    end
endgenerate

genvar ifn;
generate
    for (ifn = 1; ifn <= 15; ifn = ifn + 1) begin : level1_back
        dot bkl1 (
            .G_lower(C[2*ifn - 1]), .G_upper(G[2*ifn]), 
            .P_lower(1'b0),        .P_upper(P[2*ifn]), 
            .G_output(C[2*ifn]),    .P_output()
        );
    end
endgenerate

assign S[0] = P[0] ^ Cin;
genvar s;
generate
    for(s=1; s<32; s=s+1) begin : sumgen
        assign S[s] = P[s] ^ C[s-1];
    end
endgenerate

assign Cout = C[31];
assign Overflow = C[31]^C[30]; 

endmodule


module topmodule(input wire[31:0] A,B, 
output wire[31:0] S,  P,G,
input Cin, 
output Overflow, 
input Mode, 
input Mode_1, 


output Carry

);

wire Cout; 
wire Cin_eff; 
wire [31:0 ]B_eff; 
assign Cin_eff = Mode | (Cin & (~Mode_1));

assign B_eff[0] = (Mode_1|B[0]) ^Mode; 
genvar i; 

generate 

    for(i=1;i<32;i=i+1)begin 
    assign B_eff[i]=(~Mode_1 & B[i]) ^ Mode;
    end

endgenerate 

brentkungadder bre(
.A(A),
.B(B_eff), 
.S(S),  
.Cin(Cin_eff), 
.Cout(Cout),
.Overflow(Overflow),
.P(P),.G(G)
);




assign Carry = Cout; 


endmodule