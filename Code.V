`timescale 1ns / 1ps

module top(
    input clk,
    input start,
    input [7:0] txin,
    output reg tx, 
    input rx,
    output [7:0] rxout,
    output rxdone, 
    output txdone,
    output parity_error
);

parameter clk_value = 100_000;
parameter baud = 9600;
parameter wait_count = clk_value / baud;

////////////////////////////////////
// Baud Rate Generator
reg bitDone = 0;
integer count = 0;

always @(posedge clk) begin
    if (count == wait_count) begin
        bitDone <= 1'b1;
        count <= 0;
    end else begin
        count <= count + 1;
        bitDone <= 1'b0;
    end
end

////////////////////////////////////
// TX Logic (Transmitter)
parameter IDLE = 0, SEND = 1;
reg [1:0] tx_state = IDLE;

reg [10:0] txData; // Format: {stop, parity, data[7:0], start}
reg [3:0] txIndex = 0;

function parity_even;
    input [7:0] data;
    begin
        parity_even = ^data; // XOR all bits: 0 = even, 1 = odd parity
    end
endfunction

always @(posedge clk) begin
    case (tx_state)
        IDLE: begin
            tx <= 1'b1; // UART idle line
            txIndex <= 0;
            if (start) begin
                txData <= {1'b1, parity_even(txin), txin, 1'b0}; // framing
                tx_state <= SEND;
            end
        end
        SEND: begin
            tx <= txData[txIndex];
            if (bitDone) begin
                if (txIndex == 10) begin
                    tx_state <= IDLE;
                    tx <= 1'b1;
                end else begin
                    txIndex <= txIndex + 1;
                end
            end
        end
    endcase
end

assign txdone = (tx_state == IDLE && txIndex == 10 && bitDone);

////////////////////////////////////
// RX Logic (Receiver)
parameter RIDLE = 0, RWAIT = 1, RECV = 2;
reg [1:0] rx_state = RIDLE;

reg [10:0] rxData;
reg [3:0] rxIndex = 0;
reg [15:0] rcount = 0;

reg [7:0] rxout_reg = 0;
reg rxdone_reg = 0;
reg parity_error_reg = 0;

always @(posedge clk) begin
    case (rx_state)
        RIDLE: begin
            rxIndex <= 0;
            rcount <= 0;
            rxdone_reg <= 0;
            if (rx == 1'b0) begin // Start bit detected
                rx_state <= RWAIT;
            end
        end
        RWAIT: begin
            if (rcount < (wait_count >> 1)) begin
                rcount <= rcount + 1;
            end else begin
                rcount <= 0;
                rxData[rxIndex] <= rx;
                rxIndex <= rxIndex + 1;
                rx_state <= RECV;
            end
        end
        RECV: begin
            if (bitDone) begin
                rxData[rxIndex] <= rx;
                rxIndex <= rxIndex + 1;
                if (rxIndex == 10) begin
                    rx_state <= RIDLE;
                    rxout_reg <= rxData[8:1]; // Extract data bits
                    rxdone_reg <= 1;

                    // Parity check
                    if (parity_even(rxData[8:1]) !== rxData[9]) begin
                        parity_error_reg <= 1;
                    end else begin
                        parity_error_reg <= 0;
                    end
                end
            end
        end
    endcase
end

assign rxout = rxout_reg;
assign rxdone = rxdone_reg;
assign parity_error = parity_error_reg;

endmodule
