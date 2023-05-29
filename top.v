/* Copyright (c) 2018 Upi Tamminen, All rights reserved.
 * See the LICENSE file for more information */

module top(
    input           clk,
    output  [7:0]   LED,
    input  RX,
	output TX,
    input   uart_rx,
    output  uart_tx,
     inout  [7:0]   via_port_a,
     inout  [7:0]   via_port_b,
    input   [7:0]   via_porta_in,
    input   [7:0]   via_portb_in,
    input   [0:0]   SW,
    output  tm_cs,
    output tm_clk,
    inout  tm_dio
);

wire RX;
wire TX;
wire clk;
wire enable = SW[0];
reg reset = 1'b1;
reg [7:0] reset_count = 1'b0;
wire    [7:0]    via_port_a ;
wire    [7:0]    via_port_b ;
wire    [7:0]    via_porta_in ;
wire    [7:0]    via_portb_in ;









cpu_core #(.ROM_FILE("rom.list")) cpu_core(
    .clk (clk),
    .reset (reset),
    .RX(RX),
    .TX(TX),
    .uart_rx,
    .uart_tx,
    .gpio1 (LED),
    .via_porta_in(via_porta_in),
    .via_portb_in (via_portb_in),
    .via_port_a(via_port_a),
    .via_port_b(via_port_b),
    .tm_cs,
    .tm_clk,
    .tm_dio   
);


always @(posedge clk) begin
    if (reset == 1'b1) begin
        reset_count = reset_count + 1'b1;
        if (reset_count == 8'hff) begin
            reset <= 1'b0;
        end
    end
end

endmodule
