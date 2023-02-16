`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:       UPB
// Engineer:      Ovidiu Moldoveanu
//
// Create Date:   11:23:41 12/11/2022
// Design Name:   tester tema2
// Module Name:   tester
// Project Name:  tema2
// Target Device: ISim
// Tool versions: 14.7
// Description:   tester for homework 2: image processing
////////////////////////////////////////////////////////////////////////////////

module tester;

    parameter early_exit = 0;                   // boolean; bail on first error
    parameter show_output = 1;                  // boolean; show info
    parameter show_image = 0;                   // boolean; show image after transformation
    parameter max_errors = 32;	               // integer; maximum number of errors to show
    
    reg [16*8-1:0] test_name;
    real test_value;
    real test_penalty;
    integer test_type;                          // 0 - piecewise test, 1 - full test
    integer max_cycles;                         // maximum cycles to wait for a transformation
    
    integer config_file, data_file;
    reg[8*512-1:0] hiding_string;
    
    initial begin
        config_file = $fopen("test.config", "r");
        if(!config_file) begin
            $write("error opening config file\n");
            $finish;
        end
        if($fscanf(config_file, "name=%16s\n", test_name) != 1) begin
            $write("error reading test name\n");
            $finish;
        end
        if($fscanf(config_file, "value=%f\n", test_value) != 1) begin
            $write("error reading test value\n");
            $finish;
        end
        if($fscanf(config_file, "penalty=%f\n", test_penalty) != 1) begin
            $write("error reading test penalty\n");
            $finish;
        end
        if($fscanf(config_file, "type=%d\n", test_type) != 1) begin
            $write("error reading test type\n");
            $finish;
        end
        if($fscanf(config_file, "max_cycles=%d\n", max_cycles) != 1) begin
            $write("error reading allowed maximum cycles for a transformation\n");
            $finish;
        end
        $fclose(config_file);

        //Open the data file
        data_file = $fopen("test.string", "r");
        if(!data_file) begin
           $write("error opening string file\n");
           $finish;
        end
       
        //Take the data string from the file
        hiding_string = 0;
        if(!$fgets(hiding_string, data_file)) begin
           $write("error reading from string file\n");
           $finish;
        end
       
        $fclose(data_file);
    end

    // Instantiate the Unit Under Test (UUT)
    wire      tst_clk, tst_img_clk;
    wire[5:0] tst_row, tst_img_row;
    wire[5:0] tst_col, tst_img_col;
    wire      tst_we;
    wire      tst_img_we;
    wire[23:0]tst_in_pix, tst_img_in_pix;
    wire[8*512-1:0] tst_hiding_string;
    wire[23:0]tst_out_pix, tst_img_out_pix;
    wire[2:0] tst_done;                         // (0-gray, 1-compress, 2-encode)
    
    image tst_img(
        .clk(tst_img_clk),
        .row(tst_img_row),
        .col(tst_img_col),
        .we(tst_img_we),
        .in(tst_img_in_pix),
        .out(tst_img_out_pix));
    
    process tst_process(
        .clk(tst_clk),
        .in_pix(tst_in_pix),
        .hiding_string(tst_hiding_string),
        .row(tst_row),
        .col(tst_col),
        .out_we(tst_we),
        .out_pix(tst_out_pix),
        .gray_done(tst_done[0]),
        .compress_done(tst_done[1]),
        .encode_done(tst_done[2]));

    // Instantiate reference implementation
    wire      ref_clk, ref_img_clk;
    wire[5:0] ref_row, ref_img_row;
    wire[5:0] ref_col, ref_img_col;
    wire      ref_we;
    wire      ref_img_we;
    wire[23:0]ref_in_pix, ref_img_in_pix;
    wire[23:0]ref_out_pix, ref_img_out_pix;
    wire[2:0] ref_done;                         // (0-gray, 1-compress, 2-encode)
    
    image ref_img(
        .clk(ref_img_clk),
        .row(ref_img_row),
        .col(ref_img_col),
        .we(ref_img_we),
        .in(ref_img_in_pix),
        .out(ref_img_out_pix));
    
    ref_process ref_process(
        .clk(ref_clk),
        .in_pix(ref_in_pix),
        .hiding_string(tst_hiding_string),  
        .row(ref_row),
        .col(ref_col),
        .out_we(ref_we),
        .out_pix(ref_out_pix),
        .gray_done(ref_done[0]),
        .compress_done(ref_done[1]),
        .encode_done(ref_done[2]));

    assign tst_hiding_string = hiding_string;

    // Tester
    reg clk;                                    // master clock
    
    reg[11:0] pix;                              // pixel being checked
    wire[5:0] row;                              // row being checked
    wire[5:0] col;                              // column being checked
    
    reg[2:0] tst_prev_done;                     // previous value of tst_*_done (0-gray, 1-compress, 2-encode)
    reg[2:0] ref_prev_done;                     // previous value of ref_*_done (0-gray, 1-compress, 2-encode)
    reg tst_finished;                           // true if tst finished
    reg ref_finished;                           // true if ref finished
    
    integer state;                              // tester FSM state
    `define START       0                       // prepare for transformation
    `define RUN         1                       // run transformation
    `define CHECK       2                       // check transformation
    `define RESULT      3                       // write results
    `define RESTORE     4                       // change tst image to known good state
    
    integer transf;                             // transformation number
    `define GRAY        0
    `define COMPRESS    1
    `define ENCODE      2
    
    reg[10*8-1 : 0] transf_name[2:0];           // transformation name as string
    initial begin
        transf_name[`GRAY]     = "grayscale";
        transf_name[`COMPRESS] = "compress";
        transf_name[`ENCODE]   = "encode";
    end
    
    integer transf_ok;                          // true if current transformation is correct
    integer transf_cycles;                      // cycles used by tst for current transformation
    
    integer transf_good_pix;                    // number of good pixels
    integer transf_bad_pix;                     // number of bad pixels
    integer transf_total_pix = 64*64;           // total pixels checked
    
    reg [12:0] disp_transf_good_pix;            // appropiate size to print transf_good_pix
    reg [12:0] disp_transf_total_pix;           // appropiate size to print transf_total_pix
    
    real result;                                // test passed percentage
    integer file;                               // results file

    initial begin
        // initialize inputs
        clk = 0;
        state = `START;
        transf = `GRAY;
        tst_finished = 0;
        ref_finished = 0;
        
        // clear results file
        file = $fopen("result.tester", "w");
        $fclose(file);
    end

    always #5 clk = !clk;
    
    assign row = pix[11:6];
    assign col = pix[ 5:0];
    
    // in the RUN state process and image clocks are active until the transformation is computed
    assign tst_clk = (state == `RUN && !tst_finished) ? clk : 0;
    assign ref_clk = (state == `RUN && !ref_finished) ? clk : 0;
    
    // in the CHECK and RESTORE states image clock is controlled by tester
    assign tst_img_clk = (state == `CHECK || state == `RESTORE) ? clk : tst_clk;
    assign ref_img_clk = (state == `CHECK || state == `RESTORE) ? clk : ref_clk;
    
    // in the CHECK and RESTORE states imgage row is controlled by tester
    assign tst_img_row = (state == `CHECK || state == `RESTORE) ? row : tst_row;
    assign ref_img_row = (state == `CHECK || state == `RESTORE) ? row : ref_row;
    
    // in the CHECK and RESTORE states imgage col is controlled by tester
    assign tst_img_col = (state == `CHECK || state == `RESTORE) ? col : tst_col;
    assign ref_img_col = (state == `CHECK || state == `RESTORE) ? col : ref_col;
    
    // in the RESTORE state tst image in_pix is controlled by tester
    assign tst_img_in_pix = (state == `RESTORE) ? ref_img_out_pix : tst_out_pix;
    
    // ref image in_pix always comes from ref process
    assign ref_img_in_pix = ref_out_pix;
    
    // in the states other than RUN tst process in_pix is tied to a constant value
    assign tst_in_pix = (state == `RUN) ? tst_img_out_pix : 24'b0;
    
    // ref process in_pix always comes from ref image
    assign ref_in_pix = ref_img_out_pix;
    
    // in the CHECK and RESTORE states image we is controlled by tester
    assign tst_img_we = state == `CHECK ? 1'b0 : (state == `RESTORE ? 1'b1 : tst_we);
    assign ref_img_we = state == `CHECK ? 1'b0 : (state == `RESTORE ? 1'b0 : ref_we);
    
    always @(posedge clk) begin                        
        tst_prev_done <= tst_done;
        ref_prev_done <= ref_done;
        
        case(state)
            `START: begin
                transf_ok <= 1;                     // assume transformation will be ok
                transf_cycles <= 1;                 // first cycle is always used
                
                tst_finished <= 0;
                ref_finished <= 0;
                
                transf_good_pix <= 0;
                transf_bad_pix <= 0;
                
                $write("test %0s - %0s", test_name, transf_name[transf]);
                
                state <= `RUN;
            end
            
            `RUN: begin
                // positive edge of done
                tst_finished <= tst_finished || ((tst_prev_done[transf] === 0) && (tst_done[transf] === 1));    // uut might generate "x"
                ref_finished <= ref_finished || ((ref_prev_done[transf] === 0) && (ref_done[transf] === 1));

                if(!tst_finished) begin
                    // tst is not done yet
                    transf_cycles <= transf_cycles + 1;
                end
                
                if(tst_finished && ref_finished) begin
                    if(show_output)
                        $write(" transformation done in %0d cycles\n", transf_cycles);
                    else
                        $write("\n");
                    
                    pix <= 0;
                    
                    state <= `CHECK;
                end
                else begin
                    // kill it if it's stuck
                    if(transf_cycles >= max_cycles) begin
                        $write("\n");
                        $write("\ttimeout after %0d cycles\n", transf_cycles);
                        
                        transf_ok <= 0;

                        pix <= 0;
                        
                        state <= `RESULT;
                    end
                end
            end
            
            `CHECK: begin
                if(pix == 0)
                    $write("--------------------------------------------------------------------------------\n");
                
                if(tst_img_out_pix === ref_img_out_pix) begin
                    transf_good_pix <= transf_good_pix + 1;
                    
                    if(show_image) $write("\tchecking (%d, %d), found R:%d G:%d B:%d\n", row, col, tst_img_out_pix[23:16], tst_img_out_pix[15:8], tst_img_out_pix[7:0]);
                end
                else begin
                    if(transf_bad_pix <= max_errors || show_image) begin
                        $write("\terror at (%d, %d), found R:%d G:%d B:%d\n", row, col, tst_img_out_pix[23:16], tst_img_out_pix[15:8], tst_img_out_pix[7:0]);
                        $write("\t                expected R:%d G:%d B:%d\n", ref_img_out_pix[23:16], ref_img_out_pix[15:8], ref_img_out_pix[7:0]);
                    end
                    if(transf_bad_pix == max_errors) begin
						$write("\t.\n");
						$write("\t.\n");
						$write("\t.\n");
					end
                    
                    transf_ok <= 0;
                    transf_bad_pix <= transf_bad_pix + 1;
                    
                    if(early_exit) begin
                        state <= `RESULT;
                    end
                end
                
                pix <= pix + 1;
                
                if(pix == -12'b1) begin
                    state <= `RESULT;
                end
            end
            
            `RESULT: begin
                result = transf_good_pix * 1.0 / transf_total_pix;

                disp_transf_good_pix = transf_good_pix;
                disp_transf_total_pix = transf_total_pix;
                
                case (transf)
                    `GRAY    : test_value = 1.5;
                    `COMPRESS: test_value = 1.2;
                    `ENCODE  : begin
                        case(test_name)
                            "image1", "image2"  : test_value = 0.6;
                            "lena"              : test_value = 0.7;
                        endcase 

                        if(transf_good_pix != transf_total_pix)
                            result = 0;
                    end 
                endcase

                file = $fopen("result.tester", "a");
                $fwrite(file, "%5.2f: %d out of %d pixels (%6.2f%% completed) test %0s - %0s\n", test_value * (result - 1.0), disp_transf_good_pix, disp_transf_total_pix, 100.0 * result, test_name, transf_name[transf]);
                $fclose(file);
                
                if(transf < `ENCODE) begin
                    state <= `START;
                    transf <= transf + 1;
                end else
                    $finish;
            end
        endcase
    end
endmodule
