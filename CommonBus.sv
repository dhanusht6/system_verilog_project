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

	function automatic void ReadfromMem(input logic [DATABUSWIDTH-1:0] DATA); //pragma tbx xtf
		data=DATA;
	endfunction
	
	function automatic void ReleaseBus(); //pragma tbx xtf
		data='z;
	endfunction

	/*function automatic void WritetoMem(input ADDRESS address,input [DATABUSWIDTH-1:0] data); //pragma tbx xtf
		memory[{address.INDEX,address.TAG}]=data;
	endfunction*/
endinterface
