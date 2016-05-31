import CachePackage::*;

module TopTB();

logic [BLOCKBYTES-1:0] [7:0] memory [2**(INDEXBITS+TAGBITS)-1:0];
logic [24:0] command [0:40];
logic [24:0] randcommand;
int i,j;
logic updatesignaltested=0;
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


always@(tophdl.PAC.STALL)
	if(tophdl.PAC.STALL)
		StallCount=StallCount+1;

always@(negedge tophdl.PAC.clock)
	if(i<10001)
	begin
	if(~tophdl.PAC.STALL && ~tophdl.PAC.reset)
		begin
		if(i<=41)
			begin
			tophdl.PAC.SendCommand(command[i]);
			i=i+1;
			end
		else if(i>41)
			begin
			logic [24:0] randcommand;
			randcommand=$urandom;
			tophdl.PAC.SendCommand(randcommand);
			i=i+1;
			end
		end
	end
	else
	begin
	$display( " Hit to Miss ratio = %d /%0d " , tophvl.SB.HitCount,tophvl.SB.MissCount);
	$finish();
	end
always@(posedge tophdl.PAC.clock)
	begin
	if(tophdl.Bus.READrWRITE===1 )
		begin
		tophdl.Bus.ReadfromMem(memory[tophdl.Bus.Address[15:2]]);
		end
	end
	
always@(negedge tophdl.PAC.clock)
	if(tophdl.PAC.HIT || tophdl.PAC.MISS)
	tophdl.PAC.ReleaseBus();

always @(negedge tophdl.PAC.clock)
	begin
	if((StallCount==5 || StallCount==6 || StallCount==7 || StallCount==8 || StallCount==21 || StallCount==22 || StallCount==23 || StallCount==24) && tophdl.Bus.BusRd)
		SHARED<=1; 
	else 
		SHARED<='z;
	end
always @(negedge tophdl.PAC.clock) 
	if(tophdl.Bus.BusRd)  
	tophdl.Bus.ReleaseBus();
always @(posedge tophdl.PAC.clock) 
	if(i==41 && updatesignaltested==0)
	begin
	ADDRESS=16'b0000010100000100; DATA=32'habcdef12; BusUPD=1;
	updatesignaltested=1;
	end
	else
	begin
	ADDRESS='z; DATA='z; BusUPD='z;
	end

final
	begin
	$display( "Number of MISSES=%d " , tophvl.SB.MissCount);
	end
	
endmodule: TopTB
