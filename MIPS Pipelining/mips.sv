module mips(
	// port listpc_plus4
	input clk, reset,
	output [31:0] instr_addr,
	input [31:0] instr_in,
	output instr_stall,
	output instr_clear,
	output [31:0] data_addr,
	input [31:0] data_in,
	output logic [31:0] data_out,
	output data_rd_wr);

	// parameters overridden in testbench
	parameter [31:0] pc_init = 0;
	parameter [31:0] sp_init = 0;
	parameter [31:0] ra_init = 0;

	// IF signals
	logic [31:0] pc;
 	logic [31:0] ir;

	// pipeline registers
	logic [31:0] pc_ID;
	logic [31:0] pc_EX;
	logic [31:0] pc_ME;
	logic [31:0] pc_WB;
	logic [31:0] ir_ID;
	logic [31:0] ir_EX;
	logic [31:0] ir_ME;
	logic [31:0] ir_WB;

	// ID signals
	logic [4:0] reg_rd_num0, reg_rd_num1;
	wire [31:0] reg_rd_data0, reg_rd_data1;
	
	// stall and squash signal
	logic stall, clear;

	// EX signals
	logic [31:0] alu_a, alu_b, sign_ext_imm;
	logic [5:0] shift_amt;
	logic [31:0] alu_out;
	wire alu_compare;
	logic [31:0] pc_plus4;
	logic br_taken;
	logic [31:0] br_target;

	// pipeline registers
	logic [31:0] alu_a_EX, alu_b_EX, sign_ext_imm_EX, shift_amt_EX;
	logic [31:0] alu_b_ME, alu_out_ME;
	logic [31:0] alu_out_WB;
	logic [31:0] br_target_ME;
	logic br_taken_ME;

	// ME signals
	logic st_en;

	// WB signals
 	logic [4:0] reg_wr_num_WB;
	logic reg_wr_en_WB;
	logic [4:0] reg_wr_num;
	logic [31:0] reg_wr_data;
	logic reg_wr_en;

	// pipeline registers
	logic reg_wr_en_WB_EX, reg_wr_en_WB_ME, reg_wr_en_WB_WB;
	logic [4:0] reg_wr_num_WB_EX, reg_wr_num_WB_ME, reg_wr_num_WB_WB;

	enum { init, fetch, id, ex, me, wb } state;

	// register file
	regfile #(.sp_init(sp_init), .ra_init(ra_init)) regs(
		.wr_num(reg_wr_num), .wr_data(reg_wr_data), .wr_en(reg_wr_en),
		.rd0_num(reg_rd_num0), .rd0_data(reg_rd_data0),
		.rd1_num(reg_rd_num1), .rd1_data(reg_rd_data1),
		.clk(clk), .reset(reset));

	// instructions: ir[31:26]
	parameter [5:0] ADDIU   = 6'b001001; 
	parameter [5:0] SW      = 6'b101011;
	parameter [5:0] LW      = 6'b100011; 
	parameter [5:0] J       = 6'b000010; 
    parameter [5:0] SLTI    = 6'b001010; 
    parameter [5:0] BEQ     = 6'b000100;
	parameter [5:0] BNE		= 6'b000101;
	parameter [5:0] SPECIAL = 6'b000000; 

	//SPECIAL instructions: ir[5:0]
	parameter [5:0] JR      = 6'b001000;
	parameter [5:0] ADDU    = 6'b100001; 
    parameter [5:0] SUBU    = 6'b100011;
	parameter [5:0] SLL     = 6'b000000;

	//Combinatorial wiring
	//for instruction memory module
	assign instr_addr = pc; 
	assign ir = instr_in;
	//for register file module
	assign reg_rd_num0 = ir[25:21]; // rs
	assign reg_rd_num1 = ir[20:16]; // rt
	//for data memory module
	assign data_out = alu_b_ME; 
	assign data_rd_wr = ~st_en; 
	assign data_addr = alu_out;
	//for squash/stall logic
	assign instr_clear = clear;
	assign instr_stall = stall;
        
	//Combinatorial ALU operation (for branch instructions)
	assign alu_compare = (alu_a == alu_b); 	

	// pipelined
	//FSM part of the control unit, as well as registers in the datapath
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			state <= init;
			pc <= pc_init;
			pc_ID <= pc_init;
			pc_EX <= pc_init;
			pc_ME <= pc_init;
			pc_WB <= pc_init;
			alu_a <= 'x;
			alu_a_EX <= 'x;
			alu_b <= 'x;
			alu_b_EX <= 'x;
			alu_b_ME <= 'x;
			sign_ext_imm <= 'x;
			sign_ext_imm_EX <= 'x;
			reg_wr_en_WB <= 0;
			reg_wr_en_WB_EX <= 0;
			reg_wr_en_WB_ME <= 0;
			reg_wr_en_WB_WB <= 0;
			reg_wr_num_WB <= 'x;
			reg_wr_num_WB_EX <= 'x;
			reg_wr_num_WB_ME <= 'x;
			reg_wr_num_WB_WB <= 'x;
		end
		else begin
			// fetch
			if (br_taken == 1) begin //this circuit is physically located in the IF part of the datapath 
				pc <= br_target;
			end
			else if (br_taken == 0 && stall == 0) begin
				pc <= pc + 4;
			end

			// decode
			alu_a <= reg_rd_data0;
			alu_b <= reg_rd_data1;
			sign_ext_imm_EX <= {{16{ir[15]}}, ir[15:0]};
			shift_amt_EX <= ir[10:6];				

			//decode the Write Back related register & control signal in ID stage
			if (((ir[31:26] == SPECIAL) && (ir[5:0] == ADDU)) ||
				((ir[31:26] == SPECIAL) && (ir[5:0] == SUBU)) ||
				(ir[31:26] == SLTI) ||
				(ir[31:26] == ADDIU) ||
				(ir[31:26] == LW) ||
				((ir[31:26] == SPECIAL) && (ir[5:0] == SLL))) begin
				reg_wr_en_WB_EX <= 1;
			end
			else begin
				reg_wr_en_WB_EX <= 0;
			end

			if (((ir[31:26] == SPECIAL) && (ir[5:0] == ADDU)) ||
				((ir[31:26] == SPECIAL) && (ir[5:0] == SUBU)) ||
				((ir[31:26] == SPECIAL) && (ir[5:0] == SLL))) begin
				reg_wr_num_WB_EX <= ir[15:11];
			end
			else begin
				reg_wr_num_WB_EX <= ir[20:16];
			end

			if (stall == 0) begin
				ir_EX <= ir;
			end
			else begin
				ir_EX <= 32'b0;
				reg_wr_en_WB_EX <= 0;
			end

			pc_EX <= pc;

			// execute
			case (ir_EX[31:26])
				ADDIU:  alu_out <= alu_a + sign_ext_imm_EX;
				LW:		alu_out <= alu_a + sign_ext_imm_EX;
				SW:		alu_out <= alu_a + sign_ext_imm_EX;
				SLTI:	alu_out <= (alu_a < sign_ext_imm_EX);
				SPECIAL:	
					if (ir_EX[5:0] == SUBU) begin
						alu_out <= alu_a - alu_b;
					end
					else if (ir_EX[5:0] == ADDU) begin
						alu_out <= alu_a + alu_b;
					end	
					else if (ir_EX[5:0] == SLL) begin
						alu_out <= alu_b << shift_amt_EX;
					end	
				default:        alu_out <= alu_a + alu_b;
			endcase

			ir_ME <= ir_EX;
			alu_b_ME <= alu_b;
			pc_ME <= pc_EX;
			reg_wr_en_WB_ME <= reg_wr_en_WB_EX;
			reg_wr_num_WB_ME <= reg_wr_num_WB_EX;

			// memory
			ir_WB <= ir_ME;
			pc_WB <= pc_ME;
			reg_wr_en_WB_WB <= reg_wr_en_WB_ME;
			reg_wr_num_WB_WB <= reg_wr_num_WB_ME;
			alu_out_WB <= alu_out;

			// writeback
		end
	end

	// pipelined
	//Cominatorial part of control unit
	always @(*) begin
		st_en = 0;
		reg_wr_en = 0;
		reg_wr_num = 'x;
		reg_wr_data = 'x;
		br_target = 'x;
		br_target_ME = 'x;
		br_taken = 0;
		br_taken_ME = 0;
		pc_plus4 = 'x;

		//decode
		// Check for hazards and stall
		if ((reg_rd_num0 == reg_wr_num_WB_EX && reg_wr_en_WB_EX == 1) || (reg_rd_num0 == reg_wr_num_WB_ME && reg_wr_en_WB_ME == 1) || 
			(reg_rd_num1 == reg_wr_num_WB_EX && reg_wr_en_WB_EX == 1) || (reg_rd_num1 == reg_wr_num_WB_ME && reg_wr_en_WB_ME == 1)) begin
			stall = 1;
		end
		else begin
			stall = 0;
		end

		// execute
		//Combinatorial logic to generate a control signal for jump / taken branches, and calculate target PC	
		pc_plus4 = pc_EX;
		if ((ir_EX[31:26] == SPECIAL) && (ir_EX[5:0] == JR)) begin
			br_target = alu_a;
			br_taken = 1;
		end
		else if (ir_EX[31:26] == J) begin
			br_target = { pc_plus4[31:28], ir_EX[25:0], 2'b00}; //concatinate with PC region
			br_taken = 1;
		end
		else if (((ir_EX[31:26] == BEQ) && (alu_compare == 1)) ||
			((ir_EX[31:26] == BNE) && (alu_compare == 0))) begin
			br_target = pc_plus4 + { {14{ir_EX[15]}}, ir_EX[15:0], 2'b00 };  //sign extend and add to PC
			br_taken = 1;
		end
		else begin
			br_target = 'x;
			br_taken = 0;
		end

		// Check for jump and squash next two instructions
		if (br_taken) begin
			clear = 1;
			//ir_ME = 32'b0;
			//ir_EX = 32'b0;
			//reg_wr_en_WB_ME = 0;
			//reg_wr_en_WB_EX = 0;
		end
		else begin 
			clear = 0;
		end

		// memory
		if (ir_ME[31:26] == SW) begin
			st_en = 1; // to do stores
		end 
		else begin
			st_en = 0; 
		end

		// writeback
		reg_wr_en = reg_wr_en_WB_WB;
		reg_wr_num = reg_wr_num_WB_WB;	

		if (ir_WB[31:26] == LW) begin
			reg_wr_data = data_in;
		end
		else begin
			reg_wr_data = alu_out_WB;
		end
	end
endmodule
