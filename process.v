`timescale 1ns / 1ps

module process (
        input                clk,		    		// clock 
        input  [23:0]        in_pix,	        	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
        input  [8*512-1:0]   hiding_string,     // sirul care trebuie codat
        output  reg [6-1:0]  row, col, 	      // selecteaza un rand si o coloana din imagine
        output  reg          out_we, 		   	// activeaza scrierea pentru imaginea de iesire (write enable)
        output  reg [23:0]   out_pix,	        	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
        output  reg          gray_done,		   // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
        output  reg          compress_done,		// semnaleaza terminarea actiunii de compresie (activ pe 1)
        output  reg          encode_done        // semnaleaza terminarea actiunii de codare (activ pe 1)
    );	
    
    //TODO - instantiate base2_to_base3 here
    	 
	reg en;
	wire done;
	reg [15:0] base2;
	wire [31:0] base3_no;

	base2_to_base3 #(16,3,2) b2_to_b3(.base3_no(base3_no), .done(done), .base2_no(base2), .en(en), .clk(clk));
	 
    //TODO - build your FSM here
`define R 	2
`define G 	1
`define B 	0

`define M	3
 
`define GRAYSCALE_READ_PIXEL				0
`define GRAYSCALE_WRITE_PIXEL				1
`define GRAY_DONE								2

`define AMBTC_CHOOSE_OPERATION			3
`define AMBTC_AVG								4
`define AMBTC_var								5
`define AMBTC_BUILD_BITMAP					6
`define AMBTC_RECONSTRUCT					7
`define AMBTC_CHOOSE_NEXT_ELEMENT		8
`define AMBTC_CHOOSE_NEXT_BLOCK			9
`define COMPRESS_DONE						10

`define ENCODE_READ_STRING					11
`define ENCODE_READ_PIXEL					12
`define ENCODE_CHOOSE_NEXT_ELEMENT  	13
`define ENCODE_CHOOSE_NEXT_BLOCK			14
`define ENCODE_CHECK							15
`define ENCODE_EMBEDDING					16
`define ENCODE_CHOOSE_NEXT_OPERATION	17
`define ENCODE_DONE							18
	 
	reg [4:0] state = `GRAYSCALE_READ_PIXEL, next_state;
	
	reg [6-1:0] i = 0, j = 0;
	reg [6-1:0] next_i = 0, next_j = 0;
	reg [6-1:0] block_i = 0, block_j = 0;
	reg [6-1:0]	next_block_i = 0, next_block_j = 0;
	
	reg [7:0] RGB [2:0]; // RGB[2] = R, RGB[1] = G, RGB[0] = B
	reg [1:0] min_index, max_index;
	reg [1:0] iterator;
	
	
	reg [11:0] sum = 0, next_sum = 0;
	reg [7:0] AVG, var;
	reg [4:0] beta, next_beta;//numere de la 0->16, avem nev de 5 biti!
	reg aux [3:0][3:0];
	reg [7:0] Lm, Hm;
	reg [1:0] op, next_op; //pt.compress: op=0->AVG, op=1->var, op=2->bitmap, op=3->reconstruct
								  //pt.encode: op=0->Check, op=1->embedding
	
	reg [8*512 - 1:0] string_iterator = 0, next_string_iterator = 0;
	reg [27:0] base3_iterator = 0, next_base3_iterator = 0;
	reg [27:0] base3;
	reg second_ignored = 0;
	reg [6-1:0] second_i, second_j;
	
	//sequential part
	always@(posedge clk)begin
		state <= next_state;
		
		i <= next_i;
		j <= next_j;
		block_i <= next_block_i;
		block_j <= next_block_j;
		
		op <= next_op;
		sum <= next_sum;
		beta <= next_beta;
		
		string_iterator <= next_string_iterator;
		base3_iterator <= next_base3_iterator;
	end//always
	
	
	//combinational part
	always@(*)begin
		row = i + block_i;
		col = j + block_j;
		
		out_pix = 0;
		out_we =	0;
		gray_done = 0;
		compress_done = 0;
		encode_done =  0;
		
		en = 0;
		
		case(state)
//GRAYSCALE--------------------------------------------------------------------------------------------------------------------------------------
		`GRAYSCALE_READ_PIXEL:begin	
		
			RGB[`R] = in_pix[23:16];
			RGB[`G] = in_pix[15:8];
			RGB[`B] = in_pix[7:0];
			
			max_index = `B;
			min_index = `B;
			
			for(iterator = 1; iterator < 3; iterator = iterator + 1)begin
				if(RGB[iterator] <= RGB[min_index])
						min_index = iterator;
				if(RGB[iterator] >= RGB[max_index])
						max_index = iterator;
			end

			next_state = `GRAYSCALE_WRITE_PIXEL;	
		end//GRAYSCALE_READ_PIXEL
		
		
		
		`GRAYSCALE_WRITE_PIXEL:begin
			out_pix[23:16] = 0;
			out_pix[7:0] = 0;
			out_pix[15:8] = (RGB[min_index] + RGB[max_index])/2;			
			out_we = 1;
			
			if(i <= 63 && j < 63)begin
				next_i = i;
				next_j = j + 1;
				next_state = `GRAYSCALE_READ_PIXEL;
			end 
			else if(i < 63 && j == 63)begin
				next_i = i + 1;
				next_j = 0;
				next_state = `GRAYSCALE_READ_PIXEL;
			end
			else if(i == 63 && j == 63)
				next_state = `GRAY_DONE;	
		end//GRAYSCALE_WRITE_PIXEL
		
		
		
		`GRAY_DONE:begin
			gray_done = 1;
			
			next_op = 0;
			next_sum = 0;
			AVG = 0;
			var = 0;
			
			next_i = 0;
			next_j = 0;
			next_block_i = 0;
			next_block_j = 0;
			
			next_state = `AMBTC_CHOOSE_OPERATION;
		end//GRAY_DONE
		
		
		
//COMPRESS--------------------------------------------------------------------------------------------------------------------------------------	
		`AMBTC_CHOOSE_OPERATION:begin
			//aceasta stare redirectioaneaza firul de executie spre etapa curenta
			case(op)
				0: next_state = `AMBTC_AVG;
				1: next_state = `AMBTC_var;
				2: next_state = `AMBTC_BUILD_BITMAP;
				3: next_state = `AMBTC_RECONSTRUCT;
			endcase
			
		end//AMBTC_CHOOSE_OPERATION
		
		
		
		`AMBTC_AVG:begin
			next_sum = sum + in_pix[15:8];
			next_state = `AMBTC_CHOOSE_NEXT_ELEMENT;
		end//AMBTC_AVG
	
	
	
		`AMBTC_var:begin
			next_sum = sum + ((in_pix[15:8] > AVG) ? (in_pix[15:8] - AVG) : (AVG - in_pix[15:8]));
			next_state = `AMBTC_CHOOSE_NEXT_ELEMENT;
		end//AMBTC_var
					
					
					
		`AMBTC_BUILD_BITMAP:begin
			if(in_pix[15:8] >= AVG)begin
				aux[i][j] = 1;
				next_beta = beta + 1;
			end else 
				aux[i][j] = 0;
				
			next_state = `AMBTC_CHOOSE_NEXT_ELEMENT;
		end//BUILD_BITMPAP
				
				
				
		`AMBTC_RECONSTRUCT:begin
			out_pix[23:16] = 0;
			out_pix[7:0] = 0;

			if(aux[i][j] == 0)
				out_pix[15:8] = Lm;
			else
				out_pix[15:8] = Hm;
			out_we = 1;
			
			next_state = `AMBTC_CHOOSE_NEXT_ELEMENT;
		end//AMBTC_RECONSTRUCT
		
		
		
		`AMBTC_CHOOSE_NEXT_ELEMENT:begin
			next_state = `AMBTC_CHOOSE_OPERATION;
		
			if(i <= `M && j < `M)begin
				next_i = i;
				next_j = j + 1;
			end
			else if(i < `M && j == `M)begin
				next_i = i + 1;
				next_j = 0;
			end
			else if(i == `M && j == `M)begin
			//atunci cand se termina de facut operatia curenta pentru blocul curent
			//se fac o serie de prelucrari/salvari caracteristice fiecarei operatii
			//dupa care se trece la urmatoarea operatie
				case(op)
				0:begin
					AVG = sum /16;
					next_sum = 0;
					
					next_i = 0;
					next_j = 0;
		
					next_op = 1;
				end//0
				
				1:begin
					var = sum /16;
					next_sum = 0;
					
					next_i = 0;
					next_j = 0;
					
					next_beta = 0;
					next_op = 2;
				end//1
				
				2:begin
					Lm = AVG - (4 * 4 * var)/(2 * (4 * 4 - beta));
					Hm = AVG + (4 * 4 * var)/(2 * beta);
					
					next_i = 0;
					next_j = 0;
					
					next_op = 3;
				end//2
				
				3:begin
					//s-a terminat prelucrarea pentru blocul curent
					//asa ca se incremeneteaza blocul si se repeta toate operatiile
					next_state = `AMBTC_CHOOSE_NEXT_BLOCK;
				end//3
				endcase

			end//else ifs
		end//CHOOSE NEXT ELEMENT
		
		
		
		`AMBTC_CHOOSE_NEXT_BLOCK:begin
			
			next_op = 0;
			next_sum = 0;
			AVG = 0;
			var = 0;
			Lm = 0;
			Hm = 0;
			
			next_i = 0;
			next_j = 0;
			
			if(block_i + `M <= 63 && block_j + `M  < 63)begin
				next_block_i = block_i;
				next_block_j = block_j + 4;
				next_state = `AMBTC_CHOOSE_OPERATION;
			end
			else if(block_i + `M   < 63 && block_j + `M  == 63)begin
				next_block_i = block_i + 4;
				next_block_j = 0;
				next_state = `AMBTC_CHOOSE_OPERATION;
			end
			else if(block_i + `M  == 63 && block_j + `M  == 63)
				next_state = `COMPRESS_DONE;
		end//AMBTC_CHOOSE_NEXT_BLOCK
		
		
		
		`COMPRESS_DONE:begin	
			compress_done = 1;
			
			next_i = 0;
			next_j = 0;
			next_block_i = 0;
			next_block_j = 0;
			
			next_string_iterator = 0;
			
			next_state = `ENCODE_READ_STRING;
		end//COMPRESS_DONE
		
		
		

//ENCODE--------------------------------------------------------------------------------------------------------------------------------------
		
		`ENCODE_READ_STRING:begin
			//sta in aceasta stare cat timp se converteste in baza 3
			if(done == 0)begin
				base2 = hiding_string[string_iterator +: 16];
				en = 1;
				
				next_state = `ENCODE_READ_STRING;
			end 
			else begin
				base3 = base3_no[27:0];
				next_string_iterator = string_iterator + 16;
				
				next_base3_iterator = 0;
				second_ignored = 0;
				next_op = 0;
			
				next_state = `ENCODE_CHOOSE_NEXT_OPERATION;
			end
			
		end//ENCODE
	
		`ENCODE_CHOOSE_NEXT_OPERATION:begin
			case(op)
				0:next_state = `ENCODE_CHECK;
				1:next_state = `ENCODE_EMBEDDING;
			endcase
		end//ENCODE_CHOOSE_NEXT_OPERATION
		
		
		
		`ENCODE_CHECK:begin
			next_state = `ENCODE_CHOOSE_NEXT_ELEMENT;
			
			if(i == 0 && j == 0)begin//primul mereu exceptat
				Hm = in_pix[15:8];
			end 
			else if(in_pix[15:8] != Hm && second_ignored == 0)begin//daca se gaseste al doilea
					second_ignored = 1;
					second_i = row;//salveaza indicii
					second_j = col;
					
					next_op = 1;
					
					next_i = 0;
					next_j = 1;
					next_state = `ENCODE_CHOOSE_NEXT_OPERATION;
			end
			else if(i == `M && j == `M && second_ignored == 0)begin
				//daca nu s-a gasit al doilea => toate elementele sunt identice
				//se iau primul si al doilea ca fiind exceptati
				second_i = block_i;
				second_j = block_j + 1;
				
				next_op = 1;
				
				next_i = 0;
				next_j = 1;
				
				next_state = `ENCODE_CHOOSE_NEXT_OPERATION;
			end
			
		end//ENCODE_CHECK
		
		`ENCODE_EMBEDDING:begin
			if(row != second_i || col != second_j) begin//ignora-l pe al doilea
				if(base3[base3_iterator +: 2] == 1)begin
					out_pix[7:0] = 0;
					out_pix[23:16] = 0;
					out_pix[15:8] = in_pix[15:8] + 1;
					out_we = 1;
					
					next_base3_iterator = base3_iterator + 2;
				end
				else if(base3[base3_iterator +: 2] == 2) begin
					out_pix[7:0] = 0;
					out_pix[23:16] = 0;
					out_pix[15:8] = in_pix[15:8] - 1;
					out_we = 1;
					
					next_base3_iterator = base3_iterator + 2;
				end
				else if(base3[base3_iterator +: 2] == 0)
					next_base3_iterator = base3_iterator + 2;
			end
			
			next_state = `ENCODE_CHOOSE_NEXT_ELEMENT;
		end//EMBEDDING_NORMAL
		
	
		
		`ENCODE_CHOOSE_NEXT_ELEMENT:begin
			next_state = `ENCODE_CHOOSE_NEXT_OPERATION;
			
			if(i <= `M && j < `M)begin
				next_i = i;
				next_j = j + 1;
			end 
			else if(i < `M && j == `M)begin
				next_i = i + 1;
				next_j = 0;
			end
			else if(i == `M && j == `M)
				next_state = `ENCODE_CHOOSE_NEXT_BLOCK;
		end//ENCODE_CHOOSE_NEXT_ELEMENT
		
		
		
		`ENCODE_CHOOSE_NEXT_BLOCK:begin
			next_state = `ENCODE_READ_STRING;
			
			next_i = 0;
			next_j = 0;
			
			second_ignored = 0;

			next_op = 0;
			next_base3_iterator = 0;
			
			if(block_i + `M <= 63 && block_j + `M  < 63)begin
				next_block_i = block_i;
				next_block_j = block_j + 4;
			end
			else if(block_i + `M   < 63 && block_j + `M  == 63)begin
				next_block_i = block_i + 4;
				next_block_j = 0;
			end
			else if(block_i + `M  == 63 && block_j + `M  == 63)
				next_state = `ENCODE_DONE;
		end//ENCODE_CHOOSE_NEXT_BLOCK
		
		`ENCODE_DONE:begin
			encode_done = 1;
		end//EMBEDDING_DONE
		
		
		endcase
	end//always
endmodule
