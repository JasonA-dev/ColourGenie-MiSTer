//-------------------------------------------------------------------------------------------------
// EACA EG2000 Colour Genie implementation for ZX-Uno by Kyp
// https://github.com/Kyp069/eg2000
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
// UM6845R chip module implementation by Sorgelig
// https://github.com/sorgelig/Amstrad_MiST
//-------------------------------------------------------------------------------------------------
// AY chip module implementation by Jotego
// https://github.com/jotego/jt49
//-------------------------------------------------------------------------------------------------
module eg2000
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire       led,

	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	input  wire[ 1:0] ps2,

	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.i      (clock50),
	.o      (clock  )
);

//-------------------------------------------------------------------------------------------------

reg[7:0] rs;
wire power = rs[7];
always @(posedge clock) if(!power) rs <= rs+1'd1;

//-------------------------------------------------------------------------------------------------

reg[1:0] bc;
always @(posedge clock) bc <= bc+1'd1;

BUFG Bufg (.I(bc[1]), .O(clockmb));

multiboot Multiboot
(
	.clock  (clockmb),
	.reset  (boot   )
);

//-------------------------------------------------------------------------------------------------

wire tape = ~ear;

wire[3:0] color;

glue Glue
(
	.clock  (clock  ),
	.power  (power  ),
	.boot   (boot   ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.pixel  (pixel  ),
	.color  (color  ),
	.tape   (tape   ),
	.sound  (sound  ),
	.ps2    (ps2    ),
	.ramWe  (ramWe  ),
	.ramDQ  (ramDQ  ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

reg[8:0] palette[15:0];
initial begin
	palette[15] = 9'b111_111_111; // FF FF FF // 16 // white
	palette[14] = 9'b100_001_111; // 98 20 FF //  8 // magenta
	palette[13] = 9'b000_110_100; // 1F C4 8C // 14 // turquise
	palette[12] = 9'b100_100_100; // 8C 8C 8C // 13 // grey
	palette[11] = 9'b100_011_111; // 8A 67 FF // 12 // violet
	palette[10] = 9'b110_010_111; // C7 4E FF // 15 // pink
	palette[ 9] = 9'b100_110_111; // BC DF FF //  9 // light blue
	palette[ 8] = 9'b001_010_111; // 2F 53 FF //  8 // blue
	palette[ 7] = 9'b111_111_001; // EA FF 27 // 11 // yellow/green
	palette[ 6] = 9'b111_011_001; // EB 6F 2B //  5 // orange
	palette[ 5] = 9'b101_111_010; // AB FF 4A //  2 // green
	palette[ 4] = 9'b111_111_001; // FF F2 3D //  4 // yellow
	palette[ 3] = 9'b110_110_110; // EA EA EA //  1 // light grey
	palette[ 2] = 9'b110_001_010; // CB 26 5E //  3 // red
	palette[ 1] = 9'b011_111_111; // 7C FF EA //  7 // cyan
	palette[ 0] = 9'b010_010_010; // 5E 5E 5E // 10 // dark grey
end

assign stdn = 2'b01; // PAL
assign sync = { 1'b1, ~(hsync^vsync) };
assign rgb = pixel ? palette[color] : 1'd0;

//-------------------------------------------------------------------------------------------------

assign audio = {2{sound}};

//-------------------------------------------------------------------------------------------------

assign led = tape;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
