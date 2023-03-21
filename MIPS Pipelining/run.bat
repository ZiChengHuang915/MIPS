>output.txt (
iverilog -g2005-sv -s tb_SumArray_debug a3_tb.sv memory.sv regfile.sv mips.sv
vvp -n a.out
rem gtkwave dump.vcd 
)