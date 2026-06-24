

module preprocessing(
input wire[31:0] A, 
input wire[31:0] B,
output wire[31:0] G,
output wire[31:0] P
    );
    
genvar i; 

generate 
    for(i=0; i<32;i=i+1)begin
    
    assign G[i]=A[i]&B[i];
    assign P[i]=A[i]^B[i];
    end    
endgenerate 
endmodule
