module orgate (
	input [31:0] A,B,
	output [31:0] Y
);
genvar i;
generate
	for(i=0;i<32;i = i + 1) begin : orimp
		or (Y[i],A[i],B[i]);
	end 
endgenerate
endmodule