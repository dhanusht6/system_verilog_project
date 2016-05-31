import CachePackage::*;

module TopTB();

logic [BLOCKBYTES-1:0] [7:0] memory [2**(INDEXBITS+TAGBITS)-1:0];
logic [24:0] command [0:40];
int i,j;
initial
	begin
	$readmemh("MEM.txt",memory);
	$readmemh("Proc.txt",command);
	end

TopHDL tophdl();
TopHVL tophvl(tophdl.PAC , tophdl.Bus);

int StallCount;
logic SHARED;
logic [ADDRESSWIDTH-1:0] ADDRESS='z;
logic [DATABUSWIDTH-1:0] DATA='z;
logic BusUPD='z;
logic BusRD='z;
assign tophdl.Bus.BusRd=BusRD;
assign tophdl.Bus.BusUpd=BusUPD;
assign tophdl.Bus.Data=DATA;
assign tophdl.Bus.Address=ADDRESS;
assign tophdl.Bus.Shared=SHARED;

initial
	begin
	$monitor("C.CACHEMEM[2].BLOCKS[3].STATE=%p  at %t",tophdl.C.CACHEMEM[5].BLOCKS[1].STATE,$time);
	end

always@(tophdl.PAC.STALL)
	if(tophdl.PAC.STALL)
		StallCount=StallCount+1;

always@(negedge tophdl.PAC.clock)
	if(~tophdl.PAC.STALL && ~tophdl.PAC.reset)
		begin
		tophdl.PAC.SendCommand(command[i]);
		i=i+1;
		end
always@(posedge tophdl.PAC.clock)
	if(tophdl.Bus.READrWRITE===1)
		tophdl.Bus.ReadfromMem(memory[{tophdl.Bus.Address}]);
always@(posedge tophdl.PAC.STALL)
	tophdl.PAC.ReleaseBus();

always @(negedge tophdl.PAC.clock)
	begin
	if((StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24) && tophdl.Bus.BusRd)
		SHARED<=1; 
	else 
		SHARED<='z;
	end
endmodule: TopTB

/*logic SHARED;
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
	$monitor("C.CACHEMEM[2].BLOCKS[3].STATE=%p  at %t",C.CACHEMEM[5].BLOCKS[1].STATE,$time);
	end



always@(PAC.STALL)
	if(PAC.STALL)
		begin
		StallCount=StallCount+1;
			//if(StallCount==41)
				//begin
				//Bus.Address={8'd5,6'd1,2'd00};
				//ADDRESS=16'b0000010100000100; DATA=32'habcdef12; BusUPD=1;
				//end
		end	*/
//always @(posedge clock) if(StallCount==41) begin  ADDRESS='z; DATA='z; BusUPD='z; end
			/*if(StallCount==42)
				begin
				ADDRESS=16'b0000010000000000;
				BusRD=1;
				@(posedge clock) ADDRESS='z;
				BusRD='z;
				end*/
		
/*always @(negedge clock)
	begin
	if((StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24) && Bus.BusRd)
		SHARED<=1; 
	else 
		SHARED<='z;
	end*/

//`ifdef debug
/*property RESET;
@(posedge clock)
	(reset) |=> (for(int i=SETS-1; i>=0; i=i-1)
					{C.CACHEMEM[i].BLOCKS[4].VALIDBIT,C.CACHEMEM[i].BLOCKS[3].VALIDBIT,C.CACHEMEM[i].BLOCKS[2].VALIDBIT,C.CACHEMEM[i].BLOCKS[1].VALIDBIT}='0;
					C.CACHEMEM[i].LRUREG='0;
					end)
endproperty
//`endif	
*/	
	

/*module MEM(MainBus.MEM Bus);



always@(posedge Bus.clock)
begin
if(Bus.READ)
	Bus.DataIn=memory[{Bus.address.INDEX,Bus.address.TAG}];
else if(Bus.WRITE)
	memory[{Bus.address.INDEX,Bus.address.TAG}]=Bus.DataOut;
end
endmodule*/

/*module Processor(ProcAndCache.PROC PB);
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
endmodule*/
