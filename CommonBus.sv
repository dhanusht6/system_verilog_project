import CachePackage::*;
//Mainbus structured as interface
interface CommonBus(input clock);
//pragma attribute CommonBus partition_interface_xif 
//ADDRESS address;
wire [DATABUSWIDTH-1:0] Data;
wire [ADDRESSWIDTH-1:0] Address;
logic READrWRITE;
wire BusRd;
wire BusUpd;
wire Shared;

logic [DATABUSWIDTH-1:0] data;
assign Data=data;

	//method called from test bench side when Cache has to read from memory
	function automatic void ReadfromMem(input logic [DATABUSWIDTH-1:0] DATA); //pragma tbx xtf
		data=DATA;
	endfunction
	
	//method to release the hold of the databus. 
	function automatic void ReleaseBus(); //pragma tbx xtf
		data='z;
	endfunction

endinterface







