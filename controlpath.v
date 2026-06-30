module control_unit(
    input clk,rst,
    output reg load_A,load_B,load_opcode,result_load,flag_load,load_cin
);

localparam S0= 2'b00;
localparam S1= 2'b01;
localparam S2= 2'b10;
localparam S3= 2'b11;

reg [1:0] state;
reg [1:0] next_state;

//state memory logic
always @(posedge clk or posedge rst)
begin
    if(rst)
        state <= S3;
    else
        state <= next_state;
end

//next state logic
always @(*)
begin
    case(state)
        S0:next_state=S1; 
        S1:next_state = S2;
        S2:next_state = S3;
        S3:next_state = S0;
        default:next_state = S0;
    endcase
end

//output logic
always @(*)
begin
    load_A      = 0;
    load_B      = 0;
    load_cin =0; 
    result_load = 0;
    flag_load   = 0;
    
    
    case(state)

        S0:
        begin
            load_A      = 1;
            load_B      = 1;
            load_cin    =1; 
            result_load = 0;
            flag_load   = 0;
            load_opcode = 1; 
        end

        S1:
        begin
            load_A = 0;
            load_B = 0;
            load_cin = 0; 
            load_opcode = 0; 
        end

        S2:
        begin
            result_load = 1;
            flag_load   = 1;
        end

        S3:
        begin
            result_load= 0;
            flag_load= 0; 
        end

    endcase

end

endmodule