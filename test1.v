`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   21:09:20 12/12/2022
// Design Name:   process
// Module Name:   C:/Users/adi/Desktop/AC/tema2/test1.v
// Project Name:  tema2
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: process
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test1;

	// Inputs
	reg clk;
	reg [23:0] in_pix;
	reg [4095:0] hiding_string;

	// Outputs
	wire [5:0] row;
	wire [5:0] col;
	wire out_we;
	wire [23:0] out_pix;
	wire gray_done;
	wire compress_done;
	wire encode_done;

	// Instantiate the Unit Under Test (UUT)
	process uut (
		.clk(clk), 
		.in_pix(in_pix), 
		.hiding_string(hiding_string), 
		.row(row), 
		.col(col), 
		.out_we(out_we), 
		.out_pix(out_pix), 
		.gray_done(gray_done), 
		.compress_done(compress_done), 
		.encode_done(encode_done)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		in_pix = 0;
		hiding_string = 0;

		// Wait 100 ns for global reset to finish
		#100;
      clk = 0;
		in_pix = 24'b111111111111111111111111;
		hiding_string = 0;
		// Add stimulus here

	end
      always clk = !clk;
endmodule

