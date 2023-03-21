// this is a mips module that can only execute the addiu instruction
module mips(
	// port list
	input clk, reset,
	output [31:0] instr_addr,
	input [31:0] instr_in,
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
	assign instr_addr = pc;
	logic [31:0] ir;

	// ID signals
	logic [4:0] reg_rd_num0, reg_rd_num1;
	wire [31:0] reg_rd_data0, reg_rd_data1;
	assign reg_rd_num0 = ir[25:21]; // rs
	assign reg_rd_num1 = ir[20:16]; // rt
	logic [5:0] opcode;
	assign opcode = ir[31:26];
	logic [5:0] opcode_low;
	assign opcode_low = ir[5:0];

	// EX signals
	logic [31:0] alu_a, alu_b, sign_ext_imm;
	logic [31:0] alu_out;

	// ME signals
	logic st_en;
	assign data_out = alu_b;
	assign data_rd_wr = ~st_en;
	assign data_addr = alu_out;

	// WB signals
	logic [4:0] reg_wr_num;
	logic [31:0] reg_wr_data;
	logic reg_wr_en;

	enum { init, fetch, id, ex, me, wb } state;

	// register file
	regfile #(.sp_init(sp_init), .ra_init(ra_init)) regs(
		.wr_num(reg_wr_num), .wr_data(reg_wr_data), .wr_en(reg_wr_en),
		.rd0_num(reg_rd_num0), .rd0_data(reg_rd_data0),
		.rd1_num(reg_rd_num1), .rd1_data(reg_rd_data1),
		.clk(clk), .reset(reset));


	// ALU with registered output
	always @(posedge clk) begin
		if (state == ex) begin
			case(opcode)
				6'b001001: begin //addiu
					alu_out <= alu_a + sign_ext_imm;
				end
				6'b101011: begin //sw
					alu_out <= alu_a + sign_ext_imm;
				end
				6'b000000: begin
					case(opcode_low)
						6'b100001: begin //addu
							alu_out <= alu_a + alu_b;
						end
						6'b001000: begin //jr
							pc <= reg_rd_data0;
						end
						6'b000000: begin //nop
						end
						default: begin 
							alu_out <= alu_a + alu_b;
						end
					endcase
				end
				6'b100011: begin //lw
					alu_out <= alu_a + sign_ext_imm;
				end
				6'b100100: begin //li(lbu)
					alu_out <= alu_a + sign_ext_imm;
				end
				6'b111010: begin //move(swc2)
					alu_out <= alu_a + sign_ext_imm;
				end
				default: begin
					alu_out <= alu_a + alu_b;
				end
			endcase
		end
	end


	// State transitions, registers
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			pc <= pc_init;
			state <= init;
		end
		else
			case(state)
				init: begin
					// this state is needed since we have to wait for
					// memory to produce the first instruction after reset
					state <= fetch;
				end
				fetch: begin
					ir <= instr_in;
					pc <= pc + 4;
					state <= id;
				end
				id: begin
					case(opcode)
						6'b001001: begin //addiu
							alu_a <= reg_rd_data0;
							sign_ext_imm <= {{16{ir[15]}},ir[15:0]};
						end
						6'b101011: begin //sw
							alu_a <= reg_rd_data0;
							sign_ext_imm <= {{16{ir[15]}},ir[15:0]};
							alu_b <= reg_rd_data1;
						end
						6'b000000: begin
							case(opcode_low)
								6'b100001: begin //addu
									alu_a <= reg_rd_data0;
									alu_b <= reg_rd_data1;
								end
								6'b000000: begin //nop
								end
								default: begin
									alu_a <= reg_rd_data0;
									alu_b <= reg_rd_data1;
								end
							endcase
						end
						6'b100011: begin //lw
							alu_a <= reg_rd_data0;
							sign_ext_imm <= {{16{ir[15]}},ir[15:0]};
						end
						6'b100100: begin //li(lbu)
							alu_a <= reg_rd_data0;
							sign_ext_imm <= {{16{ir[15]}},ir[15:0]};
						end
						6'b111010: begin //move(swc2)
							alu_a <= reg_rd_data0;
							sign_ext_imm <= {{16{ir[15]}},ir[15:0]};
							alu_b <= reg_rd_data1;
						end
						default: begin
							alu_a <= reg_rd_data0;
							alu_b <= reg_rd_data1;
						end
					endcase
					state <= ex;
				end
				ex: begin
					state <= me;
				end
				me: begin
					state <= wb;
				end
				wb: begin
					state <= fetch;
				end
				default: begin
					state <= fetch;
				end
			endcase
	end
	
	// Control signals
	always @(*) begin
		st_en = 0;
		reg_wr_en = 0;
		reg_wr_num = 'x;
		reg_wr_data = 'x;
		case (state)
			me: begin
				// st_en = 1 // to do stores

				case(opcode)
					6'b001001: begin //addiu
						st_en = 0;
					end
					6'b101011: begin //sw
						st_en = 1;
					end
					6'b000000: begin
						case(opcode_low)
							6'b100001: begin //addu
								st_en = 0;
							end
							6'b000000: begin //nop
							end
							default: begin
								st_en = 0;
							end
						endcase
					end
					6'b100011: begin //lw
						st_en = 0;
					end
					6'b100100: begin //li(lbu)
						st_en = 0;
					end
					6'b111010: begin //move(swc2)
						st_en = 1;
					end
					default: begin
						st_en = 0;
					end
				endcase
			end
			wb: begin
				case(opcode)
					6'b001001: begin //addiu
						reg_wr_en = 1;
						reg_wr_num = ir[20:16];
						reg_wr_data = alu_out;
					end
					6'b101011: begin //sw
						reg_wr_en = 0;
					end
					6'b000000: begin
						case(opcode_low)
							6'b100001: begin //addu
								reg_wr_en = 1;
								reg_wr_num = ir[15:11];
								reg_wr_data = alu_out;
							end
							6'b000000: begin //nop
							end
							default: begin
								reg_wr_en = 0;
							end
						endcase
					end
					6'b100011: begin //lw
						reg_wr_en = 1;
						reg_wr_num = ir[20:16];
						reg_wr_data = data_in;
					end
					6'b100100: begin //li(lbu)
						reg_wr_en = 1;
						reg_wr_num = ir[20:16];
						reg_wr_data = data_in;
					end
					6'b111010: begin //move(swc2)
						reg_wr_en = 0;
					end
					default: begin
						reg_wr_en = 0;
					end
				endcase
			end
		endcase
	end
endmodule
