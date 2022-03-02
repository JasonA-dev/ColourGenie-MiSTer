//-------------------------------------------------------------------------------------------------
module glue
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	//input  wire 	  reset,	
	input  wire       power,

	output wire       hsync,
	output wire       vsync,
`ifdef USE_CE_PIX
	output wire       ce_pix,
`endif	

`ifdef USE_BLANK
	output wire       hblank,
	output wire       vblank,
`endif	

	output wire       pixel,
	output wire[ 3:0] color,
	output wire			crtcDe,

	input  wire       tape,
`ifdef USE_DAC
	output wire       sound,
`else
   output wire [15:0] audio_l,
   output wire [15:0] audio_r,
`endif
`ifdef MISTER
        input  wire[10:0]ps2_key,               // [7:0] - scancode,
`else
        input  wire[1:0] ps2,
`endif
	output wire       led,
`ifdef ZX1
	output wire       boot,
	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA,
`elsif USE_BRAM
	output wire       filler,
`elsif USE_SDRAM
	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBA,
	output wire[12:0] ramA,
`endif

input wire tape_play,

    input            dn_clk,
    input            dn_go,
    input            dn_wr,
    input [24:0]     dn_addr,
    input [7:0]      dn_data
    
);
//-------------------------------------------------------------------------------------------------

always @(negedge clock) ce <= ce+1'd1;



`ifdef VERILATOR
reg[3:0] ce;

assign ce_pix =pe8M8;
wire pe8M8 = ce[0] ;
wire ne8M8 = ~ce[0];

wire ne4M4 = ~ce[0] & ~ce[1] ;

wire pe2M2 = ~ce[0] & ~ce[1] & ce[2];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];


`else
reg[4:0] ce;
assign ce_pix = pe8M8;
wire pe8M8 = ~ce[0] &  ce[1];
wire ne8M8 = ~ce[0] & ~ce[1];

wire ne4M4 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe2M2 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] &  ce[4];
`endif
//-------------------------------------------------------------------------------------------------

wire ioF8 = !(!iorq && a[7:0] == 8'hF8); // psg addr
wire ioF9 = !(!iorq && a[7:0] == 8'hF9); // psg data

wire ioFA = !(!iorq && a[7:0] == 8'hFA); // crtc addr
wire ioFB = !(!iorq && a[7:0] == 8'hFB); // crtc data

wire ioFF = !(!iorq && a[7:0] == 8'hFF);

//-------------------------------------------------------------------------------------------------

wire reset = power & kreset;

assign led = reset;
wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

wire rfsh, mreq, iorq, rd, wr;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (pe2M2  ),
	.cen    (ne2M2  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.m1     (m1     ),
	.nmi    (nmi    ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!ioFA || !ioFB);
wire crtcRs = a[0];
wire crtcRw = wr;
wire m1;

assign ior = rd | iorq | (~m1);
assign iow = wr | iorq;


wire[ 7:0] crtcQ;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

wire cursor;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (pe1M1  ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (q      ),
	.DO     (crtcQ  ),
	.VSYNC  (vsync  ),
	.HSYNC  (hsync  ),
`ifdef USE_BLANK
	.HBLANK (hblank ),
	.VBLANK (vblank ),
`endif	

	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

reg[1:0] cur;
always @(posedge clock) if(pe1M1) cur <= { cur[0], cursor };

//-------------------------------------------------------------------------------------------------

wire bdir = (!wr && !ioF8) || (!wr && !ioF9);
wire bc1  = (!wr && !ioF8) || (!rd && !ioF9);

wire[7:0] psgA;
wire[7:0] psgB;
wire[7:0] psgC;
wire[7:0] psgQ;

jt49_bus Psg
(
	.clk    (clock  ),
	.clk_en (pe2M2  ),
	.rst_n  (reset  ),
	.bdir   (bdir   ),
	.bc1    (bc1    ),
	.din    (q      ),
	.dout   (psgQ   ),
	.A      (psgA   ),
	.B      (psgB   ),
	.C      (psgC   ),
	.sel    (1'b0   )
);


//-------------------------------------------------------------------------------------------------


wire [7:0] tapesnd = (tapebits[1:0] == 2'b01) ? 8'b01000000 : (tapebits[1:0] == 2'b01 || tapebits[1:0] == 2'b01) ? 8'b00100000 : 8'b00000000;
	
wire[9:0] dacD = { 2'b00, psgA } + { 2'b00, psgB } + { 2'b00, psgC } + {2'b00,tapesnd};

`ifdef USE_DAC
dac #(.MSBI(9)) Dac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (dacD   ),
	.q      (sound  )
);
`else
 assign audio_l = {dacD,6'b0};
 assign audio_r = audio_l;
`endif

//-------------------------------------------------------------------------------------------------

wire[7:0] keyQ;
wire[7:0] keyA = a[7:0];
wire nmi,boot,kreset;


`ifdef ZX1
keyboard Keyboard
`else
keyboard #(.BOOT(8'h0A), .RESET(8'h78)) Keyboard //Boot(F8) - Reset(F11)
`endif
(
	.clock  (clock  ),
	.ce     (pe8M8  ),
`ifdef MISTER
	.ps2_key    (ps2_key    ),
`else
	.ps2    (ps2    ),
`endif
	.nmi    (nmi    ),
	.boot   (boot   ),
	.reset  (kreset ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

reg mode, c, b;
always @(posedge clock) if(pe2M2) if(!ioFF && !wr) { mode, c, b } <= q[5:3];

//-------------------------------------------------------------------------------------------------

wire[13:0] vma = crtcMa;
wire[ 2:0] vra = crtcRa[2:0];

wire[ 7:0] memQ;
wire ven;

memory Memory
(
	.clock  (clock  ),
	.hsync  (hsync  ),
	.vcep   (pe8M8  ),
	.vcen   (ne8M8  ),
	.hrce   (ne4M4  ),
	.vma    (vma    ),
	.vra    (vra    ),
	.b      (b      ),
	.c      (c      ),
	.mode   (mode   ),
	.ven    (ven    ),
	.color  (color  ),
	.ce     (pe2M2  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.keyQ   (keyQ   ),
`ifdef ZX1 
	.ramWe  (ramWe  ),
	.ramDQ  (ramDQ  ),
	.ramA   (ramA   )
`elsif USE_BRAM 
   .filler (       )	
`elsif USE_SDRAM
	.ramCk  (ramCk  ),
	.ramCe  (ramCe  ),
	.ramCs  (ramCs  ),
	.ramWe  (ramWe  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBA  (ramBA  ),
	.ramA   (ramA   )
`endif
);

assign pixel = (ven || cur[1]) && crtcDe;

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq ? memQ
	: !ioF9 ? psgQ
	: !ioFB ? crtcQ
	: !ioFF ? { tapelatch|tape,3'b111,widemode, 1'b0, 1'b0, tape|tapebit_val }//tape|tapebit_val }
	: 8'hFF;


//-------------------------------------------------------------------------------------------------

reg [23:0]       io_ram_addr;
    
reg [2:0]        tapebits;		// motor on/off, plus two bits for output signal level
`define tapemotor tapebits[2]
    
reg              taperead;		// only when motor is on, 0 = write, 1 = read
reg [11:0]       tape_cyccnt;		// CPU cycle counter for cassette carrier signal
//signal tape_leadin	: std_logic_vector(7 downto 0);		-- additional 128 bits for sync-up, just in case
integer          tape_bitptr;
    
reg              tapebit_val;		// represents bit being sent from cassette file
reg              tapelatch;		// represents input bit from cassette (after signal conditioning)
//signal tapelatch_resetcnt	: std_logic_vector(3 downto 0) $ "0000";	-- when port is read, reset value - but only after a few cycles
    
    wire [15:0]      cpua;
    wire [7:0]       cpudo;
    wire [7:0]       cpudi;
    wire             cpuwr;
    wire             cpurd;
    wire             cpumreq;
    wire             cpuiorq;
    wire             cpum1;
    reg              cpuclk;
    reg              cpuclk_r;
    reg              clk_25ms;

    wire             ior;
    wire             iow;
    reg              widemode;

    wire [16:0]      ram_a_addr;
    wire [16:0]      ram_b_addr;
    wire [7:0]       ram_a_dout;
    wire [7:0]       ram_b_dout;

	 assign ram_a_addr = dn_wr ? dn_addr[16:0] : io_ram_addr[16:0];

ram #(.KB(128)) taperam
(
        .clock  (clock      ),
        .ce     (1'b1       ),
        .we     (~(dn_wr&dn_go)     ),
        .d      (dn_data    ),
        .q      (ram_a_dout ),
        .a      (ram_a_addr )
);
	 
    always @(posedge clock)
        if ((dn_go == 1'b1 ) | reset == 1'b1)
        begin
            io_ram_addr <= 24'h000000;		
            
            tapebits <= 3'b000;
            tape_cyccnt <= 12'h000;
            //		tape_leadin <= x"00";
            tape_bitptr <= 7;
            tapelatch <= 1'b0;
        end
        else
            //		tapelatch_resetcnt <="0000";
            
            
            begin
                cpuclk_r <= pe2M2;
                
                if ((cpuclk_r != pe2M2) & pe2M2 == 1'b1)
                begin
                    
                   
                    
                    //----  Cassette data I/O (covers port $FF) ------
                    //
                    // Added in order to support regular/original BIOS ROMs.
                    // Synthesizes the cassette data from .CAS files; doesn't yet accept audio files as input.
                    // Since loading a 13KB fie takes several minutes at regular speed, this version automatically
                    // sets CPU to top speed on input.
                    //
						  
						  if (tape_play && taperead==1'b0)
						  begin
						          io_ram_addr <= 24'h000000;
                            tape_bitptr <= 7;
                            taperead <= 1'b1;
                            tape_cyccnt <= 12'h000;

						  end
						  
                    if (iow == 1'b0 & a[7:0] == 8'hff)		// write to tape port
                    begin
                        
                        if ((`tapemotor == 1'b0) & (q[2] == 1'b1))		// if start motor, then reset pointer
                        begin
                            io_ram_addr <= 24'h000000;
                            tape_bitptr <= 7;
                            taperead <= 1'b0;
                        end
                        
                        else if ((`tapemotor == 1'b1) & (q[2] == 1'b0))		// if stop motor, then reset tape read status
                            taperead <= 1'b0;
                        
                        tapebits <= q[2:0];
                        widemode <= q[3];
                        tapelatch <= 1'b0;		// tapelatch is set by cassette data bit, and only reset by write to port $FF
                    end
                    
                    if (ior == 1'b0 & a[7:0] == 8'hff)
                    begin
                        if (`tapemotor == 1'b1 & taperead == 1'b0)		// reading the port while motor is on implies tape playback
                        begin
                            taperead <= 1'b1;
                            tape_cyccnt <= 12'h000;
                        end
                    end
                    //						tape_leadin <= x"00";
                    
                    if (taperead == 1'b1)
                    begin
                        tape_cyccnt <= tape_cyccnt + 1;		// count in *CPU* cycles, regardless of clock speed
                        
                        if (tape_cyccnt < 12'h200)		// fixed-timing sync clock bit - hold the signal high for a bit
                            tapelatch <= 1'b1;		// DO NOT reset the latch until port is read
                        // uncomment the following line when debugging cassette input:
                          tapebits[1:0] <= 2'b01;			//-- ** make a noise  ** remove when working

                        if (tape_cyccnt == 12'h6ff)		// after 1791 cycles (~1ms @ normal clk), actual data bit is written only if it's a '1'
                        begin
                            // timing reverse-engineered from Level II ROM cassette write routine
                            
                            tapebit_val <= ram_a_dout[tape_bitptr];
                            
                            // uncomment the following lines when debugging cassette input:
                            if (ram_a_dout[tape_bitptr] == 1'b1)		// ** make a noise
                            	tapebits[1:0] <= 2'b01;				// ** remove when working
                            
                            
                            if (tape_bitptr == 0)
                            begin
                                io_ram_addr <= io_ram_addr + 1;
                                tape_bitptr <= 7;
                            end
                            else
                                tape_bitptr <= tape_bitptr - 1;
                        end
                        
                        if (tape_cyccnt > 12'h6ff & tape_cyccnt < 12'h8ff)
                        begin
                            
                            if (tapebit_val == 1'b1)		// if set, hold it for 200 cycles like a real tape
                                tapelatch <= 1'b1;		// DO NOT reset the latch if '0'
                        end
                        // uncomment the following line when debugging cassette input:
                        tapebits[1:0] <= 2'b01;			//-- ** make a noise  ** remove when working
                        
                        if (tape_cyccnt >= 12'he08)		// after 3582 cycles (~2ms), sync signal is written (and cycle reset)
                            tape_cyccnt <= 12'h000;
                    end
                end
            end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
