// -----------------------------------------------------------------------
// uart_rx.v
// Simple 8-N-1 UART receiver.
// Samples the serial line at the middle of each bit period for noise
// immunity, and uses a 2-FF synchronizer on the async `rx` input.
// -----------------------------------------------------------------------
module uart_rx #(
    parameter CLK_FREQ  = 50_000_000, // system clock frequency in Hz
    parameter BAUD_RATE = 9600        // desired UART baud rate
)(
    input  wire       clk,
    input  wire       rst_n,      // active-low synchronous reset
    input  wire       rx,         // serial line in (from PC)
    output reg  [7:0] rx_data,    // received byte, valid when rx_valid pulses
    output reg        rx_valid    // 1-clk pulse: rx_data is valid this cycle
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam S_IDLE  = 3'd0,
               S_START = 3'd1,
               S_DATA  = 3'd2,
               S_STOP  = 3'd3,
               S_CLEAN = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_shift;

    // Double-flop synchronizer for the asynchronous rx input
    reg rx_ff1, rx_ff2;
    always @(posedge clk) begin
        rx_ff1 <= rx;
        rx_ff2 <= rx_ff1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            data_shift <= 8'd0;
            rx_data    <= 8'd0;
            rx_valid   <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // default: only pulses for exactly 1 cycle

            case (state)
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_ff2 == 1'b0)          // falling edge = start bit
                        state <= S_START;
                end

                S_START: begin
                    // Sample at the middle of the start bit to confirm
                    // it's real and not a glitch.
                    if (clk_cnt == (CLKS_PER_BIT-1)/2) begin
                        if (rx_ff2 == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE;     // false start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        data_shift[bit_idx] <= rx_ff2;  // LSB first
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end
                    end
                end

                S_STOP: begin
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        rx_data  <= data_shift;
                        rx_valid <= 1'b1;
                        clk_cnt  <= 16'd0;
                        state    <= S_CLEAN;
                    end
                end

                S_CLEAN: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
