`default_nettype none

module I2C_Master 
(
  input logic clock,
  input logic A0, A1, A2, 
  input logic reset_n,
  input logic SCL,
  inout tri   SDA
);

  logic sda_reg, scl_reg;
  
  always_ff @(posedge clock) begin
    sda_reg <= SDA;
    scl_reg <= SCL;
  end 

  logic sda_posedge, sda_negedge;
  assign sda_posedge = SDA & ~sda_reg;
  assign sda_negedge = ~SDA & sda_reg;

  logic scl_posedge, scl_negedge;
  assign scl_posedge = SCL & ~scl_reg;
  assign scl_negedge = ~SCL & scl_reg;

  logic start_condition;
  logic stop_condition;

  assign start_condition = sda_negedge & (SCL & scl_reg);
  assign stop_condition =  sda_posedge & (SCL & scl_reg);

  logic [2:0] device_address;
  assign device_address = { 4'd0, A2, A1, A0 };

  logic       slave_address_received;
  logic [3:0] slave_address_count;
  logic       slave_address_count_clr;
  logic       slave_address_count_en;
  logic [6:0] slave_address;
  logic       slave_address_shift_en; 

  assign slave_address_received = slave_address_count == 4'd7;

  logic       memory_address_received;
  logic [3:0] memory_address_counter;
  logic       memory_address_count_clr;
  logic       memory_address_count_en;
  logic [6:0] memory_address;
  logic       memory_address_shift_en; 

  assign memory_address_received = (memory_address_count == 4'd8);

  logic       data_received;
  logic [3:0] data_counter;
  logic       data_count_clr;
  logic       data_count_en;
  logic [7:0] data;
  logic       data_shift_en; 

  logic [3:0] data_out_counter;
  logic       data_send_en;
  logic       data_sent;

  assign data_sent     = (data_out_counter == 4'd8);

  assign data_received = (data_counter == 4'd8);

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      memory_address_counter <= 8'd0;
      slave_address_count    <= 8'd0;
      data_out_counter       <= 8'd0;
    end else if (slave_address_count_en && scl_posedge) begin
      slave_address_count <= slave_address_count + 1;
    end else if (slave_address_count_clr && scl_posedge) begin
      slave_address_count <= 8'd0;
    end else if(memory_address_count_en && scl_posedge) begin
      memory_address_counter <= memory_address_counter + 1;
    end else if(memory_address_count_clr && scl_posedge) begin
      memory_address_counter <= 8'd0; 
    end else if (data_count_en && scl_posedge) begin
      data_counter <= data_counter + 1;
    end else if (data_count_clr && scl_posedge) begin
      data_counter <= 8'd0; 
    end else if (data_send_en && scl_posedge) begin
      data_out_counter <= data_out_counter + 1;
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      memory_address <= 7'd0;
      slave_address  <= 7'd0;
    end else if (slave_address_shift_en && scl_posedge) begin
      slave_address <= { slave_address[5:0] , SDA };
    end else if (data_shift_en) begin
      data <= { data[6:0], SDA }; 
    end else if(memory_address_shift_en && scl_posedge) begin
      memory_address <= { memory_address[5:0], SDA };
    end
  end

  logic [7:0] mem_read_data;
  logic [7:0] mem_write_data;

  logic read_write_enable;

  Memory memory_module
  (
    .data_read(mem_read_data),
    .data_write(data),
    .address(memory_address),
    .re_weN(read_write_enable),
    .clk(clock),
    .reset_n(reset_n)
  );

  enum logic [3:0] {IDLE, START, INT1, ACK1, ACK2, REG1, RW_INTERMEDIATE, RACK1, RACK2, READ1, READ2, WRITE1, WRITE2, WACK1, WACK2, WACK3, STOP} currState, nextState;

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      currState <= IDLE;
    end
    else begin
      currState <= nextState;
    end
  end

  always_comb begin
    SDA = 1'bz;
    slave_address_shift_en  = 1'b0;
    memory_address_shift_en = 1'b0; 
    data_shift_en = 1'b0;
    slave_address_count_clr = 1'b0;
    memory_address_count_clr = 1'b0;
    data_count_clr = 1'b0;
    slave_address_count_en = 1'b0;
    memory_address_count_en = 1'b0;
    data_count_en = 1'b0;
    unique case(currState)
      IDLE: begin
        nextState = start_condition ? START : IDLE;
        slave_address_count_clr = 1'b1;
        memory_address_count_clr = 1'b1;
        data_count_clr = 1'b1;
      end 
      START: begin
        nextState = (slave_address_received & scl_negedge) ? INT1 : START; 
        slave_address_shift_en = 1'b1; 
        slave_address_count_en = 1'b1; 
      end
      INT1: begin
        nextState = (scl_negedge) ? ACK1 : INT1;
      end 
      ACK1: begin
        nextState = REG1;
        SDA = 1'b1;
      end 
      REG1: begin
        nextState = (memory_address_received & scl_negedge) ? ACK2 : REG1;
        memory_address_shift_en = 1'b1;
        memory_address_count_en = 1'b1;
      end 
      ACK2: begin
        nextState = scl_negedge ? RW_INTERMEDIATE : ACK2;
        SDA = 1'b0;
      end
      RW_INTERMEDIATE: begin
        nextState = start_condition ? READ1 : WRITE1; /* TODO: This is most likely incorrect, go ahead and fix it down the line. */
        data_shift_en = 1'b1;
        data_count_en = 1'b1;
      end 
      WRITE1: begin
        nextState = (data_received & scl_negedge) ? WACK3 : WRITE1;
        data_shift_en = 1'b1;
        data_count_en = 1'b1;
      end 
      WACK3: begin
        nextState = scl_negedge ? STOP : WACK3;
        read_write_enable = 1'b0; 
        SDA = 1'b0; /* TODO: Fix the ACKs, they should be holding SDA low from posedge to negedge of SCL. */
      end 
      READ1: begin
        nextState = (memory_address_received & scl_negedge) ? RACK2 : READ1;
        memory_address_shift_en = 1'b1;
        memory_address_count_en = 1'b1;
      end
      READ2: begin
        nextState = (data_sent & scl_negedge) ? NACK1 : READ2;
        read_write_enable = 1'b1;
        data_send_en = 1'b1;
        SDA = mem_read_data[data_out_counter];
      end
      NACK1: begin
        nextState = scl_negedge ? STOP : NACK1;
        SDA = 1'b1;
      end
      STOP: begin
        nextState = stop_condition ? IDLE : STOP;
      end
    endcase
  end

endmodule : I2C_Master 
