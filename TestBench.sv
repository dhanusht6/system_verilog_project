`include "testpr.sv"
import CachePackage::*;

module TestBench();
bit clock,reset;
int StallCount;
MainBus Bus(.clock);
ProcAndCache PAC(.clock,.reset);

CACHE C(PAC.CACHE,Bus.CACHE);
Processor P(PAC.PROC);

logic SHARED='z;
assign Bus.Shared=SHARED;

initial
begin
reset=1;
repeat (2) @(negedge clock);
	reset=0;
end

/*initial
	begin
	$monitor("C.CACHEMEM[4].BLOCKS[3].STATE=%p",C.CACHEMEM[4].BLOCKS[3].STATE);
	end*/
initial
begin
clock=0;
forever #5ns clock=~clock;
end
always@(PAC.STALL)
	if(PAC.STALL)
		begin
		StallCount=StallCount+1;
			/*if(StallCount==41)
				begin
				Bus.Snoop.address={8'd5,6'd1,2'd00};
				Bus.Snoop.Data=32'habcdef12;
				Bus.Snoop.BusUpd=1;
				@(posedge clock) Bus.Snoop.BusUpd=0;
				end*/
		end
		
always @(posedge Bus.BusRd)
	if(StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24)
		begin
		SHARED=1;
		@(negedge Bus.BusRd) SHARED='z;
		end

		
	
endmodule

/*module MEM(MainBus.MEM Bus);



always@(posedge Bus.clock)
begin
if(Bus.READ)
	Bus.DataIn=memory[{Bus.address.INDEX,Bus.address.TAG}];
else if(Bus.WRITE)
	memory[{Bus.address.INDEX,Bus.address.TAG}]=Bus.DataOut;
end
endmodule*/

module Processor(ProcAndCache.PROC PB);
bit [24:0] command [0:40];
logic [7:0] DATA;
assign PB.Data=DATA;
int i=0;
int count=0;
initial
	begin
	$readmemh("Proc.txt",command);
	end
always@(negedge PB.clock)
begin
	count=count+1;
	if(PB.STALL!=1 && count>=4)
	begin
	PB.READrWRITE=command[i][24];
	PB.address.INDEX=command[i][23:16];
	PB.address.TAG=command[i][15:10];
	PB.address.BYTESELECT=command[i][9:8];
	DATA=command[i][7:0];
	i=i+1;
	repeat (1) @(negedge PB.clock);
		DATA='z;
	end
end
endmodule

