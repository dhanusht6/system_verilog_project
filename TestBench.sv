`include "CachePackage.pkg"
`include "testpr.sv"
import CachePackage::*;

module TestBench();
bit clock,reset;
int StallCount;
MainBus Bus(.clock);
ProcAndCache PAC(.clock,.reset);

MEM M(Bus.MEM);
CACHE C(PAC.CACHE,Bus.CACHE);
Processor P(PAC.PROC);
initial 
begin
Bus.Snoop.Shared=0;
Bus.Snoop.BusUpd=0;
Bus.Snoop.BusRd=0;
Bus.Snoop.address={0,'0,'0};
Bus.Snoop.Data=32'h0;
$monitor("C.CACHEMEM[0].BLOCKS[3].DATA=%h",C.CACHEMEM[0].BLOCKS[3].DATA);
end
initial
begin
clock=0;
forever #5ns clock=~clock;
end
always@(PAC.STALL)
	if(PAC.STALL)
		begin
		StallCount=StallCount+1;
			if(StallCount==41)
				begin
				Bus.Snoop.address={8'd5,6'd1,2'd00};
				Bus.Snoop.Data=32'habcdef12;
				Bus.Snoop.BusUpd=1;
				@(posedge clock) Bus.Snoop.BusUpd=0;
				end
		end
		
always @(posedge Bus.Broadcast.BusRd)
	if(StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24)
		begin
		Bus.Snoop.Shared=1;
		@(negedge Bus.Broadcast.BusRd) Bus.Snoop.Shared=0;
		end

		
	
endmodule

module MEM(MainBus.MEM Bus);
bit [BLOCKBYTES-1:0] [7:0] memory [2**(INDEXBITS+TAGBITS-1):0];
initial
begin
integer datafile;
integer scanfile;
	datafile=$fopen("MEM.txt","r");
		for(int i=0;i<=2**(INDEXBITS+TAGBITS-1);i=i+1)
			scanfile=$fscanf(datafile,"%h",memory[i]);
end

always@(posedge Bus.clock)
begin
if(Bus.READ)
	Bus.DataIn=memory[{Bus.address.INDEX,Bus.address.TAG}];
else if(Bus.WRITE)
	memory[{Bus.address.INDEX,Bus.address.TAG}]=Bus.DataOut;
end
endmodule

module Processor(ProcAndCache.PROC PB);
integer datafile;
integer scanfile;
bit [25:0] captureddata;
initial
	datafile=$fopen("Proc.txt","r");
always@(negedge PB.clock)
begin
	if(PB.STALL!=1)
	scanfile=$fscanf(datafile,"%b",captureddata);
	PB.READ=captureddata[25];
	PB.WRITE=captureddata[24];
	PB.address.INDEX=captureddata[23:16];
	PB.address.TAG=captureddata[15:10];
	PB.address.BYTESELECT=captureddata[9:8];
	PB.DataIn=captureddata[7:0];
end
endmodule

