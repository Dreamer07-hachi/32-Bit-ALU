
module comp(
    input wire c,z,n,v,
    input wire [3:0]opcode,
    output wire equalto, Agreater,Alesser
    );
    
    wire t1, t2, t3, t4, cbar;
    
    xor (t1,n,v);
    not (cbar, c);
    and (t2,opcode[3],opcode[2],opcode[0]) ;
    
    assign equalto = t2 & z; 
    
    
mux2isto1 #(
  .width(1)
)abc(
  .i0(cbar),
  .i1(t1),
  .sel(opcode[1]),
  .y(t3)
);
    
    assign Agreater=t3&t2;
    nand (t4,z,t3);
    assign Alesser=t4&t2; 
    
    
endmodule
