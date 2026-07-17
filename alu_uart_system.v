// -----------------------------------------------------------------------
// alu_uart_system.v
// Top-level wrapper: PC (UART) <-> ALU top_module.
//
// RX packet (PC -> FPGA), 9 bytes, MSB-first per field:
//   byte0..3 = A_in[31:24], A_in[23:16], A_in[15:8], A_in[7:0]
//   byte4..7 = B_in[31:24], B_in[23:16], B_in[15:8], B_in[7:0]
//   byte8    = { opcode[3:0], cin, 3'b000 }
//
// TX packet (FPGA -> PC), 5 bytes:
//   byte0..3 = result[31:24], result[23:16], result[15:8], result[7:0]
//   byte4    = { 4'b0000, C, N, V, Z }
//
// NOTE: this wrapper only sequences bytes and drives start/waits for
// done. None of the existing ALU / control_unit / register logic is
// modified -- top_module is instantiated as-is.
// -----------------------------------------------------------------------
module alu_uart_system #(
    parameter CLK_FREQ  = 50_000_000, // adjust to your board's system clock
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx,     // serial in, from PC
    output wire tx       // serial out, to PC
);

    // ---------------------------------------------------------------
    // UART instances
    // ---------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (rx),
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

    uart_tx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx      (tx),
        .tx_busy (tx_busy),
        .tx_done (tx_done)
    );

    // ---------------------------------------------------------------
    // Existing ALU system -- instantiated unmodified
    // ---------------------------------------------------------------
    reg  [31:0] A_in, B_in;
    reg  [3:0]  opcode;
    reg         cin;
    reg         start;

    wire [31:0] result;
    wire        C_flag, N_flag, V_flag, Z_flag;
    wire        done;

    top_module u_alu (
        .start  (start),
        .A_in   (A_in),
        .B_in   (B_in),
        .opcode (opcode),
        .cin    (cin),
        .result (result),
        .C      (C_flag),
        .N      (N_flag),
        .V      (V_flag),
        .Z      (Z_flag),
        .done   (done)
    );

    // ---------------------------------------------------------------
    // Byte staging buffers
    // ---------------------------------------------------------------
    reg [7:0] rx_buf [0:8]; // 9 bytes in: A(4), B(4), {opcode,cin}(1)
    reg [7:0] tx_buf [0:4]; // 5 bytes out: result(4), flags(1)

    reg [3:0] rx_cnt; // 0..8
    reg [2:0] tx_cnt; // 0..4

    // ---------------------------------------------------------------
    // Main sequencing FSM
    // ---------------------------------------------------------------
    localparam S_RX_WAIT   = 3'd0, // Phase 1: collecting 9 input bytes
               S_LOAD      = 3'd1, // present A/B/opcode/cin, pulse start
               S_EXEC_WAIT = 3'd2, // Phase 2: wait for ALU done
               S_TX_LOAD   = 3'd3, // Phase 3: latch result/flags
               S_TX_SEND   = 3'd4, // kick off uart_tx for current byte
               S_TX_WAIT   = 3'd5; // wait for byte to finish shifting out

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_RX_WAIT;
            rx_cnt   <= 4'd0;
            tx_cnt   <= 3'd0;
            start    <= 1'b0;
            tx_start <= 1'b0;
            A_in     <= 32'd0;
            B_in     <= 32'd0;
            opcode   <= 4'd0;
            cin      <= 1'b0;
        end else begin
            // defaults every cycle; explicitly overridden where needed
            start    <= 1'b0;
            tx_start <= 1'b0;

            case (state)
                // ---------------- Phase 1: RX ----------------
                S_RX_WAIT: begin
                    if (rx_valid) begin
                        rx_buf[rx_cnt] <= rx_data;
                        if (rx_cnt == 4'd8) begin
                            rx_cnt <= 4'd0;
                            state  <= S_LOAD;
                        end else begin
                            rx_cnt <= rx_cnt + 4'd1;
                        end
                    end
                end

                S_LOAD: begin
                    A_in   <= {rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3]};
                    B_in   <= {rx_buf[4], rx_buf[5], rx_buf[6], rx_buf[7]};
                    opcode <= rx_buf[8][7:4];
                    cin    <= rx_buf[8][3];
                    start  <= 1'b1;            // 1-clk pulse into top_module
                    state  <= S_EXEC_WAIT;
                end

                // ---------------- Phase 2: execution ----------------
                // (handled entirely by top_module / control_unit)
                S_EXEC_WAIT: begin
                    if (done)
                        state <= S_TX_LOAD;
                end

                // ---------------- Phase 3: TX ----------------
                S_TX_LOAD: begin
                    tx_buf[0] <= result[31:24];
                    tx_buf[1] <= result[23:16];
                    tx_buf[2] <= result[15:8];
                    tx_buf[3] <= result[7:0];
                    tx_buf[4] <= {4'b0000, C_flag, N_flag, V_flag, Z_flag};
                    tx_cnt    <= 3'd0;
                    state     <= S_TX_SEND;
                end

                S_TX_SEND: begin
                    if (!tx_busy) begin
                        tx_data  <= tx_buf[tx_cnt];
                        tx_start <= 1'b1;
                        state    <= S_TX_WAIT;
                    end
                end

                S_TX_WAIT: begin
                    if (tx_done) begin
                        if (tx_cnt == 3'd4) begin
                            tx_cnt <= 3'd0;
                            state  <= S_RX_WAIT; // ready for next transaction
                        end else begin
                            tx_cnt <= tx_cnt + 3'd1;
                            state  <= S_TX_SEND;
                        end
                    end
                end

                default: state <= S_RX_WAIT;
            endcase
        end
    end

endmodule
