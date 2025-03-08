`default_nettype none

module I2C_Slave 
(
  input logic  clock, reset_n,
  input logic  read, write,
  input logic  slave_addr, word_addr,
  input logic  received_data,
  output logic SCL,
  output tri   SDA
);

  logic [6:0] device_address;
  assign device_address = 7'b0000001;


  logic [3:0] slave_address_counter;
  logic       slave_address_received;
  logic       slave_address_count_en;
  logic       slave_address_count_clr;
  logic       slave_address_shift_en;
  logic       slave_address_clr;
  logic [6:0] slave_address_on_bus;

  assign slave_address_received = slave_address_count == 4'd7;

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      slave_address_count <= 8'd0;
    end
    else if(slave_address_count_en) begin
      slave_address_count <= slave_address_count + 1;
    end
    else if(slave_address_count_clr) begin
      slave_address_count <= 8'd0;
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      slave_address_on_bus <= 7'd0;
    end
    else if(slave_address_shift_en) begin
      slave_address_on_bus <= {slave_address_on_bus[5:0], SDA};
    end
    else if(slave_address_clr) begin
      slave_address_on_bus <= 7'd0;
    end
  end

  logic [3:0] memory_address_counter;
  logic       memory_address_received;
  logic       memory_address_count_en;
  logic       memory_address_count_clr;
  logic       memory_address_shift_en;
  logic       memory_address_clr;
  logic [6:0] memory_address_on_bus;

  assign memory_address_received = memory_address_count = 4'd7;

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      memory_address_counter <= 8'd0;
    end
    else if(memory_address_count_en) begin
      memory_address_counter <= memory_address_counter + 1;
    end
    else if(memory_address_count_clr) begin
      memory_address_counter <= 8'd0;
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      memory_address_on_bus <= 7'd0;
    end
    else if(memory_address_shift_en) begin
      memory_address_on_bus <= {memory_address_on_bus [5:0], SDA};
    end
    else if(memory_address_clr) begin
      memory_address_on_bus <= 7'd0;
    end
  end

  logic [7:0] mem_read_data;
  logic [7:0] mem_write_data;

  Memory memory_module
  (
    .data_read(mem_read_data),
    .data_write(mem_write_data),
    .address(memory_address_on_bus),
    .re_weN(read_write_enable),
    .clk(clock),
    .reset_n(reset_n)
  );

  logic start_bit;

  enum logic [3:0] {IDLE, START, READ1, WRITE1} currState, nextState;

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      currState <= IDLE;
    end
    else begin
      currState <= nextState;
    end
  end

  always_comb begin
    unique case(currState)
      IDLE: begin
        nextState = start_bit ? START : IDLE;
      end
  end

endmodule : I2C_Slave 
