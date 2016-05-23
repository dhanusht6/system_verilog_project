`include "CachePackage.pkg"
//=================================== Main Memory =====================================
//Mainbus structured as interface
interface MainBus();
import CachePackage::*;
ADDRESS address;
logic [DATABUSWIDTH-1:0] DataIn,DataOut;
logic READ;
logic WRITE;
logic BusRd;
logic BusUpd;
logic Shared;

	modport CACHE(output address,READ,WRITE,BusRd ,BusUpd,Shared,DataOut, input DataIn);
	modport MEM(input address,READ,WRITE,DataOut, output DataIn);

endinterface

//Interface between Processor and Cache
interface ProcAndCache;
import CachePackage::*;
ADDRESS address;
logic [7:0] DataIn,DataOut;
logic STALL;
logic READ;
logic WRITE;
logic HIT;
logic MISS;

	modport CACHE(input address,READ,WRITE,DataIn,output HIT,MISS,STALL,DataOut);
	modport PROC(input HIT,MISS,STALL,DataOut,output address,READ,WRITE,DataIn);

endinterface

import CachePackage::*;

//Main module describing the behaviour of the CACHE
module CACHE(ProcAndCache.CACHE intrfcip, input bit clock, MainBus.CACHE intrfcop,input bit reset);
import CachePackage::*;
//Complete CACHE
SET [SETS-1:0] CACHEMEM;
enum bit [2:0] {RESET,IDLE,Evict,ReadfromMem, SendtoProc, WritetoCache} State, NextState;
logic PrWr,PrWrMiss;
logic PrRd,PrRdMiss;
BLOCK LRUblock;
logic [WAYREPBITS:0] HitWay, EvictWay;

//================================= Sequential Block ====================================
always_ff @(posedge clock)
begin
if(reset)
	State=RESET;
else
	State=NextState;
end

//================================= Combinational Block =================================
always_comb
begin
unique case(State)
		RESET:
			begin
			//$display("Entered reset");
			for(int i=SETS-1; i>=0; i=i-1)
				for(int j=ASSOCIATIVITY;j>0;j=j-1)
					CACHEMEM[i].BLOCKS[j].VALIDBIT=0;
			//$display("CACHEMEM['0].BLOCKS[14'd2].VALIDBIT=%d",CACHEMEM[0].BLOCKS[2].VALIDBIT);
			NextState=IDLE;
			end
		IDLE: if(intrfcip.READ || intrfcip.WRITE)
			begin
			foreach(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i])
			begin:Checking
				 if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].TAG==intrfcip.address.TAG)
					begin
					intrfcip.MISS=0;
					intrfcip.HIT=1;
					intrfcip.STALL=0;
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
					disable Checking;
					end
				else 
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
				intrfcop.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
				intrfcop.WRITE=1;
				end
			NextState=ReadfromMem;
			end

		ReadfromMem:
			begin
			DragonUpdate;
			intrfcop.READ=1;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA=intrfcop.DataIn;
			$display("CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA=%h",CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA);
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].TAG=intrfcip.address.TAG;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].VALIDBIT=1;
			unique if(PrRdMiss)
				NextState=SendtoProc;
			else if(PrWrMiss)
				NextState=WritetoCache;
			end
		SendtoProc:
			begin
			UpdateLRU;
			if(PrRdMiss)
				begin
				intrfcip.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY]].DATA[intrfcip.address.BYTESELECT];
				end
			else if(PrRd)
				begin
				intrfcip.DataOut=CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT];
				DragonUpdate;
				end
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
			NextState=IDLE;
			end

		WritetoCache:
			begin
			unique if(PrWrMiss)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[CACHEMEM[intrfcip.address.INDEX].LRUREG[ASSOCIATIVITY]].DATA[intrfcip.address.BYTESELECT]=intrfcip.DataIn;
				end
			else if(PrWr)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT]=intrfcip.DataIn;
				DragonUpdate;
				end
			UpdateLRU;
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
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
unique if(PrRd || PrWr)
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
					intrfcop.BusUpd=1;
					if(intrfcop.Shared)
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
					intrfcop.BusUpd=1;
					if(intrfcop.Shared)
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
	intrfcop.BusRd=1;
	unique if(PrRdMiss)
		begin
		$display("entered task");
		if(intrfcop.Shared)
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=EXCLUSIVE;
		else if (~intrfcop.Shared)
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDCLEAN;
		end
	else if(PrWrMiss)
		begin
		unique if(intrfcop.Shared)
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDMODIFIED;
			intrfcop.BusUpd=1;
			end
		else if (~intrfcop.Shared)
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=DIRTY;
		end
	end
endtask

endmodule

