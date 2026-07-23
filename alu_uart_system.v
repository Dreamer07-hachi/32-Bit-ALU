module alu_uart_system(

    input wire clk,
    input wire rst,

    input wire uart_rx,
    output wire uart_tx

);

//==========================================================
// UART Receiver Signals
//==========================================================

wire [7:0] rx_data;
wire rx_valid;

//==========================================================
// UART Transmitter Signals
//==========================================================

reg [7:0] tx_data;
reg tx_start;

wire tx_busy;
wire tx_done;

//==========================================================
// ALU Interface
//==========================================================

reg start;

reg [31:0] A_in;
reg [31:0] B_in;
reg [15:0] timeout_counter;

reg [3:0] opcode;
reg cin;

wire [31:0] result;

wire C_flag;
wire N_flag;
wire V_flag;
wire Z_flag;

wire done;

//==========================================================
// Buffers
//==========================================================

reg [7:0] rx_buffer [0:8];     // 9 received bytes
reg [7:0] tx_buffer [0:4];     // 5 transmit bytes

reg [3:0] rx_count;
reg [2:0] tx_count;

//==========================================================
// FSM States
//==========================================================

localparam S_WAIT_RX    = 4'd0;
localparam S_LOAD_DATA  = 4'd1;
localparam S_START_ALU  = 4'd2;
localparam S_WAIT_DONE  = 4'd3;
localparam S_PREP_TX    = 4'd4;
localparam S_SEND_BYTE  = 4'd5;
localparam S_WAIT_TX    = 4'd6;

reg [3:0] state;

//==========================================================
// UART Receiver
//==========================================================

uart_rx RX(

    .clk(clk),
    .rst_n(rst),

    .rx(uart_rx),

    .rx_data(rx_data),
    .rx_valid(rx_valid)

);

//==========================================================
// UART Transmitter
//==========================================================

uart_tx TX(

    .clk(clk),
    .rst_n(rst),

    .tx_start(tx_start),
    .tx_data(tx_data),

    .tx(uart_tx),

    .tx_busy(tx_busy),
    .tx_done(tx_done)

);

//==========================================================
// ALU
//==========================================================

top_module u_alu(

    .clk(clk),
    .rst(rst),

    .start(start),

    .A_in(A_in),
    .B_in(B_in),

    .opcode(opcode),
    .cin(cin),

    .result(result),

    .C(C_flag),
    .N(N_flag),
    .V(V_flag),
    .Z(Z_flag),

    .done(done)

);
//==========================================================
// Main FSM
//==========================================================

always @(posedge clk) begin

    if (rst) begin

        state <= S_WAIT_RX;

        rx_count <= 4'd0;
        tx_count <= 3'd0;

        start <= 1'b0;
        tx_start <= 1'b0;

        tx_data <= 8'd0;
        timeout_counter <= 16'd0;

        A_in <= 32'd0;
        B_in <= 32'd0;

        opcode <= 4'd0;
        cin <= 1'b0;

        tx_buffer[0] <= 8'd0;
        tx_buffer[1] <= 8'd0;
        tx_buffer[2] <= 8'd0;
        tx_buffer[3] <= 8'd0;
        tx_buffer[4] <= 8'd0;

        rx_buffer[0] <= 8'd0;
        rx_buffer[1] <= 8'd0;
        rx_buffer[2] <= 8'd0;
        rx_buffer[3] <= 8'd0;
        rx_buffer[4] <= 8'd0;
        rx_buffer[5] <= 8'd0;
        rx_buffer[6] <= 8'd0;
        rx_buffer[7] <= 8'd0;
        rx_buffer[8] <= 8'd0;

    end

    else begin

        //--------------------------------------------------
        // Default Outputs
        //--------------------------------------------------

        start <= 1'b0;
        tx_start <= 1'b0;

        case(state)

        //--------------------------------------------------
        // WAIT FOR 9 UART BYTES
        //--------------------------------------------------

        S_WAIT_RX:
        begin

            if(rx_valid) begin

                rx_buffer[rx_count] <= rx_data;

                if(rx_count == 8) begin

                    rx_count <= 0;
                    state <= S_LOAD_DATA;

                end

                else begin

                    rx_count <= rx_count + 1;
                end

            end

        end

        //--------------------------------------------------
        // LOAD ALU INPUTS
        //--------------------------------------------------

        S_LOAD_DATA:
        begin

            A_in <= {

                rx_buffer[0],
                rx_buffer[1],
                rx_buffer[2],
                rx_buffer[3]

            };

            B_in <= {

                rx_buffer[4],
                rx_buffer[5],
                rx_buffer[6],
                rx_buffer[7]

            };

            opcode <= rx_buffer[8][7:4];
            cin    <= rx_buffer[8][3];

            state <= S_START_ALU;

        end

        //--------------------------------------------------
        // ONE CLOCK START PULSE
        //--------------------------------------------------

        S_START_ALU:
        begin

            start <= 1'b1;
            timeout_counter <= 16'd0;

            state <= S_WAIT_DONE;

        end

        //--------------------------------------------------
        // WAIT UNTIL ALU FINISHES
        //--------------------------------------------------

S_WAIT_DONE:
begin

    if(done) begin

        timeout_counter <= 16'd0;
        state <= S_PREP_TX;

    end

    else if(timeout_counter == 16'd50000) begin

        timeout_counter <= 16'd0;

        tx_buffer[0] <= 8'hEE;
        tx_buffer[1] <= 8'hEE;
        tx_buffer[2] <= 8'hEE;
        tx_buffer[3] <= 8'hEE;
        tx_buffer[4] <= 8'h0F;

        tx_count <= 0;

        state <= S_SEND_BYTE;

    end

    else begin

        timeout_counter <= timeout_counter + 1'b1;

    end

end

        //--------------------------------------------------
        // PREPARE TRANSMIT BUFFER
        //--------------------------------------------------

        S_PREP_TX:
        begin

            tx_buffer[0] <= result[31:24];
            tx_buffer[1] <= result[23:16];
            tx_buffer[2] <= result[15:8];
            tx_buffer[3] <= result[7:0];

            tx_buffer[4] <= {

                4'b0000,

                C_flag,
                N_flag,
                V_flag,
                Z_flag

            };

            tx_count <= 0;

            state <= S_SEND_BYTE;

        end

        //--------------------------------------------------
        // START UART TRANSMISSION
        //--------------------------------------------------

        S_SEND_BYTE:
        begin

            if(!tx_busy) begin

                tx_data <= tx_buffer[tx_count];
                tx_start <= 1'b1;

                state <= S_WAIT_TX;

            end

        end

        //--------------------------------------------------
        // WAIT FOR UART TO FINISH
        //--------------------------------------------------

        //--------------------------------------------------
// WAIT FOR UART TO FINISH
//--------------------------------------------------

S_WAIT_TX:
begin

    if(tx_done) begin

        if(tx_count == 3'd4) begin

            state <= S_WAIT_RX;

        end

        else begin

            tx_count <= tx_count + 1'b1;
            state <= S_SEND_BYTE;

        end

    end

end

        //--------------------------------------------------
        // DEFAULT
        //--------------------------------------------------

        default:
        begin

            state <= S_WAIT_RX;

        end

        endcase

    end

end
endmodule