module mux2isto1 #(
    parameter width = 1
)(
    input  [width-1:0] i0,
    input  [width-1:0] i1,
    input  sel,
    output [width-1:0] y
);
assign y = sel ? i1 : i0;
endmodule

module barrel_shifter(
	input[31:0] A,B,
	input wire opcode,
	output [31:0] otp
);

wire [31:0] reverse_in;

genvar i;
generate
	for(i=0; i<32; i = i + 1) begin : input_reverse
		mux2isto1 instance1(
			.i0(A[i]),
			.i1(A[31-i]),
			.sel(opcode),
			.y(reverse_in[i])
		);
	end 
endgenerate

wire [31:0] stage[0:5];

assign stage[0] = reverse_in;

genvar j,k;
generate
	for(j=0;j<5;j = j + 1) begin : stage_gen
		for(k=0;k<32;k = k + 1) begin : bit_gen
			if(k + (1 << j) <32) begin : valid_shift
				mux2isto1 M(
					.i0(stage[j][k]),
					.i1(stage[j][k+(1<<j)]),
					.sel(B[j]),
					.y(stage[j+1][k])
				);
			end
			else begin : zero_fill
				mux2isto1 M(
					.i0(stage[j][k]),
					.i1(1'b0),
					.sel(B[j]),
					.y(stage[j+1][k])
				);
			end
		end
	end
endgenerate

wire [31:0] reverse_out;

genvar m;
generate
	for(m=0; m<32; m = m + 1) begin : output_reverse
		mux2isto1 instance2(
			.i0(stage[5][m]),
			.i1(stage[5][31-m]),
			.sel(opcode),
			.y(reverse_out[m])
		);
	end 
endgenerate

assign otp = reverse_out; 
endmodule
		
		



