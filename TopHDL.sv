import CachePackage::*;

module TopHDL();
logic clock,reset;

//free running clock
//tbx clkgen
initial
	begin
	clock=0;
	forever #5ns clock=~clock;
	end

//Reset signal
//tbx clkgen
initial
	begin
	reset=1;
	#25ns reset=0;
	end
CommonBus Bus(.clock);
ProcAndCache PAC(.clock,.reset);
Cache C(.intrfcip(PAC),.intrfcop(Bus));
endmodule: TopHDL


