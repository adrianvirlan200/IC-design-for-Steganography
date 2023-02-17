`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:03:26 11/25/2022 
// Design Name: 
// Module Name:    base2_to_base3_fsm 
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
module base2_to_base3_fsm(
    output reg [31 : 0]  	base3_no, 
    output reg           	done,
	 output reg [15 : 0]   	N,
    output reg [15 : 0]   	D,
    input		[15 : 0]    base2_no,
    input             		en,
    input              		clk,
    input    	[15 : 0]   	Q,
    input    	[15 : 0]   	R);

`define READ 	0
`define EXEC 	1
`define EXEC2 	2
`define DONE 	3
	
	reg [15:0] base2_no_r = 0;
	reg[1:0] next_state, state = `READ;
	
	// N/D = Q rest R 
	integer i = 0, next_i;
	
	//seqential part
	always@(posedge clk)begin
		state <= next_state;
		i <= next_i;
	end//always

	//combinational part
	always@(*)begin
		case(state)
		`READ: begin
			base3_no = 0;
			done = 0;
			next_i = 0;
			if(en == 1)begin
				base2_no_r = base2_no;
				next_state = `EXEC;
			end else
				next_state = `READ; 
		end//READ
		
		`EXEC:begin
			N = base2_no_r;
			D = 3;
			next_state = `EXEC2;
		end//EXEC
		
		`EXEC2:begin
			base3_no[i +: 2] = R[1:0];//doar ultimii 2 biti conteaza ptc. R este maxim 2.
			next_i = i + 2;//nu este indicat i = i+1 in partea combinationala
			
			base2_no_r = Q;
			
			if(base2_no_r != 0)
				next_state = `EXEC;
			else
				next_state = `DONE;
		end//EXEC2
		
		`DONE:begin
			done = 1;
			next_state = `READ;
		end//DONE
	
		endcase
	end//always

endmodule
