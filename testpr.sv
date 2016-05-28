`include "CachePackage.pkg"
import CachePackage::*;

//Mainbus structured as interface
interface MainBus(input clock);
//pragma attribute MainBus partition_interface_xif 
ADDRESS address;
wire [DATABUSWIDTH-1:0] Data;
wire [ADDRESSWIDTH-1:0] Address;
logic READrWRITE;
wire BusRd;
wire BusUpd;
wire Shared;
logic [DATABUSWIDTH-1:0] data;
assign Data=data;

	initial
	begin
	$readmemh("MEM.txt",memory);
	end

	function automatic void ReadfromMem(input ADDRESS address);
        data=memory[{address.INDEX,address.TAG}];
	endfunction
	
	function automatic void releasebus();
	data='z;
	endfunction

	function automatic void WritetoMem(input ADDRESS address,input [DATABUSWIDTH-1:0] data);
	memory[{address.INDEX,address.TAG}]=data;
	endfunction

	modport CACHE(inout BusRd,BusUpd,Shared,Data,Address,input clock,output READrWRITE,import WritetoMem,ReadfromMem,releasebus);
endinterface

//Interface between Processor and Cache
interface ProcAndCache(input clock,reset);
//pragma attribute ProcAndCache partition_interface_xif 
ADDRESS address;
wire [7:0] Data;
logic STALL;
logic READrWRITE;
logic HIT;
logic MISS;

	modport CACHE(inout Data,output HIT,MISS,STALL,input READrWRITE,address,clock,reset);
	modport PROC(inout Data,input HIT,MISS,STALL,clock,reset,output READrWRITE,address);
endinterface


//Main module describing the behaviour of the CACHE
module CACHE(ProcAndCache.CACHE intrfcip, MainBus.CACHE intrfcop);

//Complete CACHE
SET [SETS-1:0] CACHEMEM;
enum bit [2:0] {RESET,IDLE,CheckHitrMiss,Evict,WritetoMem, ReadfromMem, SendtoProc, WritetoCache} State, NextState;
logic PrWr,PrWrMiss;
logic PrRd,PrRdMiss;
logic [WAYREPBITS:0] HitWay='0;
logic [WAYREPBITS:0] EvictWay='0; 
logic [WAYREPBITS:0] UpdateWay='0;
logic [ADDRESSWIDTH-1:0] ADDRESS;
logic BusRD,SHARED,BusUPD;
logic [DATABUSWIDTH-1:0] DATA;
logic [7:0] DATAIN;
logic update=0;
logic updateothers=0;
logic reading;
//logic hitfound=0;
//logic victimfound=0;
logic [7:0] DataBuffer;


assign intrfcop.Address=ADDRESS;
assign intrfcop.BusRd=BusRD;
assign intrfcop.BusUpd=BusUPD;
assign intrfcop.Shared=SHARED;
assign intrfcop.Data=DATA;
assign intrfcip.Data=DATAIN;

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
if(intrfcop.BusUpd && updateothers!=1)
			begin
			//foreach(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i])
			for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
				begin
				//$display("entered");
				if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].TAG==intrfcop.Address[7:2])
					begin
				 	CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].DATA=intrfcop.Data;
					UpdateWay=i;
					//$display("UpdateWay=%d",UpdateWay);
					update=1;
					DragonUpdate();
					end
				end
			end
else if(intrfcop.BusRd && reading!=1)
	begin
		//foreach(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i])
		for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
			begin
			if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].TAG==intrfcop.Address[7:2])
				begin
				update=1;
				UpdateWay=i;
				//$display("UpdateWay=%d",UpdateWay);
				DragonUpdate();
				end
			end
	end

else if(~intrfcop.BusRd && reading!=1)
	begin
	DATA='z;
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
			HitWay='0;
			EvictWay='0; 
			UpdateWay='0;
			BusRD='z;
			BusUPD='z;
			updateothers=0;
			SHARED='z;
			DATA='z;
			DATAIN='z;
			NextState=IDLE;
			end
		IDLE: 	begin
			PrWr=0;
			PrWrMiss=0;
			PrRd=0;
			PrRdMiss=0;
			intrfcip.HIT=0;
			intrfcip.MISS=0;
			HitWay='0;
			EvictWay='0; 
			UpdateWay='0;
			DATAIN='z;
			ADDRESS='z;
			BusUPD='z;
			updateothers=0;
			intrfcip.STALL=0;
			if(intrfcip.READrWRITE || ~intrfcip.READrWRITE)
				begin
				NextState=CheckHitrMiss;
				DataBuffer=intrfcip.Data;
				end
			else
				NextState=IDLE;
			end
		CheckHitrMiss:
			begin
			automatic bit hitfound=0;
			//foreach(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i])
			for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
			begin
				 if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].TAG==intrfcip.address.TAG)
					begin
					if(hitfound==0)
					begin
					intrfcip.MISS=0;
					intrfcip.HIT=1;
					intrfcip.STALL=1;
					if(intrfcip.READrWRITE)
						begin
						PrRd=1;
						NextState=SendtoProc;
						end
					else if(~intrfcip.READrWRITE)
						begin
						PrWr=1;
						NextState=WritetoCache;
						end
					HitWay=i;
					hitfound=1;
					end 
					end
			end
				//else 
					if(hitfound==0)
					begin
					intrfcip.MISS=1;
					intrfcip.HIT=0;
					intrfcip.STALL=1;
					if(intrfcip.READrWRITE)
						begin
						PrRdMiss=1;
						NextState=Evict;
						end
					else if (~intrfcip.READrWRITE)
						begin
						PrWrMiss=1;
						NextState=Evict;
						end
					end
			end


		Evict:
			begin
				automatic bit victimfound=0;
				//foreach(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i])
				for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
					begin
					if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[i].VALIDBIT==0)
						begin
						if(victimfound==0)
							begin
							EvictWay=i;
							victimfound=1;
							end
						end
					else
						if(victimfound==0)
						EvictWay=CACHEMEM[intrfcip.address.INDEX].LRUREG[1];
					end
			if(CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE==DIRTY || CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE==SHAREDMODIFIED)
				begin
				intrfcop.READrWRITE=0;
				ADDRESS={intrfcip.address.INDEX,CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].TAG,2'b0};
				DATA=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
				NextState=WritetoMem;
				end
			else
				begin
				intrfcop.READrWRITE=1;
				ADDRESS=intrfcip.address;
				NextState=ReadfromMem;
				end
			end

		WritetoMem:	begin
				intrfcop.WritetoMem(intrfcop.Address,intrfcop.Data);
				intrfcop.READrWRITE='1;
				ADDRESS=intrfcip.address;
				NextState=ReadfromMem;
				end

		ReadfromMem:
			begin
			BusRD=1;
			reading=1;
			intrfcop.ReadfromMem(intrfcop.Address);
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA=intrfcop.Data;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].TAG=intrfcip.address.TAG;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].VALIDBIT=1;
			intrfcop.READrWRITE='z;
			unique if(PrRdMiss)
				begin
				NextState=SendtoProc;
				end
			else if(PrWrMiss)
				begin
				NextState=WritetoCache;
				end
			DragonUpdate();
			end
		SendtoProc:
			begin
			UpdateLRU();
			intrfcop.releasebus();
			if(PrRdMiss)
				begin
				DATAIN=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA[intrfcip.address.BYTESELECT];
				end
			else if(PrRd)
				begin
				DATAIN=CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT];
				DragonUpdate();
				end
			BusRD='z;
			reading=0;
			NextState=IDLE;
			end

		WritetoCache:
			begin
			UpdateLRU();
			intrfcop.releasebus;
			if(PrWrMiss)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA[intrfcip.address.BYTESELECT]=DataBuffer;
				end
			else if(PrWr)
				begin
				CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].DATA[intrfcip.address.BYTESELECT]=DataBuffer;
				DragonUpdate();
				end
			BusRD='z;
			reading=0;
			NextState=IDLE;
			end
endcase
end

//============================================= Task for updating LRU =======================================================
function automatic void UpdateLRU();

logic [WAYREPBITS:0] MRUWay;
int rank=0;

if(PrRd || PrWr)
	MRUWay=HitWay;
else if(PrRdMiss || PrWrMiss)
	MRUWay=EvictWay;

//foreach(CACHEMEM[intrfcip.address.INDEX].LRUREG[i])
	for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
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

endfunction


//================Dragon Protocol to update the State of the Cache Blocks and maintain coherence.======================
function automatic void DragonUpdate();
if(intrfcop.BusUpd && update)
	begin
	//$display("CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE=%p",CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE);
	if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE==SHAREDMODIFIED)
		begin
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE=SHAREDCLEAN;
		update=0; UpdateWay=0;
		end
	end

else if(intrfcop.BusRd && update)
	begin
	if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE==EXCLUSIVE)
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE=SHAREDCLEAN;
	else if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE==DIRTY)
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[UpdateWay].STATE=SHAREDMODIFIED;
	update=0; UpdateWay=0;
	end
else if(PrRd || PrWr)
	begin
	case(CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE)
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
					//ADDRESS={intrfcip.address.INDEX,intrfcip.address.TAG,intrfcip.address.BYTESELECT};
					//DATA=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
					{BusUPD,updateothers}=2'b11;
					if(intrfcop.Shared)
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=DIRTY;
					else
						CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDMODIFIED;
					end
			     end

		SHAREDMODIFIED: begin
				unique if(PrRd)
					CACHEMEM[intrfcip.address.INDEX].BLOCKS[HitWay].STATE=SHAREDMODIFIED;
				else if(PrWr)
					begin
					//ADDRESS={intrfcip.address.INDEX,intrfcip.address.TAG,intrfcip.address.BYTESELECT};
					//DATA=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
					{BusUPD,updateothers}=2'b11;
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
	if(PrRdMiss)
		begin
		if(intrfcop.Shared)
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDCLEAN;
			end
		else
			begin
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=EXCLUSIVE;
			end
		end
	else if(PrWrMiss)
		begin
		unique if(intrfcop.Shared)
			begin
			//ADDRESS={intrfcip.address.INDEX,intrfcip.address.TAG,intrfcip.address.BYTESELECT};
			//DATA=CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].DATA;
			{BusUPD,updateothers}=2'b11;
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=SHAREDMODIFIED;
			end
		else 
			CACHEMEM[intrfcip.address.INDEX].BLOCKS[EvictWay].STATE=DIRTY;
		end
	end
endfunction
endmodule
