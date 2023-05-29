/* Copyright (c) 2018 Upi Tamminen, All rights reserved.
 * See the LICENSE file for more information */

/*
memory map:

RAM     0x0000  0
        0x03ff  1023

GPIO    0x0400  1024    (big area, gpio gets duplicated)
        0x07ff  2047
// 	// ACIA at page ...0xe00,0xe100....
---------
unused  0x0800  2048
        0xfbff  64511

ROM     0xfc00  64512
        0xffff  65535
*/

module cpu_core #(parameter ROM_FILE = "rom.list") (
    input           clk,
    input           reset,
    input           uart_rx,
    output          uart_tx,
    inout  [7:0]   via_port_a,
    inout  [7:0]   via_port_b,
    input   [7:0]  via_porta_in,
    input   [7:0]  via_portb_in,
    input           RX,
	output          TX,
    output  tm_cs,
    output tm_clk,
    inout  tm_dio, 
    output  [7:0]   gpio1
   
);
wire RX;
wire TX;
wire [15:0] addr;
wire [7:0] cpu_do;
reg [7:0] cpu_di;
wire we;
 wire CPU_IRQ ;
//--------------------------------------------------------------------------------------------
   localparam 
        HIGH    = 1'b1,
        LOW     = 1'b0;

   reg tm_rw;
    wire dio_in, dio_out;
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(we&via_cs),
        .D_IN_0(via_portb_in[2]),
        .D_OUT_0(via_port_b[2])
    );
assign  tm_cs=   via_port_b[4];
assign  tm_clk=  via_port_b[3];

//assign  tm_dio=  via_port_b[2];
//---------------------------direccion i/o-----------------------------------------------------

  assign   uart_cs = (addr[15:2] ==   14'b11010000000000)	    ?	1'b1:   1'b0;	// d000  d000 uart 6551
  assign   via_cs =  (addr[15:2] ==   14'b10110000000000)		?	1'b1:   1'b0;	// B000  B0003 

// RAM
//
wire [7:0] ram_do;
wire cs_ram = (addr[15:10]   == 6'b000000) ? 1'b1 : 1'b0; // 0000-03ff
reg cs_ram_prev = 1'b0;
always @(posedge clk) cs_ram_prev <= cs_ram;
ram #(
    .ADDR_WIDTH(10),
    .DEPTH(1024))
ram(
    .clk (clk),
    .cs (cs_ram),
    .we (we && cs_ram),
    .addr (addr[9:0]),
    .data_in (cpu_do),
    .data_out (ram_do)
);
//
// 	// ACIA at page ...e0,e1....
//
wire [7:0] acia_do;
wire pe  = (addr[15:10]   == 6'b111000) ? 1'b1 : 1'b0; // e0,e1....
reg cs_acia_prev = 1'b0;
always @(posedge clk) cs_acia_prev <= pe;	
	  
	acia uacia(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(pe),				// chip select
		.we(we),			// write enable
		.rs(addr[0]),			// register select
		.rx(RX),				// serial receive
		.din(cpu_do),			// data bus input
		.dout(acia_do),			// data bus output
		.tx(TX),				// serial transmit
		.irq(CPU_IRQ)		     	// interrupt request
	);

//
   ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    ///
    /// 6522 VIA
    ///
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
  

      wire     ca1_in,
               ca2_out,
               ca2_in,
               cb1_out,
               cb1_in,
               cb2_out,
               cb2_in
               ;
  
    wire slow_clock;
  
    wire [7:0] data_in;
    wire [7:0] via_do ;
    wire [7:0] via_data_out;
    wire [7:0] porta_out;
    reg [7:0] portb_out;
    wire [7:0] porta_in;
    reg [7:0] portb_in;
	wire reset_via,irq;
    wire ce;

    reg [7:0] via2_do ;
    reg cs_via_prev = 1'b0;
    always @(posedge clk) cs_via_prev <= via_cs;	
    always @(posedge !we&via_cs) via2_do <= via_do;	
via6522 u0 (
               .data_out(via_do),          // cpu interface
               .data_in(cpu_do[7:0]),
               .addr(addr[3:0]),
               .ce(via_cs),
               .we(we),
               .strobe(via_cs),
               .irq(irq),

               .porta_out(via_port_a),
               .porta_in(via_porta_in),
               .portb_out(via_port_b),
               .portb_in(via_portb_in),

               .ca1_in(1'b1),
               .ca2_out(),
               .ca2_in(1'b1),
               .cb1_out(),
               .cb1_in(1'b1),
               .cb2_out(),
               .cb2_in(1'b1),

             

               .clk(clk),
               .reset(reset)

 );



////////////////////////// UART6551 ////////////////////////////////////////////////

wire [7:0]DATAIN,uart_DO;
wire [1:0]RS;
wire
CS,
RESET,
RX_CLK,

XTLI,
uart_cs,		
PH_2,
IRQn,
RW_N,
TXDATA_OUT,
RXDATA_IN,
rts,
cts,

DSR
;
reg cs_uart_prev = 1'b0;
always @(posedge clk) cs_uart_prev <= uart_cs;	
assign CS = !uart_cs;
assign RS ={addr[1] , addr[0]};
   ACIA ACIA_a
     (
      .RESET(!reset),         //: in     std_logic;
      .PHI2(clk ),          //: in     std_logic;
      .CS(!uart_cs),        //: in     std_logic;
      .RWN(!we&uart_cs),             //: in     std_logic;
      .RS(RS),                          //: in     std_logic_vector(1 downto 0);
      .DATAIN(cpu_do[7:0]),             //: in     std_logic_vector(7 downto 0);
      .DATAOUT(uart_DO),                //: out    std_logic_vector(7 downto 0);
      .XTLI(clk),                      //: in     std_logic;
      .RTSB(rts),           //: out    std_logic;
      .CTSB(1'b0),           //: in     std_logic;
      .DTRB(DTRB),              //: out    std_logic;
      .RXD(uart_rx),            //: in     std_logic;
      .TXD(uart_tx),            //: buffer std_logic;
      .IRQn(IRQn)               //: buffer std_logic
      );
//
// ROM
//
/*
wire [7:0] rom_do;
wire  cs_rom = (addr[15:12] == 4'hf) ? 1 : 0; //moodificacion mas rom f000
//wire cs_rom = (addr[15:10]   == 6'b111111) ? 1'b1 : 1'b0; // fc00-ffff
reg cs_rom_prev = 1'b0;
always @(posedge clk) cs_rom_prev <= cs_rom;
rom #(
    .ADDR_WIDTH(10),
    .DEPTH(1024),
    .ROM_FILE(ROM_FILE))
rom(
    .clk (clk),
    .cs (cs_rom),
    .addr (addr[9:0]),
    .data_in (cpu_do),
    .data_out (rom_do)
);
*/
reg cs_rom_prev = 1'b0;
always @(posedge clk) cs_rom_prev <= cs_rom;
	wire  cs_rom = (addr[15:12] == 4'hf) ? 1 : 0;
  //  wire cs_rom = (addr[15:10]   == 6'b111111) ? 1'b1 : 1'b0; // f00-ffff
// ROM @ pages f0,f1...
    reg [7:0] rom_mem[4095:0];
	reg [7:0] rom_do;
	 parameter ROMFILE = "rom.list";
	initial
        $readmemh(ROMFILE,rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[addr[11:0]];
//
// GPIO (leds)
//
wire cs_gpio1 = (addr[15:10] == 6'b000001) ? 1'b1 : 1'b0; // 0400-07ff
reg cs_gpio1_prev = 1'b0;
always @(posedge clk) cs_gpio1_prev <= cs_gpio1;
gpio gpio1_device(
    .clk (clk),
    .reset (reset),
    .cs (cs_gpio1),
    .data_in (cpu_do),
    .data_out (gpio1)
);

//
// CPU
//

cpu cpu(
    .clk (clk),
    .reset (reset),
    .AB (addr),
    .DI (cpu_di),
    .DO (cpu_do),
    .WE (we),
    .IRQ (CPU_IRQ),
    .NMI (1'b0),
    .RDY (1'b1)
);
// data mux
	reg [3:0] mux_sel;
	always @(posedge clk)
		mux_sel <= addr[15:12];
	always @(*)
		casez(mux_sel)
			4'h0: cpu_di = ram_do;
			4'h4: cpu_di = gpio1;
			4'he: cpu_di = acia_do ;
            4'hb: cpu_di =  via2_do;
            4'hd: cpu_di =  uart_DO ;
			4'hf: cpu_di = rom_do;
			default: cpu_di = rom_do;
		endcase
/* use cs values from previous clk for delayed read 
assign cpu_di =
      cs_ram_prev     ?         ram_do :  
      cs_gpio1_prev   ?         gpio1 :
      cs_acia_prev    ?         acia_do :
      cs_via_prev     ?         via2_do:
      cs_uart_prev    ?         uart_DO :
      cs_rom_prev     ?         rom_do :
   
    8'h00;
*/
endmodule






