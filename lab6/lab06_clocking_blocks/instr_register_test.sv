/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 *
 * SystemVerilog Training Workshop.
 * Copyright 2006, 2013 by Sutherland HDL, Inc.
 * Tualatin, Oregon, USA.  All rights reserved.
 * www.sutherland-hdl.com
 **********************************************************************/

module instr_register_test (tb_ifc io);  // interface port

  timeunit 1ns/1ns;

  // user-defined types are defined in instr_register_pkg.sv
  import instr_register_pkg::*;

  int seed = 555;
	
class transaction;
	
	rand opcode_t opcode;
	rand operand_t operand_a;
	rand operand_t operand_b;
	address_t write_pointer;
	
	constraint op_a{
	operand_a >= -15 ;
	operand_a <= 15;
	}
	
	constraint op_b{
	operand_b >= 0;
	operand_b <=15;	
	}
	
	constraint opc{
	opcode >= 0;
	opcode <= 7;
	}
	
	// function void randomize_transaction();
    // // A later lab will replace this function with SystemVerilog
    // // constrained random values
    // //
    // // The stactic temp variable is required in order to write to fixed
    // // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
    // // write_pointer values in a later lab
    // //
    // static int temp = 0;
    // operand_a     = $random(seed)%16;                 // between -15 and 15
    // operand_b     = $unsigned($random)%16;            // between 0 and 15
    // opcode        = opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
    // write_pointer = temp++;
  // endfunction: randomize_transaction
  
virtual function void print_transaction();
    $display("Writing to register location %0d: ", write_pointer);
    $display("  opcode = %0d (%s)", opcode, opcode.name);
    $display("  operand_a = %0d",   operand_a);
    $display("  operand_b = %0d\n", operand_b);
  endfunction: print_transaction
  
endclass

class transaction_ext extends transaction;
		
		virtual function void print_transaction();
				$display("clasa extinsa");
				super.print_transaction();
		endfunction
		
endclass
  
class Driver;

	    transaction_ext tr_ext;
		
		virtual tb_ifc vifc;
		transaction tr;
		
	covergroup inputs_measure;
	
		cov_0: coverpoint vifc.cb.opcode {
			bins val_ZERO = {ZERO};
			bins val_PASSA = {PASSA};
			bins val_PASSB = {PASSB};
			bins val_ADD = {ADD};
			bins val_SUB = {SUB};
			bins val_MULT = {MULT};
			bins val_DIV = {DIV};
			bins val_MOD = {MOD};
		}	
		
		cov_1: coverpoint vifc.cb.operand_a {
			bins val_operand_a[] = {[-15:15]};
		}
	
		cov_2: coverpoint vifc.cb.operand_b {
			bins val_operand_b[] = {[0:15]};
		}
		
		cov_3: coverpoint vifc.cb.operand_a {
			bins val_operand_a_neg = {[-15:-1]};
			bins val_operand_a_poz = {[0:15]}; 
		}
		
		cov_4: cross cov_0, cov_3 {
			ignore_bins val_poz = binsof(cov_3.val_operand_a_poz);
		}
		
		ov_5: cross cov_0, cov_3 {
			ignore_bins val_neg = binsof(cov_3.val_operand_a_neg);
		}
		
	endgroup
	
		function new(virtual tb_ifc vifc);
			this.vifc = vifc;
			tr = new();
			tr_ext = new();
			inputs_measure = new;
		endfunction
		
	task generate_transaction;
	
		$display("\n\n***********************************************************");
		$display(    "*  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  *");
		$display(    "*  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     *");
		$display(    "*  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  *");
		$display(    "***************************************************");
	
		$display("\nReseting the instruction register...");
		reset_sgn();
		 
		@( vifc.cb) vifc.cb.load_en <= 1'b1;  // enable writing to register
		
		 repeat (5) begin
		 @(vifc.cb) tr.randomize();
		 assign_signal();
		 inputs_measure.sample;
		 @(vifc.cb) tr.print_transaction;

		 end
		 
		 tr = tr_ext;
		 
		 repeat (5) begin
		 @(vifc.cb) tr.randomize();
		 assign_signal();
		 inputs_measure.sample;
		 @(vifc.cb) tr.print_transaction;

		 end
		@(vifc.cb) vifc.cb.load_en <= 1'b0;  // turn-off writing to register
		
	endtask
	
	task reset_sgn;
		io.cb.write_pointer <= 5'h00;      // initialize write pointer
		io.cb.read_pointer  <= 5'h1F;      // initialize read pointer
		io.cb.load_en       <= 1'b0;       // initialize load control line
		io.cb.reset_n       <= 1'b0;       // assert reset_n (active low)
		repeat (2) @(vifc.cb);  // hold in reset for 2 clock cycles
		vifc.cb.reset_n       <= 1'b1;       // assert reset_n (active low)
	endtask
	
	function assign_signal;
		static int temp = 0;
		vifc.cb.operand_a <= tr.operand_a;
		vifc.cb.operand_b <= tr.operand_b;
		vifc.cb.opcode	  <= tr.opcode;
		vifc.cb.write_pointer <= temp++;	
	endfunction
	
endclass
	
class Monitor;
	virtual tb_ifc vifc;
	
		
		function new(virtual tb_ifc vifc);
			this.vifc = vifc;
		endfunction
		
		function void print_results();
			$display("Read from register location %0d: ", vifc.cb.read_pointer);
			$display("  opcode = %0d (%s)", vifc.cb.instruction_word.opc, vifc.cb.instruction_word.opc.name);
			$display("  operand_a = %0d",   vifc.cb.instruction_word.op_a);
			$display("  operand_b = %0d\n", vifc.cb.instruction_word.op_b);
		endfunction: print_results
			
		task transaction_monitor;
			$display("\nReading back the same register locations written...");
			for (int i=0; i<=5; i++) begin
				// A later lab will replace this loop with iterating through a
				// scoreboard to determine which address were written and the
				// expected values to be read back
				@(posedge vifc.cb) vifc.read_pointer <= i;
				@(posedge vifc.cb) print_results;
			end
		endtask
endclass
	
  
 //initial begin
 //  $display("\n\n***********************************************************");
 //  $display(    "*  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  *");
 //  $display(    "*  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     *");
 //  $display(    "*  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  *");
 //  $display(    "***************************************************");
 //
 //  $display("\nReseting the instruction register...");
 //  io.cb.write_pointer <= 5'h00;      // initialize write pointer
 //  io.cb.read_pointer  <= 5'h1F;      // initialize read pointer
 //  io.cb.load_en       <= 1'b0;       // initialize load control line
 //  io.cb.reset_n       <= 1'b0;       // assert reset_n (active low)
 //  repeat (2) @(posedge io.cb) ;  // hold in reset for 2 clock cycles
 //  io.cb.reset_n       <= 1'b1;       // assert reset_n (active low)
 //
 //  $display("\nWriting values to register stack...");
 //  @(posedge io.cb) io.cb.load_en <= 1'b1;  // enable writing to register
 //  repeat (3) begin
 //    @(posedge io.cb) randomize_transaction;
 //    @(negedge io.cb) print_transaction;
 //  end
 //  @(posedge io.cb) io.cb.load_en <= 1'b0;  // turn-off writing to register
 //
 //  // read back and display same three register locations
 //  $display("\nReading back the same register locations written...");
 //  for (int i=0; i<=2; i++) begin
 //    // A later lab will replace this loop with iterating through a
 //    // scoreboard to determine which address were written and the
 //    // expected values to be read back
 //    @(posedge io.cb) io.read_pointer <= i;
 //    @(posedge io.cb) print_results;
 //  end
 //
 //  @(posedge io.cb) ;
 //  $display("\n***********************************************************");
 //  $display(  "*  THIS IS NOT A SELF-CHECKING TESTBENCH (YET).  YOU  *");
 //  $display(  "*  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     *");
 //  $display(  "*  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  *");
 //  $display(  "***********************************************************\n");
 //  $finish;
 //end
 //
		
		
		
  //function void randomize_transaction;
  //  // A later lab will replace this function with SystemVerilog
  //  // constrained random values
  //  //
  //  // The stactic temp variable is required in order to write to fixed
  //  // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
  //  // write_pointer values in a later lab
  //  //
  //  static int temp = 0;
  //  io.cb.operand_a     <= $random(seed)%16;                 // between -15 and 15
  //  io.cb.operand_b     <= $unsigned($random)%16;            // between 0 and 15
  //  io.cb.opcode        <= opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
  //  io.cb.write_pointer <= temp++;
  //endfunction: randomize_transaction
  //
  //function void print_transaction;
  //  $display("Writing to register location %0d: ", io.cb.write_pointer);
  //  $display("  opcode = %0d (%s)", io.cb.opcode, io.cb.opcode.name);
  //  $display("  operand_a = %0d",   io.cb.operand_a);
  //  $display("  operand_b = %0d\n", io.cb.operand_b);
  //endfunction: print_transaction
  //
  //
  //function void print_results;
  //  $display("Read from register location %0d: ", io.cb.read_pointer);
  //  $display("  opcode = %0d (%s)", io.cb.instruction_word.opc, io.cb.instruction_word.opc.name);
  //  $display("  operand_a = %0d",   io.cb.instruction_word.op_a);
  //  $display("  operand_b = %0d\n", io.cb.instruction_word.op_b);
  //endfunction: print_results


initial begin
	Driver driver;
	Monitor monitor;
	
	driver = new(io);
	monitor = new(io);
	
	driver.reset_sgn;
	driver.assign_signal;
	
	driver.generate_transaction();
	monitor.transaction_monitor();
	monitor.print_results();
	$finish;
	
end

endmodule: instr_register_test