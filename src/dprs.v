//-------------------------------------------------------------------------------------------------
module dprs
//-------------------------------------------------------------------------------------------------
#
(
	parameter KB = 0,
	parameter DW = 8
)
(
	input  wire                      clock,
	input  wire                      ce1,
	output reg [             DW-1:0] q1,
	input  wire[$clog2(KB*1024)-1:0] a1,
	input  wire                      ce2,
	input  wire                      we2,
	input  wire[             DW-1:0] d2,
	input  wire[$clog2(KB*1024)-1:0] a2
);
//-------------------------------------------------------------------------------------------------

reg[DW-1:0] dpr[(KB*1024)-1:0];

always @(posedge clock) if(ce1) q1 <= dpr[a1];
always @(posedge clock) if(ce2)  if(!we2) dpr[a2] <= d2;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
