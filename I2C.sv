`default_nettype none

module I2C_Driver(
  input logic  clock, reset_n,
  input logic  read, write,
  input logic  slave_addr, word_addr,
  input logic  received_data,
  output logic SCL,
  output tri   SDA
);

  enum logic [3:0] {IDLE, READ0, READ1, READ2, READ3, READ4, READ5} currState, nextState;

  logic [7:0] message_buff;
  logic [7:0] buffer;
  logic [7:0] read_buffer;
  logic [7:0] count;
  logic load;
  logic done_sending_data;

  assign done_sending_data = (count == 8'd8);

  logic idle, shift_en, count_en, count_clr, clock_propagate;
  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      count <= 8'd0;
    end
    else if(count_en) begin
      count <= count + 1;
    end
    else if(count_clr) begin
      count <= 8'd0;
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      message_buff <= 8'd0;
    end
    else if(load) begin
      message_buff <= read_buffer;
    end
    else if(idle) begin
      message_buff <= 8'd0;
    end
    else if(shift_en) begin
      SDA <= message_buff[0];
      message_buff <= {1'b0, message_buff[7:1]};
    end
  end

 always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
      currState <= IDLE;
    end
    else begin
      currState <= nextState;
    end
  end

  assign SCL = clock;

  always_comb begin
    nextState = IDLE;
    load = 1'b0;
    idle = 1'b0;
    count_clr = 1'b0;
    count_en = 1'b0;
    shift_en = 1'b0;
    unique case(currState)
      IDLE: begin
        nextState = READ0;
        load = 1'b0;
        idle = 1'b1;
        count_clr = 1'b1;
        count_en = 1'b0;
        shift_en = 1'b0;
      end
      READ0: begin
        nextState = READ1;
        load = 1'b1;
        idle = 1'b0;
        count_clr = 1'b0;
        count_en = 1'b0;
        shift_en = 1'b0;
      end
      READ1: begin
        nextState = done_sending_data ? READ2 : READ1;
        load = 1'b0;
        idle = 1'b0;
        count_en = 1'b1;
        count_clr = 1'b0;
        shift_en = 1'b1;
      end
      READ2: begin
        if(SDA == 1'b0) begin
          nextState = READ3;
          load = 1'b0;
          idle = 1'b0;
          count_en = 1'b0;
          count_clr = 1'b0;
          shift_en = 1'b0;
        end
        else begin
          nextState = READ2;
          load = 1'b0;
          idle = 1'b0;
          count_en = 1'b0;
          count_clr = 1'b0;
          shift_en = 1'b0;
        end
      end
      READ3: begin
        nextState = READ4;
        load = 1'b1;
        idle = 1'b0;
        count_en = 1'b0;
        count_clr = 1'b1;
        shift_en = 1'b0;
      end
      READ4: begin
        nextState = done_sending_data ? READ5 : READ4;
        load = 1'b0;
        idle = 1'b0;
        count_en = 1'b1;
        count_clr = 1'b0;
        shift_en = 1'b1;
      end
      READ5: begin
        if(SDA == 1'b0) begin
          nextState = READ6;
          load = 1'b0;
          idle = 1'b0;
          count_en = 1'b1;
          count_clr = 1'b0;
          shift_en = 1'b0;
        end
        else begin
          nextState = READ5;
          load = 1'b0;
          idle = 1'b0;
          count_en = 1'b0;
          count_clr = 1'b0;
          shift_en = 1'b0;
        end
      end
      READ6: begin

      end
    endcase
  end

endmodule : I2C_Driver
