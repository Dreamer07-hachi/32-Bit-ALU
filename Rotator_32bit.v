module mux2to1 (
    input i0, i1,
    input sel,
    output wire y
);
    assign y = sel ? i1 : i0;
endmodule

module bidirectional_rotator_32bit_structural (
    input  wire [31:0] A,
    input  wire [4:0]  B,
    input  wire        opcode,
    output wire [31:0] otp
);

    wire [4:0] wire_boss;

    assign wire_boss = opcode ? (~B + 1'b1) : B;
    wire [31:0] stage [0:5];
    
    assign stage[0] = A;

    genvar i, j;

    generate
        for (i = 0; i < 5; i = i + 1) begin : stage_builder
            
            for (j = 0; j < 32; j = j + 1) begin : bit_mux
                
                mux2to1 physical_mux (
                    .i0(stage[i][j]),
                    .i1(stage[i][(j + (1 << i)) % 32]),
                    .sel(wire_boss[i]), 
                    .y(stage[i+1][j])   
                );
                
            end
        end
    endgenerate

    assign otp = stage[5];

endmodule