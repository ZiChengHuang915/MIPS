`timescale 1ns/1ns

//tb_SimpleAdd -----------------------------------------------------------------
module tb_SimpleAdd;
	`include "params.sv" //loads "SimpleAdd.x";
	logic clk;
	logic reset;

	// instruction memory / I-cache
	logic im_rw = 1; // 1=read,0=write
	logic [31:0] im_addr, im_dout;
	logic [1:0] im_access_sz = sz_word;
	logic im_stall, im_clear;
	memory imem(.clk(clk), .addr(im_addr), .data_out(im_dout),
		.access_size(im_access_sz), .rd_wr(im_rw), .enable(~reset), .stall(im_stall), .clear(im_clear));

	// data memory / D-cache
	logic dm_rw; // 1=read,0=write
	logic [31:0] dm_addr, dm_din, dm_dout;
	logic [1:0] dm_access_sz = sz_word;
	memory dmem(.clk(clk), .addr(dm_addr), .data_in(dm_din), .data_out(dm_dout),
		.access_size(dm_access_sz), .rd_wr(dm_rw), .enable(~reset));

	// mips processor
	// #(...) overrides parameters defined inside the module
	mips #(.pc_init(mem_start), .sp_init(mem_start+mem_depth), .ra_init(0))
		proc(.clk(clk), .reset(reset),
		.instr_addr(im_addr), .instr_in(im_dout), .instr_stall(im_stall), .instr_clear(im_clear),
		.data_addr(dm_addr), .data_in(dm_dout), .data_out(dm_din),
		.data_rd_wr(dm_rw));
 
	initial begin
		clk = 1; forever #5 clk = ~clk;
	end

	int clk_cnt;

    	initial begin
	        reset <= 1;
		#10 reset <= 0;
		clk_cnt <= 0;
    	end

	always @(negedge clk) begin
		#1;
		clk_cnt <= clk_cnt + 1;
	
		$write("c %4d  ", clk_cnt);

		//---- uncomment these 5 lines to print out the PC in each stage ----
		/*
		$write("|%8h    ", tb_SimpleAdd.proc.pc); //fetch 
		$write("|%8h    ", tb_SimpleAdd.pc_ID); //decode 
		$write("|%8h               ", tb_SimpleAdd.pc_EX);//execute
		$write("|%8h                                   ", tb_SimpleAdd.proc.pc_ME);//memory
		$write("|%8h", tb_SimpleAdd.proc.pc_WB);//write back
	        */

		$write("\n");
		$write("        ");
	
		$write("|pc=%8h ", tb_SimpleAdd.proc.pc);
		$write("|ir=%8h ", tb_SimpleAdd.proc.ir);
		$write("|a=%8h, b=%8h ", tb_SimpleAdd.proc.alu_a, tb_SimpleAdd.proc.alu_b);
	
		//print when there is a MEM write operation
		if(tb_SimpleAdd.proc.st_en) begin
			$write("|alu=%8h, store %8h at [%8h] ", tb_SimpleAdd.proc.alu_out, dm_din, dm_addr);
		end
		else begin
			$write("|alu=%8h,                              ", tb_SimpleAdd.proc.alu_out);
		end
	
		//print when there is a register write operation
		if(tb_SimpleAdd.proc.reg_wr_en) begin
			$write("|write %8h to r%1d ",
				tb_SimpleAdd.proc.reg_wr_data,
				tb_SimpleAdd.proc.reg_wr_num);
		end
		else begin
			$write("|");
		end
	
		$write("\n\n");
	
		if(im_addr == 0) begin //to print until program exits
			#10 $stop;
		end
	end

	initial $dumpvars(0, tb_SimpleAdd); // creates waveform file

endmodule

// tb_SimpleIf -----------------------------------------------------------------
// only prints out the value of c returned from main
module tb_SimpleIf;
	`include "params.sv"
	logic clk;
	logic reset;
	logic [1:0] im_access_sz = sz_word;

	// instruction memory
	logic im_rw = 1;
	logic [31:0] im_addr, im_dout;
	logic im_stall, im_clear;
    	memory #(.mem_file("SimpleIf.x"))
		imem(.clk(clk), .addr(im_addr), .data_out(im_dout),
		.access_size(im_access_sz), .rd_wr(im_rw), .enable(~reset), .stall(im_stall), .clear(im_clear));

	// data memory
	logic dm_rw;
	logic [31:0] dm_addr, dm_din, dm_dout;
	logic [1:0] dm_access_sz = sz_word;
    	memory #(.mem_file("SimpleIf.x"))
		dmem(.clk(clk), .addr(dm_addr), .data_in(dm_din), .data_out(dm_dout),
		.access_size(dm_access_sz), .rd_wr(dm_rw), .enable(~reset));

	mips #(.pc_init(mem_start), .sp_init(mem_start+mem_depth), .ra_init(0))
		proc(.clk(clk), .reset(reset),
		.instr_addr(im_addr), .instr_in(im_dout), .instr_stall(im_stall), .instr_clear(im_clear),
		.data_addr(dm_addr), .data_in(dm_dout), .data_out(dm_din),
		.data_rd_wr(dm_rw));
 
    	initial begin
        	clk = 1; forever #5 clk = ~clk;
    	end

    	initial begin
        	reset <= 1;
		#10 reset <= 0;
		
		wait(im_addr==32'h80020078)
   		$display("c=%0d", tb_SimpleIf.proc.regs.data[2]);

		#10 $stop;
	end

    	initial $dumpvars(0, tb_SimpleIf);

endmodule

// tb_SimpleIf_debug -----------------------------------------------------------
// generates cycle by cycle output
module tb_SimpleIf_debug;
	`include "params.sv"
	logic clk;
	logic reset;
	logic [1:0] im_access_sz = sz_word;

	// instruction memory
	logic im_rw = 1;
	logic [31:0] im_addr, im_dout;
	logic im_stall, im_clear;
    	memory #(.mem_file("SimpleIf.x"))
		imem(.clk(clk), .addr(im_addr), .data_out(im_dout),
		.access_size(im_access_sz), .rd_wr(im_rw), .enable(~reset), .stall(im_stall), .clear(im_clear));

	// data memory
	logic dm_rw;
	logic [31:0] dm_addr, dm_din, dm_dout;
	logic [1:0] dm_access_sz = sz_word;
    	memory #(.mem_file("SimpleIf.x"))
		dmem(.clk(clk), .addr(dm_addr), .data_in(dm_din), .data_out(dm_dout),
		.access_size(dm_access_sz), .rd_wr(dm_rw), .enable(~reset));

	mips #(.pc_init(mem_start), .sp_init(mem_start+mem_depth), .ra_init(0))
		proc(.clk(clk), .reset(reset),
		.instr_addr(im_addr), .instr_in(im_dout), .instr_stall(im_stall), .instr_clear(im_clear),
		.data_addr(dm_addr), .data_in(dm_dout), .data_out(dm_din),
		.data_rd_wr(dm_rw));
 
    	initial begin
        	clk = 1; forever #5 clk = ~clk;
    	end

	int clk_cnt;

    	initial begin
	        reset <= 1;
		#10 reset <= 0;
		clk_cnt <= 0;
    	end

	always @(negedge clk) begin
		#1;
		clk_cnt <= clk_cnt + 1;
	
		$write("c %4d  ", clk_cnt);

		//---- uncomment these 5 lines to print out the PC in each stage ----
		/*
		$write("|%8h    ", tb_SimpleIf_debug.proc.pc); //fetch 
		$write("|%8h    ", tb_SimpleIf_debug.proc.pc_ID); //decode 
		$write("|%8h               ", tb_SimpleIf_debug.proc.pc_EX);//execute
		$write("|%8h                                   ", tb_SimpleIf_debug.proc.pc_ME);//memory
		$write("|%8h", tb_SimpleIf_debug.proc.pc_WB);//write back
	        */

		$write("\n");
		$write("        ");
	
		$write("|pc=%8h ", tb_SimpleIf_debug.proc.pc);
		$write("|ir=%8h ", tb_SimpleIf_debug.proc.ir);
		$write("|a=%8h, b=%8h ", tb_SimpleIf_debug.proc.alu_a, tb_SimpleIf_debug.proc.alu_b);
	
		//print when there is a MEM write operation
		if(tb_SimpleIf_debug.proc.st_en) begin
			$write("|alu=%8h, store %8h at [%8h] ", tb_SimpleIf_debug.proc.alu_out, dm_din, dm_addr);
		end
		else begin
			$write("|alu=%8h,                              ", tb_SimpleIf_debug.proc.alu_out);
		end
	
		//print when there is a register write operation
		if(tb_SimpleIf_debug.proc.reg_wr_en) begin
			$write("|write %8h to r%1d ",
				tb_SimpleIf_debug.proc.reg_wr_data,
				tb_SimpleIf_debug.proc.reg_wr_num);
		end
		else begin
			$write("|");
		end
	
		$write("\n\n");
	
		if(im_addr == 0) begin //to print until program exits
			#10 $stop;
		end
	end
endmodule

// tb_SumArray -----------------------------------------------------------------
// only prints out the sum
module tb_SumArray;
	`include "params.sv"
	logic clk;
	logic reset;
	logic [1:0] im_access_sz = sz_word;

	// instruction memory
	logic im_rw = 1;
	logic [31:0] im_addr, im_dout;
	logic im_stall, im_clear;
    	memory #(.mem_file("SumArray.x"))
		imem(.clk(clk), .addr(im_addr), .data_out(im_dout),
		.access_size(im_access_sz), .rd_wr(im_rw), .enable(~reset), .stall(im_stall), .clear(im_clear));

	// data memory
	logic dm_rw;
	logic [31:0] dm_addr, dm_din, dm_dout;
	logic [1:0] dm_access_sz = sz_word;
    	memory #(.mem_file("SumArray.x"))
		dmem(.clk(clk), .addr(dm_addr), .data_in(dm_din), .data_out(dm_dout),
		.access_size(dm_access_sz), .rd_wr(dm_rw), .enable(~reset));

	mips #(.pc_init(mem_start), .sp_init(mem_start+mem_depth), .ra_init(0))
		proc(.clk(clk), .reset(reset),
		.instr_addr(im_addr), .instr_in(im_dout), .instr_stall(im_stall), .instr_clear(im_clear),
		.data_addr(dm_addr), .data_in(dm_dout), .data_out(dm_din),
		.data_rd_wr(dm_rw));
 
	initial begin
	        clk = 1; forever #5 clk = ~clk;
    	end

    	initial begin
        	reset <= 1;
		#10 reset <= 0;
		
		wait(im_addr==32'h800200a4)
   		$display("c=%0d", tb_SumArray.proc.regs.data[2]);

		#10 $stop;
    	end

    	initial $dumpvars(0, tb_SumArray);

endmodule

// tb_SumArray_debug -----------------------------------------------------------
// generates cycle by cycle output
module tb_SumArray_debug;
	`include "params.sv"
	logic clk;
	logic reset;
	logic [1:0] im_access_sz = sz_word;

	// instruction memory
	logic im_rw = 1;
	logic [31:0] im_addr, im_dout;
	logic im_stall, im_clear;
    	memory #(.mem_file("SumArray.x"))
		imem(.clk(clk), .addr(im_addr), .data_out(im_dout),
		.access_size(im_access_sz), .rd_wr(im_rw), .enable(~reset), .stall(im_stall), .clear(im_clear));

	// data memory
	logic dm_rw;
	logic [31:0] dm_addr, dm_din, dm_dout;
	logic [1:0] dm_access_sz = sz_word;
    	memory #(.mem_file("SumArray.x"))
		dmem(.clk(clk), .addr(dm_addr), .data_in(dm_din), .data_out(dm_dout),
		.access_size(dm_access_sz), .rd_wr(dm_rw), .enable(~reset));

	mips #(.pc_init(mem_start), .sp_init(mem_start+mem_depth), .ra_init(0))
		proc(.clk(clk), .reset(reset),
		.instr_addr(im_addr), .instr_in(im_dout), .instr_stall(im_stall), .instr_clear(im_clear),
		.data_addr(dm_addr), .data_in(dm_dout), .data_out(dm_din),
		.data_rd_wr(dm_rw));
 
	
    	initial begin
        	clk = 1; forever #5 clk = ~clk;
    	end

	int clk_cnt;

    	initial begin
	        reset <= 1;
		#10 reset <= 0;
		clk_cnt <= 0;
    	end

	always @(negedge clk) begin
		#1;
		clk_cnt <= clk_cnt + 1;
	
		$write("c %4d  ", clk_cnt);

		//---- uncomment these 5 lines to print out the PC in each stage ----
		$write("|%8h    ", tb_SumArray_debug.proc.pc); //fetch 
		$write("|%8h    ", tb_SumArray_debug.proc.pc_ID); //decode 
		$write("|%8h               ", tb_SumArray_debug.proc.pc_EX);//execute
		$write("|%8h                                   ", tb_SumArray_debug.proc.pc_ME);//memory
		$write("|%8h", tb_SumArray_debug.proc.pc_WB);//write back

		$write("\n");
		$write("        ");
	
		$write("|pc=%8h ", tb_SumArray_debug.proc.pc);
		$write("|ir=%8h ", tb_SumArray_debug.proc.ir);
		$write("|a=%8h, b=%8h ", tb_SumArray_debug.proc.alu_a, tb_SumArray_debug.proc.alu_b);
	
		//print when there is a MEM write operation
		if(tb_SumArray_debug.proc.st_en) begin
			$write("|alu=%8h, store %8h at [%8h] ", tb_SumArray_debug.proc.alu_out, dm_din, dm_addr);
		end
		else begin
			$write("|alu=%8h,                              ", tb_SumArray_debug.proc.alu_out);
		end
	
		//print when there is a register write operation
		if(tb_SumArray_debug.proc.reg_wr_en) begin
			$write("|write %8h to r%1d ",
				tb_SumArray_debug.proc.reg_wr_data,
				tb_SumArray_debug.proc.reg_wr_num);
		end
		else begin
			$write("|");
		end
	
		$write("\n\n");
	
		//if (clk_cnt == 100) begin //to only printout 100 cycles
		if(im_addr == 0) begin //to print until program exits
			#10 $stop;
		end
	end

    	initial $dumpvars(0, tb_SumArray_debug);

endmodule


