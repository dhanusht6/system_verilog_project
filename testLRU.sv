module testLRU();

parameter ASSOCIATIVITY=4;
parameter WAYREPBITS=($clog2(ASSOCIATIVITY));
logic [ASSOCIATIVITY:1][WAYREPBITS:0] 	LRUREG;
logic [WAYREPBITS:0] MRUWay;

initial
begin
LRUREG[4]=3'd3;
LRUREG[3]=3'd1;
LRUREG[2]=3'd4;
LRUREG[1]=3'd2;
$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
MRUWay=3;
UpdateLRU;

MRUWay=1;
UpdateLRU;

MRUWay=4;
UpdateLRU;

MRUWay=2;
UpdateLRU;

LRUREG[4]=3'd3;
LRUREG[3]=3'd1;
LRUREG[2]=3'd0;
LRUREG[1]=3'd0;

MRUWay=4;
UpdateLRU;
end



task automatic UpdateLRU;

int rank=0;
foreach(LRUREG[i])
	begin
	if(LRUREG[i]==MRUWay)
		begin
		rank=i;
		end
	end
$display("rank is %d",rank);
unique case(rank)
	4:	begin
		LRUREG[ASSOCIATIVITY:1]=LRUREG[ASSOCIATIVITY:1];
		$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
	   	end
	3:	begin
		LRUREG[ASSOCIATIVITY:3]={LRUREG[3],LRUREG[ASSOCIATIVITY:4]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
	  	end
	2:	begin
		LRUREG[ASSOCIATIVITY:2]={LRUREG[2],LRUREG[ASSOCIATIVITY:3]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
		end
	1:	begin
		LRUREG[ASSOCIATIVITY:1]={LRUREG[1],LRUREG[ASSOCIATIVITY:2]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
		end
	0:  	begin
		LRUREG[ASSOCIATIVITY:1]={MRUWay,LRUREG[ASSOCIATIVITY:2]};
		$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
		end
endcase
endtask

endmodule
