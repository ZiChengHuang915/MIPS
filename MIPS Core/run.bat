iverilog -g2005-sv -s tb_SimpleAdd -o tb_SimpleAdd.vvp p2_tb.sv memory.sv regfile.sv mips.sv
vvp -n tb_SimpleAdd.vvp
gtkwave dump.vcd