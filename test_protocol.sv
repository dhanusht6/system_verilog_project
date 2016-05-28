module test_dragon();
typedef enum int {EXCLUSIVE=0 , SHAREDCLEAN=1 , SHAREDMODIFIED=2 , DIRTY=3} BLOCKSTATE;
BLOCKSTATE STATE, PREVIOUS_STATE ;
logic BusUpd, PrRd, PrWr, PrRdMiss,PrWrMiss, Shared ;
//logic clk, reset;
parameter Delay =  10ns;
parameter Delay_1 = 1ns;

initial begin
STATE = SHAREDMODIFIED;
for (int i=0 ; i <1000 ;i++)begin
 PREVIOUS_STATE = STATE;
 {BusUpd, PrWr, PrRd, PrRdMiss,PrWrMiss, Shared } = $random();
 DragonUpdate; 
 Display;
 Analyse;
#Delay;
end
STATE = SHAREDMODIFIED ;PREVIOUS_STATE = STATE;{BusUpd, PrWr, PrRd, PrRdMiss,PrWrMiss, Shared } = 6'b101110;
DragonUpdate; 
Display;
Analyse;
$stop();
end

task automatic Display;
$display("Time :%t PRE_STATE:%s STATE:%s BusUpd  :%b PrRd:%b PrWr:%b PrRdMiss:%b  PrWrMiss:%b Shared:%b ",$time,PREVIOUS_STATE, STATE, BusUpd, PrRd, PrWr, PrRdMiss,PrWrMiss, Shared );
endtask


task automatic Analyse;

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == EXCLUSIVE && PrRd )
assert (STATE == EXCLUSIVE) else $error (" EXCLUSIVE to EXCLUSIVE err ");

if (BusUpd && PREVIOUS_STATE==SHAREDMODIFIED ) 
assert(STATE == SHAREDCLEAN )else $error (" BusUpd error,STATE : %p",STATE);

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == EXCLUSIVE && PrWr  && ~PrRd)
assert (STATE == DIRTY) else $error (" EXCLUSIVE to DIRTY err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDCLEAN && PrRd )
assert (STATE == SHAREDCLEAN) else $error (" SHAREDCLEAN to SHAREDCLEAN err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDCLEAN && ~PrRd  && PrWr && Shared) 
assert (STATE == SHAREDMODIFIED) else $error (" SHAREDCLEAN to  SHAREDMODIFIED err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDCLEAN && ~PrRd  && PrWr && ~Shared) 
assert (STATE == DIRTY) else $error (" SHAREDCLEAN to  DIRTY err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDMODIFIED && PrRd )
assert (STATE == SHAREDMODIFIED) else $error (" SHAREDMODIFIED to SHAREDMODIFIED err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDMODIFIED && ~PrRd && PrWr && Shared)
assert (STATE == SHAREDMODIFIED) else $error (" SHAREDMODIFIED to SHAREDMODIFIED err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == SHAREDMODIFIED && ~PrRd && PrWr && ~Shared)
assert (STATE == DIRTY) else $error (" SHAREDMODIFIED to DIRTY err ");

if (~BusUpd && (PrRd || PrWr) && PREVIOUS_STATE == DIRTY )
assert (STATE == DIRTY) else $error (" DIRTY to DIRTY err ");

if (~BusUpd && ~(PrRd || PrWr)&& (PrRdMiss || PrWrMiss) && PrRdMiss && Shared )
assert (STATE == SHAREDCLEAN) else $error (" SHAREDCLEAN err ");

if (~BusUpd && ~(PrRd || PrWr)&& (PrRdMiss || PrWrMiss) && PrRdMiss && ~Shared )
assert (STATE == EXCLUSIVE) else $error (" EXCLUSIVE err ");


if (~BusUpd && ~(PrRd || PrWr) &&  (PrRdMiss || PrWrMiss) && ~PrRdMiss && PrWrMiss && Shared )
assert (STATE == SHAREDMODIFIED) else $error (" SHAREDMODIFIED err "); 


if (~BusUpd &&~(PrRd || PrWr) &&(PrRdMiss || PrWrMiss) && ~PrRdMiss && PrWrMiss && ~Shared )
assert (STATE == DIRTY) else $error (" DIRTY err "); 




endtask

task automatic DragonUpdate;
if(BusUpd)
	begin
		if(STATE==SHAREDMODIFIED)
		begin
		STATE=SHAREDCLEAN;

		end
	end
else if(PrRd || PrWr)
	begin
	unique case(STATE)
		EXCLUSIVE: begin
				if(PrRd)
					STATE=EXCLUSIVE;
				else if(PrWr)
					STATE=DIRTY;
			   end

		SHAREDCLEAN: begin
				if(PrRd)
					STATE=SHAREDCLEAN;
				else if(PrWr)
					begin
					BusUpd=1;
					if(Shared)
						STATE=SHAREDMODIFIED;
					else
						STATE=DIRTY;
					end
			     end

		SHAREDMODIFIED: begin
				if(PrRd)
					STATE=SHAREDMODIFIED;
				else if(PrWr)
					begin
					BusUpd=1;
					if(Shared)
						STATE=SHAREDMODIFIED;
					else
						STATE=DIRTY;
					end
			       end
		DIRTY:         begin
				if(PrRd || PrWr)
					STATE=DIRTY;
			       end
		endcase
	end
else if(PrRdMiss || PrWrMiss)
	begin
	if(PrRdMiss)
		begin
		if(Shared)
			begin
			STATE=SHAREDCLEAN;
			end
		else if (~Shared)
			begin
			STATE=EXCLUSIVE;
			end
		end
	else if(PrWrMiss)
		begin
		unique if(Shared)
			begin
			STATE=SHAREDMODIFIED;
			end
		else if (~Shared)
			STATE=DIRTY;
		end
	end
endtask
endmodule