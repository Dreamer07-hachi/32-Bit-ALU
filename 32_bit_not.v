module notgate (
	input [31:0] A,
	output [31:0] Y
);
genvar i;
generate
	for(i=0;i<32;i = i + 1) begin : notimp
		not (Y[i],A[i]);
	end 
endgenerate
endmodule