module adder (
    input a,
    input b,
    input cin,
    output cout,
    output sum
);

    assign {cout, sum} = a+b+cin;
    
endmodule


module testbench;

    /* Make a regular pulsing clock. */
    reg clk = 0;
    always #5 clk = !clk;

    /* Create an instance of a full adder*/
    reg a, b, cin;
    wire cout, sum;
    adder a1(a, b, cin, cout, sum);

    initial begin
        @(posedge clk) {a,b,cin} <= 3'b000;
        @(posedge clk) {a,b,cin} <= 3'b010;
        @(posedge clk) {a,b,cin} <= 3'b100;
        @(posedge clk) {a,b,cin} <= 3'b110;
        @(posedge clk) {a,b,cin} <= 3'b000;
        @(posedge clk) {a,b,cin} <= 3'b001;
        @(posedge clk) {a,b,cin} <= 3'b011;
        $finish;
    end

    initial begin
        $monitor("At time %t, a(%0d) + b(%0d) + cin(%0d) = cout(%0d) + sum(%0d)",$time, a, b, cin, cout, sum);
        $dumpvars(0, testbench);
    end
        
endmodule
