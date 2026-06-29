`timescale 1ns/1ps

module tb_top_module_full;

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg [31:0] A_in;
    reg [31:0] B_in;
    reg [3:0] opcode;
    reg cin;

    // Outputs
    wire [31:0] result;
    wire C;
    wire N;
    wire V;
    wire Z;
    wire done;

    // Instantiate the Top Module (UUT)
    top_module uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .A_in(A_in), 
        .B_in(B_in), 
        .opcode(opcode), 
        .cin(cin), 
        .result(result), 
        .C(C), 
        .N(N), 
        .V(V), 
        .Z(Z), 
        .done(done)
    );

    // Clock Generation (10ns period / 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to automatically feed instructions through the FSM Pipeline
    task execute_instruction;
        input [31:0] test_A;
        input [31:0] test_B;
        input [3:0]  test_opcode;
        input        test_cin;
        input [8*15:1] op_name; // String for printing
        input [31:0] expected_res;
        begin
            // 1. Wait for negative edge to apply inputs safely
            @(negedge clk); 
            A_in   = test_A;
            B_in   = test_B;
            opcode = test_opcode;
            cin    = test_cin;
            
            // 2. Trigger the FSM from IDLE to READ
            start  = 1; 
            
            // 3. Drop start on the next cycle so we don't trigger it twice
            @(negedge clk);
            start  = 0; 
            
            // 4. Wait until the FSM reaches the 'DONE' state
            wait(done);
            
            // 5. Evaluate the results captured in the registers
            if (result === expected_res)
                $display("[PASS] %s | Op: %b | A: %h | B: %h | Res: %h", op_name, test_opcode, test_A, test_B, result);
            else
                $display("[FAIL] %s | Op: %b | A: %h | B: %h | Res: %h (Exp: %h)", op_name, test_opcode, test_A, test_B, result, expected_res);
            
            // 6. Wait for FSM to return to IDLE before next instruction
            @(negedge clk);
        end
    endtask

    // Main Test Sequence
    initial begin
        // Generate waveform file
        $dumpfile("top_fsm_massive_test.vcd");
        $dumpvars(0, tb_top_module_full);

        // Initialize Inputs
        rst = 1;
        start = 0;
        A_in = 0;
        B_in = 0;
        opcode = 0;
        cin = 0;

        // Reset the system
        #20;
        rst = 0;
        #20;
        
        $display("=========================================================================");
        $display(" Starting Massive 50+ Case FSM ALU Test Suite...");
        $display("=========================================================================");

        // ---------------------------------------------------------
        // 1. ARITHMETIC TESTS (ADD: 0000, SUB: 0001)
        // ---------------------------------------------------------
        execute_instruction(32'h0000_0001, 32'h0000_0001, 4'b0000, 1'b0, "ADD", 32'h0000_0002);
        execute_instruction(32'h0000_0010, 32'h0000_0020, 4'b0000, 1'b0, "ADD", 32'h0000_0030);
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0001, 4'b0000, 1'b0, "ADD", 32'h0000_0000); // Overflow test
        execute_instruction(32'h7FFF_FFFF, 32'h0000_0001, 4'b0000, 1'b0, "ADD", 32'h8000_0000);
        execute_instruction(32'h0000_0000, 32'h0000_0000, 4'b0000, 1'b0, "ADD", 32'h0000_0000);

        execute_instruction(32'h0000_0032, 32'h0000_0014, 4'b0001, 1'b1, "SUB", 32'h0000_001E); // 50 - 20 = 30
        execute_instruction(32'h0000_0010, 32'h0000_0010, 4'b0001, 1'b1, "SUB", 32'h0000_0000);
        execute_instruction(32'h0000_0000, 32'h0000_0001, 4'b0001, 1'b1, "SUB", 32'hFFFF_FFFF); // 0 - 1 = -1
        execute_instruction(32'h0000_0064, 32'h0000_00C8, 4'b0001, 1'b1, "SUB", 32'hFFFF_FF9C); // 100 - 200 = -100
        execute_instruction(32'h8000_0000, 32'h0000_0001, 4'b0001, 1'b1, "SUB", 32'h7FFF_FFFF);

        // ---------------------------------------------------------
        // 2. BITWISE TESTS (AND: 0100, OR: 0101, XOR: 0110, NOT: 0111)
        // ---------------------------------------------------------
        execute_instruction(32'hFFFF_0000, 32'h0000_FFFF, 4'b0100, 1'b0, "AND", 32'h0000_0000);
        execute_instruction(32'hAAAA_AAAA, 32'h5555_5555, 4'b0100, 1'b0, "AND", 32'h0000_0000);
        execute_instruction(32'hFFFF_FFFF, 32'h1234_5678, 4'b0100, 1'b0, "AND", 32'h1234_5678);
        execute_instruction(32'hF0F0_F0F0, 32'h0F0F_0F0F, 4'b0100, 1'b0, "AND", 32'h0000_0000);
        execute_instruction(32'h1111_1111, 32'h1111_1111, 4'b0100, 1'b0, "AND", 32'h1111_1111);

        execute_instruction(32'hFFFF_0000, 32'h0000_FFFF, 4'b0101, 1'b0, "OR ", 32'hFFFF_FFFF);
        execute_instruction(32'hAAAA_AAAA, 32'h5555_5555, 4'b0101, 1'b0, "OR ", 32'hFFFF_FFFF);
        execute_instruction(32'h0000_0000, 32'h1234_5678, 4'b0101, 1'b0, "OR ", 32'h1234_5678);
        execute_instruction(32'hF0F0_F0F0, 32'h0F0F_0F0F, 4'b0101, 1'b0, "OR ", 32'hFFFF_FFFF);
        execute_instruction(32'h1111_1111, 32'h1111_1111, 4'b0101, 1'b0, "OR ", 32'h1111_1111);

        execute_instruction(32'hFFFF_0000, 32'h0000_FFFF, 4'b0110, 1'b0, "XOR", 32'hFFFF_FFFF);
        execute_instruction(32'hAAAA_AAAA, 32'h5555_5555, 4'b0110, 1'b0, "XOR", 32'hFFFF_FFFF);
        execute_instruction(32'hFFFF_FFFF, 32'hFFFF_FFFF, 4'b0110, 1'b0, "XOR", 32'h0000_0000);
        execute_instruction(32'h1234_5678, 32'h0000_0000, 4'b0110, 1'b0, "XOR", 32'h1234_5678);
        execute_instruction(32'hF0F0_F0F0, 32'h0F0F_0F0F, 4'b0110, 1'b0, "XOR", 32'hFFFF_FFFF);

        execute_instruction(32'h0000_0000, 32'h0000_0000, 4'b0111, 1'b0, "NOT", 32'hFFFF_FFFF); // Evaluates ~A
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0000, 4'b0111, 1'b0, "NOT", 32'h0000_0000);
        execute_instruction(32'hAAAA_AAAA, 32'h0000_0000, 4'b0111, 1'b0, "NOT", 32'h5555_5555);
        execute_instruction(32'h5555_5555, 32'h0000_0000, 4'b0111, 1'b0, "NOT", 32'hAAAA_AAAA);
        execute_instruction(32'h0F0F_0F0F, 32'h0000_0000, 4'b0111, 1'b0, "NOT", 32'hF0F0_F0F0);

        // ---------------------------------------------------------
        // 3. SHIFT TESTS (SLR: 0010, SLL: 0011)
        // Assuming 0 = Right, 1 = Left based on Opcode[0] mapping
        // ---------------------------------------------------------
        execute_instruction(32'h8000_0000, 32'h0000_0001, 4'b0010, 1'b0, "SLR", 32'h4000_0000);
        execute_instruction(32'h8000_0000, 32'h0000_001F, 4'b0010, 1'b0, "SLR", 32'h0000_0001); // Shift 31
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0004, 4'b0010, 1'b0, "SLR", 32'h0FFF_FFFF); // Shift 4
        execute_instruction(32'hFFFF_0000, 32'h0000_0010, 4'b0010, 1'b0, "SLR", 32'h0000_FFFF); // Shift 16
        execute_instruction(32'hAAAA_AAAA, 32'h0000_0001, 4'b0010, 1'b0, "SLR", 32'h5555_5555);

        execute_instruction(32'h0000_0001, 32'h0000_0001, 4'b0011, 1'b0, "SLL", 32'h0000_0002);
        execute_instruction(32'h0000_0001, 32'h0000_001F, 4'b0011, 1'b0, "SLL", 32'h8000_0000); // Shift 31
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0004, 4'b0011, 1'b0, "SLL", 32'hFFFF_FFF0); // Shift 4
        execute_instruction(32'h0000_FFFF, 32'h0000_0010, 4'b0011, 1'b0, "SLL", 32'hFFFF_0000); // Shift 16
        execute_instruction(32'h5555_5555, 32'h0000_0001, 4'b0011, 1'b0, "SLL", 32'hAAAA_AAAA);

        // ---------------------------------------------------------
        // 4. ROTATE TESTS (ROR: 1010, ROL: 1011)
        // ---------------------------------------------------------
        execute_instruction(32'h0000_0001, 32'h0000_0001, 4'b1010, 1'b0, "ROR", 32'h8000_0000);
        execute_instruction(32'h8000_0000, 32'h0000_001F, 4'b1010, 1'b0, "ROR", 32'h0000_0001); // Rotate 31 (equivalent to ROL 1)
        execute_instruction(32'h0F0F_0F0F, 32'h0000_0004, 4'b1010, 1'b0, "ROR", 32'hF0F0_F0F0); // Rotate 4
        execute_instruction(32'hFFFF_0000, 32'h0000_0010, 4'b1010, 1'b0, "ROR", 32'h0000_FFFF); // Rotate 16
        execute_instruction(32'hAAAA_AAAA, 32'h0000_0001, 4'b1010, 1'b0, "ROR", 32'h5555_5555);

        execute_instruction(32'h8000_0000, 32'h0000_0001, 4'b1011, 1'b0, "ROL", 32'h0000_0001);
        execute_instruction(32'h0000_0001, 32'h0000_001F, 4'b1011, 1'b0, "ROL", 32'h8000_0000); // Rotate 31 (equivalent to ROR 1)
        execute_instruction(32'hF0F0_F0F0, 32'h0000_0004, 4'b1011, 1'b0, "ROL", 32'h0F0F_0F0F); // Rotate 4
        execute_instruction(32'h0000_FFFF, 32'h0000_0010, 4'b1011, 1'b0, "ROL", 32'hFFFF_0000); // Rotate 16
        execute_instruction(32'h5555_5555, 32'h0000_0001, 4'b1011, 1'b0, "ROL", 32'hAAAA_AAAA);

        // ---------------------------------------------------------
        // 5. PASS-THROUGH TESTS (PASS A: 1100, PASS 0: 1110)
        // ---------------------------------------------------------
        execute_instruction(32'h1234_5678, 32'h0000_0000, 4'b1100, 1'b0, "PASS_A", 32'h1234_5678);
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0000, 4'b1100, 1'b0, "PASS_A", 32'hFFFF_FFFF);
        execute_instruction(32'h0000_0000, 32'h0000_0000, 4'b1100, 1'b0, "PASS_A", 32'h0000_0000);
        execute_instruction(32'hAAAA_AAAA, 32'h0000_0000, 4'b1100, 1'b0, "PASS_A", 32'hAAAA_AAAA);
        execute_instruction(32'h5555_5555, 32'h0000_0000, 4'b1100, 1'b0, "PASS_A", 32'h5555_5555);

        execute_instruction(32'h1234_5678, 32'h0000_0000, 4'b1110, 1'b0, "PASS_0", 32'h0000_0000);
        execute_instruction(32'hFFFF_FFFF, 32'h0000_0000, 4'b1110, 1'b0, "PASS_0", 32'h0000_0000);
        execute_instruction(32'h0000_0000, 32'h0000_0000, 4'b1110, 1'b0, "PASS_0", 32'h0000_0000);
        execute_instruction(32'hAAAA_AAAA, 32'h0000_0000, 4'b1110, 1'b0, "PASS_0", 32'h0000_0000);
        execute_instruction(32'h5555_5555, 32'h0000_0000, 4'b1110, 1'b0, "PASS_0", 32'h0000_0000);

        $display("=========================================================================");
        $display(" Simulation Complete.");
        $display("=========================================================================");
        
        #20;
        $finish;
    end

endmodule