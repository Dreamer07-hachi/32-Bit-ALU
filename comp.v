
module comp(
    input wire c,z,n,v,
    input wire [3:0]opcode,
    output wire equalto, Agreater,Alesser
    );
    
    wire t1, t2, t3, t4, cbar,opmatch;
    
    xor (t1,n,v);   //n^v
    not (cbar, c);   //~c
    and (t2,opcode[3],opcode[2]) ;
    and (opmatch, t2, opcode[0]);
    
    assign equalto = opmatch & z; 
    
    
mux2isto1 #(
  .width(1)
)abc(
  .i0(cbar),
  .i1(t1),
  .sel(opcode[1]),
  .y(t3)
);
    
    assign Alesser=t3&opmatch;
    nor (t4,z,t3);
    assign Agreater=t4&opmatch; 
    
    
endmodule
