`default_nettype none


module Memory(){
  output logic [7:0] data_read
  input logic [7:0] data_write,
  input logic [9:0] address,
  input logic re_weN,
  input logic clk,
  input logic reset_n
};

  logic [1023:0][7:0] memory;

  always_ff @(posedge clock, negedge reset_n) begin
    data_out <= (read_enable) ? data_memory[{address[17 : 2], 2'b0} +: 32] : 32'bZ;
  end

  always_ff @(posedge clock, negedge reset_n) begin
    memory[address] <= (write_enable) ? data_write : memory[address];
  end

endmodule : Memory
