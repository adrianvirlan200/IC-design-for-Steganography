# First part consists of a finite state machine that aims to transform a number from base 2 to base 3.
In order to solve the assignment it is necessary to divide the problem into 2 distinct modules with specific functionalities. The block diagram is shown in Fig1. Block diagram:
![image](https://github.com/adrianvirlan200/IC-design-for-Steganography/assets/74298808/8dec10a8-78d4-412b-aeba-c93e817e9913)

The first module, named **div_algo**, contains the implementation of **long division algorithm** and has the following signals: 
* Q - quotient
* R - reminder
* N - divide
* D - divisor

The main module, which is called **base2_to_base3**, implements the FSM and contains the following signals:
* base3_no - the value of the number expressed in base 3
* done - signal marking the end of the conversion; it must be asserted when the final value is present on the base3_no output port
* base2_no - number in base 2 to be converted to base 3
* en - signal indicating that the number present on port base2_no is valid and can be read
* clk - clock signal
  
The FSM behavior is summarized by the following picture:
  ![image](https://github.com/adrianvirlan200/IC-design-for-Steganography/assets/74298808/97da4249-2f96-43cf-a589-9bddbbcbe37c)
  
* READ - state in which the input value is read and saved in an auxiliary register base2_no_r; the next state will be changed after the number is read;
* EXEC - state in which the division operation is executed; in this state the corresponding values are given to the div_algo module
* EXEC2- state in which the result of the division is read; after this the number is composed in base3 and the next transition is decided, depending on the value of base2_no_r
* DONE - final state marking the end of execution; in this state the done signal is asserted


# Second part consists of a synchronous sequential circuit that hides a secret message in an image.
The initial images are represented in RGB color space and are 64×64 elements (pixels) in size, where each element has 24 bits (8 'R' bits, 8 'G' bits and 8 'B' bits). The message is text, with characters belonging to the extASCII set (8 bits required for each character). In order to be able to encrypt the message in the image, the following processing steps will be required:
## 1. Image conversion from RGB to grayscale
The initial image is coded in RGB space, with values on all three channels. The resulting image will be stored in 8 bits in the 'G' channel. The value in channel 'G' will be calculated as the average of the maximum and minimum values in the three channels. After this operation, channels 'R' and 'B' will be set to '0'. Each pixel is processed individually.

## 2. Image compression using the AMBTC method
The AMBTC algorithm is based on dividing a grayscale image into sub-blocks of sufficiently small size M (in our case 4 x 4 ) and modifying each of them on two levels, Lm and Hm . The following steps are performed for each block of the image:
![image](https://github.com/adrianvirlan200/IC-design-for-Steganography/assets/74298808/2745e3ea-9951-4822-8132-7c525f1bbf76)

## 3. Encapsulating the message in the processed image
The message to be encrypted is made up of a string of ASCII characters . Each character is encoded in 8 bits. Thus, in each block we can encapsulate only 2 characters. Initially the bit string will convert from base 2 to base 3. Each valueSj
will be integrated into the pixels of the block, except for the first value Lm and Hm. The procedure will be executed according to the following algorithm:

![image](https://github.com/adrianvirlan200/IC-design-for-Steganography/assets/74298808/95242310-7567-49ce-b7e5-91f272b42b0e)
_______________________________________________________________________________________________________________________________________________________________________________________________________
# Implementation
**Image** - The module responsible for loading the image from the file into the internal memory, it represents the interface between the fsm implemented in the process and the image. Using the control signals, the module processcan read or write individual elements (pixels).
* clk- clock signal;
* row- select a row from the image;
* col- select a column from the image;
* we - write enable - activates writing in the image to the given row and column;
* in - the value of the pixel that will be written on the given position;
* out- the value of the pixel that will be read from the given position.
  
To read a pixel from the image to be processed (out), the rowand signals must be set col. The value will be immediately available on the signal out.
To write a pixel from the processed image (in), the signals rowand col, as well as the signal , must be set we. The value present on the signal inwill be stored in memory on the next clock cycle.

**Process** - The finite state machine that will model the behavior must be implemented in the process module. Here all necessary transformations will be performed and base2_to_base3 will be instantiated, useful in the character transformation sequence in the last step.
* clk- clock signal;
* in_pix- the value of the pixel at position [row, col] in the input image (R 23:16; G 15:8; B 7:0);
* hiding_string- the string to be encoded;
* row, col- selects a pixel from the image at position (row, col), both for reading and writing;
* out_we- enable writing for the output image (write enable);
* out_pix- the pixel value that will be written in the output image at position [row, col] (R 23:16; G 15:8; B 7:0);
* gray_done- signals the end of the grayscale transformation action (active on 1);
* compress_done- signals the end of the compression action (active on 1);
* encode_done- signals the end of the coding action (active on 1).

* Var. row and col are always assigned i+block_i and j+block_j respectively.
Block_i and block_j indicate the pixel where the current block starts and they vary in increments of 4
 
-> GRAY_SCALE:
	The grayscale part contains 3 states. In this stage i and j vary from 0...63, and block_i and block_j always have the value 0 (no blocks count at this stage). In the first state I save each pixel component on the row and col in a vector and calculate the average of the minimum and maximum.
	In the second state, I assign out_pix the average value in the required format, write the pixel and calculate the next row and col(i and j). If i and j are 63 it means that the stage is finished and the variable gray done can be made 1(in a special state)
 
-> COMPRESSS:
The compress part contains 8 states. Now i and j vary from 0...3, and block_i and block_j from 0...63, but in increments of 4.
In the Choose_operation step, using the op variable, I switch to the state characteristic of the current operation (each operation has its own state). There are 4 different operations that each require iteration through all the elements of the block, so I can use the same state that increments row and col for all operations and blocks.
In each of the 4 steps I calculate the operation( AVG, var, bitmap, or rewrite result), switch to the state that increments row and col(only inside the block), and at the end if i and j are not 3, switch back to the choose_op state. If i and j are 3, it means that the current step is finished and go to the next one (change wave to op and return to choose_operation).
When the last operation is done, you can increment block_i and block_j, reset the necessary variables (op = 0, sum, etc.) and go to the next block, repeating the 4 processes again.
When block_i and block_j are 63, compression is finished and you can set compress_done to 1, in a special state.
The Choose_operation state has also been chosen to wait for a clock pulse, so that the row and col signal are set accordingly.

-> ENCODE:
The encode state contains 8 states. Iteration on elements/blocks is done as in the previous step. 
The first state reads the first 16 bits (2 characters) of the string and transforms them to base 3. As long as the done is 0, I wait for the transformation to take place, and when it becomes 1 it means that the converted number in base 3 is available on the output, which can be saved and moved to the next state.
The Choose_operation state is intended to redirect the execution thread to the current operation (same as compress). 
There are 2 operations that are performed in this step. The first one determines the second element to be excepted (the first one is always excepted, and if all the elements of the block are the same the second element is taken as excepted) and saves its coordinates in 2 variables. The second state is the one in which encryption and rewriting is performed, according to the given algorithm (the first element is ignored, and the one indicated by the pair determined in the previous state). 
When all blocks have been completed, the encode_done variable can be set to 1, in a final state..
