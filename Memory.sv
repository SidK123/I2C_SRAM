`default_nettype none


module Memory(
  output logic [7:0] data_read
  input logic [7:0] data_write,
  input logic [6:0] address,
  input logic re_weN,
  input logic clk,
  input logic reset_n
);

  logic [127:0][7:0] memory;

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      memory <= 1024'b0;
    end
    else begin
      memory[address] <= (write_enable) ? data_write : memory[address];
    end
  end

  data_out <= (read_enable) ? memory[address] : 'bz;

endmodule : Memory
