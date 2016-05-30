module testLRU();

parameter ASSOCIATIVITY=4;
parameter WAYREPBITS=($clog2(ASSOCIATIVITY));
logic [ASSOCIATIVITY:1][WAYREPBITS:0] 	LRUREG , LRUREG1;
logic [WAYREPBITS:0] MRUWay;
parameter Delay =10ns;

initial
begin
LRUREG[4]=3'd3;
LRUREG[3]=3'd1;
LRUREG[2]=3'd4;
LRUREG[1]=3'd2;
$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
MRUWay=3;
UpdateLRU;
#Delay
MRUWay=1;
UpdateLRU;
#Delay
MRUWay=4;
UpdateLRU;
#Delay
MRUWay=2;
UpdateLRU;
#Delay
LRUREG[4]=3'd3;
LRUREG[3]=3'd1;
LRUREG[2]=3'd0;
LRUREG[1]=3'd0;
MRUWay=4;
$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);

LRUREG[4]=3'd3;
LRUREG[3]=3'd1;
LRUREG[2]=3'd4;
LRUREG[1]=3'd2;

for (int i=0 ; i < 500 ; i++ ) begin
$display("LRU is now %d , %d , %d , %d", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
LRUREG1 = LRUREG ; 
MRUWay = $urandom_range(3'd4,3'd1);
$display("The value of the MRUWay is:%p", MRUWay);
UpdateLRU;
UpdateLRUcheck;
#Delay;
//$display("The LRU:", LRUREG[4],LRUREG[3],LRUREG[2],LRUREG[1]);
$display("****************************************************");
end
LRUREG[4]=3'd3;LRUREG[3]=3'd0;LRUREG[2]=3'd0;LRUREG[1]=3'd0;
UpdateLRUcheck;
#Delay
LRUREG[4]=3'd3;LRUREG[3]=3'd1;LRUREG[2]=3'd0;LRUREG[1]=3'd0;
UpdateLRUcheck;
#Delay
LRUREG[4]=3'd3;LRUREG[3]=3'd1;LRUREG[2]=3'd2;LRUREG[1]=3'd0;
UpdateLRUcheck;
#Delay
$stop();

end

C1:cover property(A1);

task UpdateLRUcheck;

if (LRUREG1[1] == MRUWay)
A1: assert(LRUREG[ASSOCIATIVITY:1]=={LRUREG1[1],LRUREG1[ASSOCIATIVITY:2]}) else $error (" Rank1 error");
if (LRUREG1[2] == MRUWay)
assert(LRUREG[ASSOCIATIVITY:2]=={LRUREG1[2],LRUREG1[ASSOCIATIVITY:3]})  else $error ("Rank2 error");
if (LRUREG1[3] == MRUWay)
assert(LRUREG[ASSOCIATIVITY:3]=={LRUREG1[3],LRUREG1[ASSOCIATIVITY:4]})  else $error ("Rank3 error");
if (LRUREG1[4] == MRUWay)
assert(LRUREG[ASSOCIATIVITY:1]==LRUREG1[ASSOCIATIVITY:1])  else $error ("Rank4 error");
if (~LRUREG[4] || ~LRUREG[3] || ~LRUREG[2] || ~LRUREG[1])

begin
if (LRUREG[4] == 1'b0) 
assert (LRUREG[3] == 0 && LRUREG[2] ==1'b0 && LRUREG[1] == 0) else $error (" error in LRUREG[3] or LRUREG[2] or LRUREG[1]");

else if (LRUREG[4] != 1'b0 && LRUREG[3] == 1'b0 ) 
assert (LRUREG[2] ==1'b0 && LRUREG[1] == 0) else $error ("error in LRUREG[2] or LRUREG[1]");

else if (LRUREG[4] != 1'b0 && LRUREG[3] != 1'b0 && LRUREG[2] == 1'b0 ) 
assert (LRUREG[1] == 0) else $error ("error in  LRUREG[1]");

end



endtask



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