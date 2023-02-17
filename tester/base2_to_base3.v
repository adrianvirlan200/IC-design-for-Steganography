`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:40:08 11/25/2022 
// Design Name: 
// Module Name:    base2_to_base3 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module base2_to_base3 (
    output   [31 : 0]  base3_no, 
    output             done,
    input    [15 : 0]  base2_no,
    input              en,
    input              clk);
	
	wire[15:0] D, N, Q, R;

	base2_to_base3_fsm fsm(.base3_no(base3_no), .done(done),.N(N),.D(D),.base2_no(base2_no),.en(en),.clk(clk),.Q(Q),.R(R));
	div_algo div(.Q(Q), .N(N), .D(D), .R(R));
endmodule
