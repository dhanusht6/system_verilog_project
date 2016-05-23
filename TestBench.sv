`include "CachePackage.pkg"
`include "testpr.sv"
import CachePackage::*;

module TestBench();
bit clock,reset;
MainBus Bus();
ProcAndCache PAC();

MEM M(Bus.MEM);
CACHE C(PAC.CACHE,clock, Bus.CACHE, reset);
Processor P(PAC.PROC);
//assign Bus.MEM.Data=32'habcd;
initial 
begin
clock=0;
Bus.Shared=1;
forever #5ns clock=~clock;
end
endmodule

module MEM(MainBus.MEM Bus);
initial
	begin
	Bus.DataIn=32'habcdef12;
	$display("Bus.DataIn=%h",Bus.DataIn);
	end
endmodule

module Processor(ProcAndCache.PROC PB);
initial
begin
PB.READ=1;
PB.WRITE=0;
PB.address.INDEX='0;
PB.address.TAG=14'd2;
PB.address.BYTESELECT=1;
end
endmodule

