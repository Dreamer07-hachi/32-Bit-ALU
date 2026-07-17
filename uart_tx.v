// -----------------------------------------------------------------------
// uart_tx.v
// Simple 8-N-1 UART transmitter.
// Assert tx_start for 1 clock with tx_data held stable; tx_busy stays
// high until the byte (start+8data+stop) has fully shifted out, and
// tx_done pulses for 1 clock at the end.
// -----------------------------------------------------------------------
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,   // 1-clk pulse to begin sending tx_data
    output reg        tx,         // serial line out (to PC)
    output reg        tx_busy,    // high while a byte is being shifted out
    output reg        tx_done     // 1-clk pulse when the byte finishes
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam S_IDLE  = 2'd0,
               S_START = 2'd1,
               S_DATA  = 2'd2,
               S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
            tx       <= 1'b1;   // idle line is high
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
        end else begin
            tx_done <= 1'b0; // default

            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        tx_busy  <= 1'b1;
                        clk_cnt  <= 16'd0;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0; // start bit
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        bit_idx <= 3'd0;
                        state   <= S_DATA;
                    end
                end

                S_DATA: begin
                    tx <= data_reg[bit_idx]; // LSB first
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            state <= S_STOP;
                        end
                    end
                end

                S_STOP: begin
                    tx <= 1'b1; // stop bit
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        state   <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
