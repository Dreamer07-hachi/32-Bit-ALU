module control_unit(

    input clk,
    input rst,
    input start,

    output reg load_A,
    output reg load_B,

    output reg result_load,
    output reg flag_load,

    output reg done

);

localparam IDLE  = 2'b00;
localparam READ  = 2'b01;
localparam WRITE = 2'b10;
localparam DONE  = 2'b11;

reg [1:0] state;
reg [1:0] next_state;

always @(posedge clk or posedge rst)
begin
    if(rst)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*)
begin

    case(state)

        IDLE:
        begin
            if(start)
                next_state = READ;
            else
                next_state = IDLE;
        end

        READ:
            next_state = WRITE;

        WRITE:
            next_state = DONE;

        DONE:
            next_state = IDLE;

        default:
            next_state = IDLE;

    endcase

end

always @(*)
begin

    load_A      = 0;
    load_B      = 0;
    result_load = 0;
    flag_load   = 0;
    done        = 0;

    case(state)

        IDLE:
        begin
            load_A      = 0;
            load_B      = 0;
            result_load = 0;
            flag_load   = 0;
            done        = 0;
        end

        READ:
        begin
            load_A = 1;
            load_B = 1;
        end

        WRITE:
        begin
            result_load = 1;
            flag_load   = 1;
        end

        DONE:
        begin
            done = 1;
        end

    endcase

end

endmodule