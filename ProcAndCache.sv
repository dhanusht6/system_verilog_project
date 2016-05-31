import CachePackage::*;
//Interface between Processor and Cache
interface ProcAndCache(input clock,reset);
//pragma attribute ProcAndCache partition_interface_xif 
ADDRESS Address;
wire [7:0] Data;
logic STALL;
logic READrWRITE;
logic HIT;
logic MISS;

logic [7:0] DATA;
assign Data=DATA;

	
	function automatic void SendCommand(input logic [24:0] command);   //pragma tbx xtf
	READrWRITE=command[24];
	Address.INDEX=command[23:16];
	Address.TAG=command[15:10];
	Address.BYTESELECT=command[9:8];
	DATA=command[7:0];
	endfunction

	function automatic void ReleaseBus();    //pragma tbx xtf
	DATA='z;
	endfunction

endinterface
