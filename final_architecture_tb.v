`timescale 1ns/1ps

module tb_top_module_full;

    reg clk;
    reg rst;
    reg start;
    reg [31:0] A_in;
    reg [31:0] B_in;
    reg [3:0] opcode;
    reg cin;

    wire [31:0] result;
    wire C;
    wire N;
    wire V;
    wire Z;
    wire done;
	
	reg [31:0] expected_result;

	reg expected_C;
	reg expected_N;
	reg expected_V;
	reg expected_Z;

	reg expected_AgreaterB;
	reg expected_AequalB;
	reg expected_AlesserB;

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
	
	task expected_model;

input [31:0] A;
input [31:0] B;
input [3:0]  opcode;
input Cin;
output reg [31:0] result;
output reg Carry;
output reg Negative;
output reg Zero;
output reg Overflow;
output reg AgreaterB;
output reg AequalB;
output reg AlesserB;

reg [32:0] temp;

begin
    result    = 32'd0;
    Carry     = 0;
    Negative  = 0;
    Zero      = 0;
    Overflow  = 0;
    AgreaterB = 0;
    AequalB   = 0;
    AlesserB  = 0;
    temp = 33'd0;

    case(opcode)
    4'b0000:
    begin
        temp   = {1'b0,A} + {1'b0,B} + Cin;
        result = temp[31:0];
        Carry  = temp[32];

        Overflow =
        (A[31]==B[31]) &&
        (result[31]!=A[31]);
    end

    4'b0001:
    begin
        temp   = {1'b0,A} + {1'b0,(~B)} + 1'b1;
        result = temp[31:0];
        Carry  = temp[32];

        Overflow =
        (A[31]!=B[31]) &&
        (result[31]!=A[31]);
    end
	
    4'b0010:
        result = A >> B[4:0];
		
    4'b0011:
        result = A << B[4:0];

    4'b0100:
        result = A & B;
		
    4'b0101:
        result = A | B;
		
    4'b0110:
        result = A ^ B;
		
    4'b0111:
        result = ~A;
		
    4'b1000:
    begin
        temp   = {1'b0,A} + 33'd1;
        result = temp[31:0];
        Carry  = temp[32];
        Overflow = (A==32'h7FFFFFFF);
    end
	
     4'b1001:
    begin
        temp = {1'b0,A} + {1'b0,(~32'h00000001)} + 1'b1;
		result = temp[31:0];
		Carry  = temp[32];
        Overflow = (A==32'h80000000);
    end

    4'b1010:
        result = (A >> B[4:0]) | (A << (32-B[4:0]));
		
    4'b1011:
        result = (A << B[4:0]) | (A >> (32-B[4:0]));
		
    4'b1100:
        result = A;

    4'b1101:
    begin
        if(A>B)
            AgreaterB = 1;
        else if(A<B)
            AlesserB = 1;
        else
            AequalB = 1;
    end

    4'b1110:
        result = 32'd0;

    4'b1111:
    begin

        if($signed(A)>$signed(B))
            AgreaterB = 1;
        else if($signed(A)<$signed(B))
            AlesserB = 1;
        else
            AequalB = 1;
    end
    endcase

    Negative = result[31];
    Zero     = (result==32'd0);

end

endtask



task execute_instruction;

input [31:0] test_A;
input [31:0] test_B;
input [3:0]  test_opcode;
input        test_cin;
input [8*20:1] op_name;

begin
    @(negedge clk);

    A_in   = test_A;
    B_in   = test_B;
    opcode = test_opcode;
    cin    = test_cin;
    start = 1;

    @(negedge clk);
    start = 0;

    wait(done);

    expected_model(
        test_A,
        test_B,
        test_opcode,
        test_cin,
        expected_result,
        expected_C,
        expected_N,
        expected_Z,
        expected_V,
        expected_AgreaterB,
        expected_AequalB,
        expected_AlesserB
    );

//    $display("------------------------------------------------------------");
//    $display("Operation : %s",op_name);
//    $display("Opcode    : %b",test_opcode);
//    $display("A         : %h",test_A);
//    $display("B         : %h",test_B);
//    $display("Cin       : %b",test_cin);

    if(test_opcode==4'b1101 || test_opcode==4'b1111)
    begin

        if(uut.alu1.AgreaterB==expected_AgreaterB &&
		   uut.alu1.AequalB==expected_AequalB &&
		   uut.alu1.AlesserB==expected_AlesserB)
		begin
			//passed
		end
        else
        begin
            $display("STATUS    : FAIL");
            $display("Expected  : G=%b E=%b L=%b", expected_AgreaterB, expected_AequalB, expected_AlesserB);
            $display("Actual    : G=%b E=%b L=%b", uut.alu1.AgreaterB, uut.alu1.AequalB, uut.alu1.AlesserB);
        end
    end
	
    else
    begin
       if(result==expected_result &&
		   C==expected_C &&
		   N==expected_N &&
		   V==expected_V &&
		   Z==expected_Z)
		begin
			// passed
		end
		else
		begin
			$display("x----------------x----------------x");
			$display("FAILED RANDOM TEST");
			$display("Opcode : %b",test_opcode);
			$display("A      : %h",test_A);
			$display("B      : %h",test_B);
			$display("Cin    : %b",test_cin);

			$display("Expected Result : %h",expected_result);
			$display("Actual Result   : %h",result);

			$display("Expected Flags : C=%b N=%b V=%b Z=%b",
					  expected_C,
					  expected_N,
					  expected_V,
					  expected_Z);

			$display("Actual Flags   : C=%b N=%b V=%b Z=%b",
					  C,N,V,Z);
		end
    end
    @(negedge clk);
end
endtask

	reg [31:0] ranA;
	reg [31:0] ranB;
	reg [3:0] ranopcode;
	reg ranCin;

	integer i;

initial
begin
    rst    = 1;
    start  = 0;
    A_in   = 0;
    B_in   = 0;
    opcode = 0;
    cin    = 0;
    #20;
    rst = 0;
    #20;

    $display("Automated Testbench");
	for(i=0;i<10000;i=i+1)
		begin
			ranA      = $random;
			ranB      = $random;
			ranopcode = $random & 4'hF;
			ranCin    = $random & 1'b1;

			execute_instruction(
				ranA,
				ranB,
				ranopcode,
				ranCin,
				"RANDOM"
			);

		end
    $display("Completed");

    #20;
    $finish;
end
endmodule