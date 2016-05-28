module testLRU();

int MRUWay;
parameter ASSOCIATIVITY=4;
logic [ASSOCIATIVITY-1:0][1:0] 	LRUREG;

initial
begin
LRUREG[3]=2'd3;
LRUREG[2]=2'd1;
LRUREG[1]=2'd0;
LRUREG[0]=2'd2;

MRUWay=0;
UpdateLRU;

MRUWay=1;
UpdateLRU;

MRUWay=2;
UpdateLRU;

MRUWay=3;
UpdateLRU;
end

task automatic UpdateLRU;

int rank;
foreach(LRUREG[i])
	begin
	if(LRUREG[i]==MRUWay)
		begin
		rank=i;
		end
	end
unique case(rank)
	3:	begin
		LRUREG[ASSOCIATIVITY-1:0]=LRUREG[ASSOCIATIVITY-1:0];
		$display("LRU is now %d , %d , %d , %d", LRUREG[3],LRUREG[2],LRUREG[1],LRUREG[0]);
	   	end
	2:	begin
		LRUREG[ASSOCIATIVITY-1:2]={LRUREG[2],LRUREG[ASSOCIATIVITY-1:3]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[3],LRUREG[2],LRUREG[1],LRUREG[0]);
	  	end
	1:	begin
		LRUREG[ASSOCIATIVITY-1:1]={LRUREG[1],LRUREG[ASSOCIATIVITY-1:2]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[3],LRUREG[2],LRUREG[1],LRUREG[0]);
		end
	0:	begin
		LRUREG[ASSOCIATIVITY-1:0]={LRUREG[0],LRUREG[ASSOCIATIVITY-1:1]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[3],LRUREG[2],LRUREG[1],LRUREG[0]);
		end
endcase
endtask

endmodule
