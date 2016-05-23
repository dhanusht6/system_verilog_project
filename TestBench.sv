`include "CachePackage.pkg"
`include "testpr.sv"
import CachePackage::*;

module TestBench();
bit clock,reset;
MainBus Bus();
ProcAndCache PAC();

MEM M(Bus.MEM,clock);
CACHE C(PAC.CACHE,clock, Bus.CACHE, reset);
Processor P(PAC.PROC,clock);
initial 
begin
clock=0;
Bus.Snoop.Shared=1;
forever #5ns clock=~clock;
end
endmodule

module MEM(MainBus.MEM Bus,input clock);
bit [BLOCKBYTES-1:0] [7:0] memory [2**(INDEXBITS+TAGBITS-1):0];
initial
begin
integer datafile;
integer scanfile;
	datafile=$fopen("MEM.txt","r");
		for(int i=0;i<=2**(INDEXBITS+TAGBITS-1);i=i+1)
			scanfile=$fscanf(datafile,"%h",memory[i]);
end

always@(posedge clock)
begin
if(Bus.READ)
	Bus.DataIn=memory[{Bus.address.INDEX,Bus.address.TAG}];
else if(Bus.WRITE)
	memory[{Bus.address.INDEX,Bus.address.TAG}]=Bus.DataOut;
end
endmodule

module Processor(ProcAndCache.PROC PB,input clock);
integer datafile;
integer scanfile;
bit [25:0] captureddata;
initial
	datafile=$fopen("Proc.txt","r");
always@(posedge clock)
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

