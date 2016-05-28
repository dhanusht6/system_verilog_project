`include "testpr.sv"

module TestBench();
bit clock,reset;
int StallCount;
MainBus Bus(.clock);
ProcAndCache PAC(.clock,.reset);

CACHE C(PAC.CACHE,Bus.CACHE);
Processor P(PAC.PROC);

logic SHARED='z;
logic [ADDRESSWIDTH-1:0] ADDRESS='z;
logic [DATABUSWIDTH-1:0] DATA='z;
logic BusUPD='z;
logic BusRD='z;
assign Bus.BusRd=BusRD;
assign Bus.BusUpd=BusUPD;
assign Bus.Data=DATA;
assign Bus.Address=ADDRESS;
assign Bus.Shared=SHARED;

initial
begin
reset=1;
@(negedge clock)
	reset=0;
end

initial
	begin
	$monitor("C.CACHEMEM[2].BLOCKS[3].STATE=%p",C.CACHEMEM[5].BLOCKS[3].STATE);
	end

//tbx clkgen
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
				//Bus.Address={8'd5,6'd1,2'd00};
				ADDRESS=16'b0000010100000100; DATA=32'habcdef12; BusUPD=1;
				end
		end	
always @(posedge clock) if(StallCount==41) begin  ADDRESS='z; DATA='z; BusUPD='z; end
			/*if(StallCount==42)
				begin
				ADDRESS=16'b0000010000000000;
				BusRD=1;
				@(posedge clock) ADDRESS='z;
				BusRD='z;
				end*/
		
always @(posedge Bus.BusRd)
	if(StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24)
		SHARED=1;
always @(negedge Bus.BusRd) 
	if(StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24)
		SHARED='z;

//`ifdef debug
/*property RESET;
@(posedge clock)
	(reset) |=> (for(int i=SETS-1; i>=0; i=i-1)
					{C.CACHEMEM[i].BLOCKS[4].VALIDBIT,C.CACHEMEM[i].BLOCKS[3].VALIDBIT,C.CACHEMEM[i].BLOCKS[2].VALIDBIT,C.CACHEMEM[i].BLOCKS[1].VALIDBIT}='0;
					C.CACHEMEM[i].LRUREG='0;
					end)
endproperty
//`endif	*/	
	
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
	if(PB.STALL!=1 && count>=3)
	begin
	PB.READrWRITE=command[i][24];
	PB.address.INDEX=command[i][23:16];
	PB.address.TAG=command[i][15:10];
	PB.address.BYTESELECT=command[i][9:8];
	DATA=command[i][7:0];
	i=i+1;
	@(negedge PB.clock)
		DATA='z;
	end
end
endmodule

