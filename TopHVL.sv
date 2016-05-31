import CachePackage::*;
module TopHVL(ProcAndCache ip, CommonBus op);

class ScoreBoard;
bit requests[$];
bit results[$];
int HitCount=0;
int MissCount=0;
int RequestCount;
endclass

ScoreBoard SB;
initial
	SB=new();

always@(negedge ip.clock)
	if(~ip.STALL && ~ip.reset)
		begin
		if(ip.READrWRITE)
			begin
			SB.requests[SB.RequestCount]=1;
			SB.RequestCount=SB.RequestCount+1;
			end
		else if(~ip.READrWRITE)
			begin
			SB.requests[SB.RequestCount]=0;
			SB.RequestCount=SB.RequestCount+1;
			end
		end

always@(posedge ip.HIT)
	begin
	SB.results[SB.RequestCount-1]=1;
	SB.HitCount=SB.HitCount+1;
	end
always@(posedge ip.MISS)
	begin
	SB.results[SB.RequestCount-1]=0;
	SB.MissCount=SB.MissCount+1;
	end

property VALIDDATA;
@(posedge ip.clock)
	disable iff(ip.reset)
		(~ip.READrWRITE && ~ip.STALL) |-> (~$isunknown(ip.Data));
endproperty

property VALIDADDRESS;
@(posedge ip.clock)
	disable iff(ip.reset)
		(~ip.STALL && (~$isunknown(ip.READrWRITE))) |-> (~$isunknown(ip.Address)) ;
endproperty

property READMISS;
@(posedge ip.clock)
	disable iff(ip.reset)
		(ip.MISS && ip.READrWRITE ) |-> ##3 (~$isunknown(ip.Data)) ##1 (~ip.STALL);
endproperty

property READHIT;
@(posedge ip.clock)
	disable iff(ip.reset)
		(ip.HIT && ip.READrWRITE ) |=> ((~$isunknown(ip.Data)) ##1 (~ip.STALL));
endproperty

property WRITEMISS;
@(posedge ip.clock)
	disable iff(ip.reset)
		(ip.MISS && ~ip.READrWRITE ) |-> ##4   (~ip.STALL);
endproperty

property VALIDDATAANDADDRESS;
@(posedge ip.clock)
	disable iff(ip.reset)
	(op.BusRd || op.BusUpd) |-> (~$isunknown(op.Data) && $isunknown(op.Address))
endproperty


property WRITEHIT;
@(posedge ip.clock)
	disable iff(ip.reset)
		(ip.HIT && ~ip.READrWRITE ) |-> ##2   (~ip.STALL)
endproperty

assert property(VALIDDATA);
assert property(VALIDADDRESS);
assert property(READMISS);
assert property(READHIT);
assert property(WRITEMISS);
assert property(WRITEHIT);


endmodule
