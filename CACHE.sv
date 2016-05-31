`define DEBUG
import CachePackage::*;

//Main module describing the behaviour of the CACHE
module Cache(ProcAndCache intrfcip, CommonBus intrfcop);

//Complete CACHE
SET [SETS-1:0] CACHEMEM;
enum bit [2:0] {RESET,IDLE,CheckHitrMiss,Evict,ReadfromMem, SendtoProc, WritetoCache} State, NextState;
logic PrWr,PrWrMiss,PrRd,PrRdMiss;
logic [WAYREPBITS:0] Way,UpdateWay; 
logic [ADDRESSWIDTH-1:0] ADDRESS;
logic BusRD,SHARED,BusUPD;
logic [DATABUSWIDTH-1:0] DATA;
logic [7:0] DATAIN;
logic update,updateothers,reading,ProtocolUpdated,lruupdated;
logic [7:0] DataBuffer;
logic CommandReceived;

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
	State<=RESET;
else
	State<=NextState;
end

//================================= Combinational Block =================================
always_comb
begin
if(intrfcop.BusUpd && updateothers!=1)
			begin
			for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
				begin
				if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].TAG==intrfcop.Address[7:2])
					begin
				 	CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].DATA=intrfcop.Data;
					UpdateWay=i;
					update=1;
					DragonUpdate();
					end
				end
			end
else if(intrfcop.BusRd && reading!=1)
	begin
		for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
			begin
			if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcop.Address[15:8]].BLOCKS[i].TAG==intrfcop.Address[7:2])
				begin
				update=1;
				UpdateWay=i;
				DragonUpdate();
				end
			end
	end

else if(~intrfcop.BusRd && reading!=1)
	begin
	DATA='z;
	end
case(State)
		RESET:
			begin
			for(int i=SETS-1; i>=0; i=i-1)
				for(int j=ASSOCIATIVITY;j>0;j=j-1)
					begin
					CACHEMEM[i].BLOCKS[j].VALIDBIT=0;
					CACHEMEM[i].LRUREG='0;
					end
			{PrWr,PrWrMiss,PrRd,PrRdMiss}=4'b0000;
			{intrfcip.HIT,intrfcip.MISS,intrfcip.STALL}=3'b0;
			{UpdateWay,Way}=2'b00; 
			{BusRD,DATA,DATAIN}='z;
			{SHARED,BusUPD,updateothers,update,ProtocolUpdated}=5'bzz000; 
			NextState=IDLE;
			end
		IDLE: 	begin
			{PrWr,PrWrMiss,PrRd,PrRdMiss}=4'b0000;
			ProtocolUpdated=0; lruupdated=0;
			{UpdateWay,Way}=2'b00; 
			{DATAIN,ADDRESS}='z;
			{BusUPD,updateothers}=2'bz0;
			intrfcip.STALL=0;
			if(intrfcip.READrWRITE || ~intrfcip.READrWRITE)
				begin
				`ifdef DEBUG
				if(intrfcip.READrWRITE)
				$display(" Command Received is READ at %t",$time);
				else
				$display(" Command Received is WRITE at %t",$time);
				`endif
				NextState=CheckHitrMiss;
				DataBuffer=intrfcip.Data;
				end
			else
				NextState=IDLE;
			end
		CheckHitrMiss:
			begin
			automatic bit hitfound=0;
			`ifdef DEBUG
			ValidData: assert (~$isunknown(intrfcip.Address)) else $error(" Valid address not available when expected");
			if(~intrfcip.READrWRITE)
			`endif
			CommandReceived=0;
			//intrfcip.ProcReleaseBus();
			for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
			begin
				 if(CACHEMEM[intrfcip.Address.INDEX].BLOCKS[i].VALIDBIT==1 && CACHEMEM[intrfcip.Address.INDEX].BLOCKS[i].TAG==intrfcip.Address.TAG)
					begin
					if(hitfound==0)
					begin
					{intrfcip.HIT,intrfcip.MISS,intrfcip.STALL}=3'b101;
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
					`ifdef DEBUG
					$display(" It is a HIT at %t " , $time);
					`endif
					Way=i;
					hitfound=1;
					end 
					end
			end
					if(hitfound==0)
					begin
					{intrfcip.HIT,intrfcip.MISS,intrfcip.STALL}=3'b011;
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
					`ifdef DEBUG
					$display(" It is a MISS at %t " , $time);
					`endif
					end
			end

		Evict:
			begin
				automatic bit victimfound=0;
				intrfcip.MISS=0;
				`ifdef DEBUG
				$display(" In Eviction phase at %t " , $time);
				`endif
				for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
					begin
					if(CACHEMEM[intrfcip.Address.INDEX].BLOCKS[i].VALIDBIT==0)
						begin
						if(victimfound==0)
							begin
							Way=i;
							victimfound=1;
							end
						end
					else
						if(victimfound==0)
							Way=CACHEMEM[intrfcip.Address.INDEX].LRUREG[1];
					end
			if(CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE==DIRTY || CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE==SHAREDMODIFIED)
				begin
				intrfcop.READrWRITE=0;
				ADDRESS={intrfcip.Address.INDEX,CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].TAG,2'b0};
				DATA=CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].DATA;
				//intrfcop.WritetoMem(intrfcop.Address,intrfcop.Data);
				end
			intrfcop.READrWRITE=1;
			ADDRESS=intrfcip.Address;
			NextState=ReadfromMem;
			end

		ReadfromMem:
			begin
			`ifdef DEBUG
			$display(" Reading from memory at %t " , $time);
			`endif
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].DATA=intrfcop.Data;
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].TAG=intrfcip.Address.TAG;
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].VALIDBIT=1;
			intrfcop.READrWRITE='z;
			if(PrRdMiss)
				begin
				NextState=SendtoProc;
				end
			else if(PrWrMiss)
				begin
				NextState=WritetoCache;
				end
			{BusRD,reading}=2'b11;
			end
		SendtoProc:
			begin
			if(ProtocolUpdated==0)
				begin
				DragonUpdate();
				ProtocolUpdated=1;
				`ifdef DEBUG
				$display(" State Updated %t " , $time);
				`endif
				end
			if(lruupdated==0)
				begin
				UpdateLRU();
				lruupdated=1;
				`ifdef DEBUG
				$display(" LRU Updated at %t " , $time);
				`endif
				end
			DATAIN=CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].DATA[intrfcip.Address.BYTESELECT];
			intrfcip.HIT=0;
			{BusRD,reading}=2'bz0;
			NextState=IDLE;
			`ifdef DEBUG
			$display(" READ process completed at %t " , $time);
			`endif
			end

		WritetoCache:
			begin
			if(ProtocolUpdated==0)
				begin
				DragonUpdate();
				ProtocolUpdated=1;
				`ifdef DEBUG
				$display(" State Updated %t " , $time);
				`endif
				end
			if(lruupdated==0)
				begin
				UpdateLRU();
				lruupdated=1;
				`ifdef DEBUG
				$display(" LRU Updated at %t " , $time);
				`endif
				end
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].DATA[intrfcip.Address.BYTESELECT]=DataBuffer;
			intrfcip.HIT=0;
			{BusRD,reading}=2'bz0;
			NextState=IDLE;
			`ifdef DEBUG
			$display(" WRITE process completed at %t " , $time);
			`endif
			end
endcase
end

//============================================= Function for updating LRU =======================================================
function automatic void UpdateLRU();

int rank=0;
	for(int i=ASSOCIATIVITY ; i>0 ; i=i-1)
	begin
	if(CACHEMEM[intrfcip.Address.INDEX].LRUREG[i]==Way)
		begin
		rank=i;
		end
	end

case(rank)
	4:	begin
		CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:1]=CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:1];
	   	end
	
	3:	begin
		CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:3]={CACHEMEM[intrfcip.Address.INDEX].LRUREG[3],CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:4]};
	  	end

	2:	begin
		CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:2]={CACHEMEM[intrfcip.Address.INDEX].LRUREG[2],CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:3]};
		end

	1:	begin
		CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:1]={CACHEMEM[intrfcip.Address.INDEX].LRUREG[1],CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:2]};
		end
	0:	begin
		CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:1]={Way,CACHEMEM[intrfcip.Address.INDEX].LRUREG[ASSOCIATIVITY:2]};
		end
endcase
endfunction


//================Dragon Protocol to update the State of the Cache Blocks and maintain coherence.======================
function automatic void DragonUpdate();
BLOCKSTATE STATE;
STATE=CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE;
if(intrfcop.BusUpd && update)
	begin
	if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE==SHAREDMODIFIED)
		begin
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE=SHAREDCLEAN;
		update=0; UpdateWay=0;
		end
	end

else if(intrfcop.BusRd && update)
	begin
	if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE==EXCLUSIVE)
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE=SHAREDCLEAN;
	else if(CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE==DIRTY)
		CACHEMEM[intrfcop.Address[15:8]].BLOCKS[Way].STATE=SHAREDMODIFIED;
	update=0; UpdateWay=0;
	end
else if(PrRd || PrWr)
begin
case(STATE)
		EXCLUSIVE: begin
				if(PrRd)
					CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=EXCLUSIVE;
				else if(PrWr)
					CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=DIRTY;
			   end

		SHAREDCLEAN: begin
				if(PrRd)
					CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDCLEAN;
				else if(PrWr)
					begin
					{BusUPD,updateothers}=2'b11;
					if(intrfcop.Shared)
						begin
						CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=DIRTY;
						end
					else 
						begin
						CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDMODIFIED;
						end
					end
			     end

		SHAREDMODIFIED: begin
				if(PrRd)
					CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDMODIFIED;
				else if(PrWr)
					begin
					{BusUPD,updateothers}=2'b11;
					if(intrfcop.Shared)
						CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDMODIFIED;
					else
						CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=DIRTY;
					end
			       end
		DIRTY:         begin
				if(PrRd || PrWr)
					CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=DIRTY;
			       end
		endcase
	end
else if(PrRdMiss || PrWrMiss)
	begin
	if(PrRdMiss)
		begin
		
		if(intrfcop.Shared)
			begin
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDCLEAN;
			end
		else 
			begin
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=EXCLUSIVE;
			end
		end
	else if(PrWrMiss)
		begin
		if(intrfcop.Shared)
			begin
			{BusUPD,updateothers}=2'b11;
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=SHAREDMODIFIED;
			end
		else 
			CACHEMEM[intrfcip.Address.INDEX].BLOCKS[Way].STATE=DIRTY;
		end
	end
endfunction
endmodule
