
`include "CachePackage.pkg"
import CachePackage::*;
//=================================== Main Memory =====================================
//Mainbus structured as interface
interface MainBus(input clock);
ADDRESS address;
logic [BLOCKBYTES-1:0] [7:0] DataIn,DataOut;
logic READ;
logic WRITE;
SnoopSignals Snoop;
BroadcastSignals Broadcast;

	modport CACHE(output address,READ,WRITE,Broadcast,DataOut, input DataIn,Snoop,clock);
	modport MEM(input address,READ,WRITE,DataOut,clock, output DataIn);

endinterface

//Interface between Processor and Cache
interface ProcAndCache(input clock,reset);
ADDRESS address;
logic [7:0] DataIn,DataOut;
logic STALL;
logic READ;
logic WRITE;
logic HIT;
logic MISS;

	modport CACHE(input address,READ,WRITE,DataIn,clock,reset,output HIT,MISS,STALL,DataOut);
	modport PROC(input HIT,MISS,STALL,DataOut,clock,output address,READ,WRITE,DataIn);

endinterface

//Main module describing the behaviour of the CACHE
module CACHE(ProcAndCache.CACHE intrfcip, MainBus.CACHE intrfcop);
//Complete CACHE
SET [SETS-1:0] CACHEMEM;
enum bit [2:0] {RESET,IDLE,Evict,WritetoMem, ReadfromMem, SendtoProc, WritetoCache} State, NextState;
logic PrWr,PrWrMiss;
logic PrRd,PrRdMiss;
logic [WAYREPBITS:0] HitWay='0;
logic [WAYREPBITS:0] EvictWay='0; 
logic [WAYREPBITS:0] UpdateWay='0;

//================================= Sequential Block ====================================
always_ff @(posedge intrfcip.clock)
begin
if(intrfcip.reset)
	State=RESET;
else
	State=NextState;
end

//================================= Combinational Block =================================
always_comb
begin
if(intrfcop.Snoop.BusUpd)
			begin
			foreach(CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i])
				begin
				if(CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].TAG==intrfcip.address.TAG)
					begin
				 	CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].DATA=intrfcop.Snoop.Data;
					UpdateWay=i;
					end
				end
			DragonUpdate;
			end
else if(intrfcop.Snoop.BusRd)
	begin
		foreach(CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i])
			begin
			if(CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].TAG==intrfcip.address.TAG)
				begin
				intrfcop.Broadcast.BusUpd=1;
				intrfcop.DataOut=CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i].DATA;
				intrfcop.address=CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[i];
				end
			end
	end
unique case(State)
		RESET:
			begin
			for(int i=SETS-1; i>=0; i=i-1)
				for(int j=ASSOCIATIVITY;j>0;j=j-1)
					begin
					CACHEMEM[i].BLOCKS[j].VALIDBIT=0;
					CACHEMEM[i].LRUREG='0;
					end
				
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
			intrfcip.STALL=0;
			intrfcop.READ=0;
			intrfcop.WRITE=0;
			HitWay='0;
			EvictWay='0; 
			UpdateWay='0;
			intrfcop.Broadcast.BusRd=0;
			intrfcop.Broadcast.BusUpd=0;
			intrfcop.Broadcast.Shared=0;
			NextState=IDLE;
			end
		IDLE: 	begin
			intrfcop.Broadcast.BusUpd=0;
			if(intrfcip.READ || intrfcip.WRITE)
			begin
			automatic bit hitfound=0;
			foreach(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i])
			begin
				 if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].TAG==intrfcip.address.TAG)
					begin
					if(hitfound==0)
					begin
					intrfcip.MISS=0;
					intrfcip.HIT=1;
					intrfcip.STALL=1;
					if(intrfcip.READ)
						begin
						PrRd=1;
						NextState=SendtoProc;
						end
					else if (intrfcip.WRITE)
						begin
						PrWr=1;
						NextState=WritetoCache;
						end
					HitWay=i;
					hitfound=1;
					end 
					end
				else 
					if(hitfound==0)
					begin
					intrfcip.MISS=1;
					intrfcip.HIT=0;
					intrfcip.STALL=1;
					if(intrfcip.READ)
						begin
						PrRdMiss=1;
						NextState=Evict;
						end
					else if (intrfcip.WRITE)
						begin
						PrWrMiss=1;
						NextState=Evict;
						end
					end
			end
			end
			end

		Evict:
			begin
				automatic bit found=0;
				foreach(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i])
					begin
					if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].VALIDBIT==0)
						begin
						if(found==0)
							begin
							EvictWay=i;
							found=1;
							end
						end
					else
						if(found==0)
						EvictWay=CACHEMEM[intrfcip.address.INDEX].LRUREG[1];
					end
			if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE==DIRTY || CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE==SHAREDMODIFIED)
				begin
				intrfcop.WRITE=1;
				intrfcop.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
				NextState=WritetoMem;
				end
			else
				begin
				intrfcop.READ=1;
				intrfcop.address=intrfcip.address;
				NextState=ReadfromMem;
				end
			end

		WritetoMem:	begin
				NextState=ReadfromMem;
				intrfcop.WRITE=0;
				end

		ReadfromMem:
			begin
			intrfcop.Broadcast.BusRd=1;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA=intrfcop.DataIn;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].TAG=intrfcip.address.TAG;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].VALIDBIT=1;
			intrfcop.READ=0;
			unique if(PrRdMiss)
				NextState=SendtoProc;
			else if(PrWrMiss)
				NextState=WritetoCache;
			end
		SendtoProc:
			begin
			UpdateLRU;
			DragonUpdate;
			intrfcop.Broadcast.BusRd=0;
			if(PrRdMiss)
				begin
				intrfcip.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA[intrfcip.address.BYTESELECT];
				end
			else if(PrRd)
				begin
				$display("entered");
				intrfcip.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT];
				//$display("data=%h",CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT]);
				end
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
			HitWay='0;
			EvictWay='0; 
			UpdateWay='0;
			intrfcop.Broadcast.Shared=0;
			intrfcip.STALL=0;
			NextState=IDLE;
			end

		WritetoCache:
			begin
			UpdateLRU;
			DragonUpdate;
			intrfcop.Broadcast.BusRd=0;
			if(PrWrMiss)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA[intrfcip.address.BYTESELECT]=intrfcip.DataIn;
				intrfcop.Broadcast.BusUpd=1;
				end
			else if(PrWr)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT]=intrfcip.DataIn;
				end
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
			HitWay='0;
			EvictWay='0; 
			UpdateWay='0;
			intrfcop.Broadcast.Shared=0;
			intrfcip.STALL=0;
			NextState=IDLE;
			end
endcase
end

//============================================= Task for updating LRU =======================================================
task automatic UpdateLRU;

logic [WAYREPBITS:0] MRUWay;
int rank=0;

if(PrRd || PrWr)
	MRUWay=HitWay;
else if(PrRdMiss || PrWrMiss)
	MRUWay=EvictWay;

foreach(CACHEMEM[intrfcip.address.INDEX].LRUREG[i])
	begin
	if(CACHEMEM[intrfcip.address.INDEX].LRUREG[i]==MRUWay)
		begin
		rank=i;
		end
	end

unique case(rank)
	4:	begin
		CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:1]=CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:1];
	   	end
	
	3:	begin
		CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:3]={CACHEMEM[intrfcip.address.INDEX].LRUREG[3],CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:4]};
	  	end

	2:	begin
		CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:2]={CACHEMEM[intrfcip.address.INDEX].LRUREG[2],CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:3]};
		end

	1:	begin
		CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:1]={CACHEMEM[intrfcip.address.INDEX].LRUREG[1],CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:2]};
		end
	0:	begin
		CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:1]={MRUWay,CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY:2]};
		end
endcase

endtask


//================Dragon Protocol to update the State of the Cache Blocks and maintain coherence.======================
task automatic DragonUpdate;
if(intrfcop.Snoop.BusUpd)
	begin
	if(CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[UpdateWay].STATE==SHAREDMODIFIED)
		CACHEMEM[intrfcop.Snoop.address.INDEX].BLOCKS[UpdateWay].STATE=SHAREDCLEAN;
	end
else if(PrRd || PrWr)
	begin
	unique case(CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE)
		EXCLUSIVE: begin
				unique if(PrRd)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=EXCLUSIVE;
				else if(PrWr)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=DIRTY;
			   end

		SHAREDCLEAN: begin
				unique if(PrRd)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDCLEAN;
				else if(PrWr)
					begin
					intrfcop.Broadcast.BusUpd=1;
					if(intrfcop.Snoop.Shared)
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDMODIFIED;
					else
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=DIRTY;
					end
			     end

		SHAREDMODIFIED: begin
				unique if(PrRd)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDMODIFIED;
				else if(PrWr)
					begin
					intrfcop.Broadcast.BusUpd=1;
					if(intrfcop.Snoop.Shared)
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDMODIFIED;
					else
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=DIRTY;
					end
			       end
		DIRTY:         begin
				unique if(PrRd || PrWr)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=DIRTY;
			       end
		endcase
	end
else if(PrRdMiss || PrWrMiss)
	begin
	if(PrRdMiss)
		begin
		if(intrfcop.Snoop.Shared)
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDCLEAN;
			end
		else if (~intrfcop.Snoop.Shared)
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=EXCLUSIVE;
			end
		end
	else if(PrWrMiss)
		begin
		unique if(intrfcop.Snoop.Shared)
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDMODIFIED;
			end
		else if (~intrfcop.Snoop.Shared)
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=DIRTY;
		end
	end
endtask

endmodule

