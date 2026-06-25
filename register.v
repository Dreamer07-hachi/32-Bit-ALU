module Register(
    input wire [31:0] load,
    input wire load_en,
    input wire clk,
    input wire rst,
    output reg [31:0] op
);

    // Triggers instantly on either the clock edge OR the reset edge
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            op <= 32'h00000000;  // Reset happens immediately
        end else if (load_en) begin
            op <= load;          // Capture data only if load_en is high
        end
    end

endmodule
