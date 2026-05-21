`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.05.2026 21:39:24
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "baudrate.v"
`include "u_xmit.v"
`include "u_rec.v"

module top(input sys_clk,input sys_rst,input xmitH,input [7:0] xmit_dataH,input uart_rec_datah,output xmit_doneH,output xmit_active,output uart_xmit_datah,output rec_readyh,output rec_busyh,output[7:0] rec_datah,output uart_clk  );
    baudrate#(.xtal(100000000),.baud(2400)) br(.sys_clk(sys_clk),.sys_rst(sys_rst),.uart_clk(uart_clk));
    u_xmit tx(.sys_rst(sys_rst),.uart_clk(uart_clk),.xmitH(xmitH),.xmit_dataH(xmit_dataH),.xmit_doneH(xmit_doneH),.xmit_active(xmit_active),.uart_xmit_datah(uart_xmit_datah));
    u_rec rx(.sys_rst(sys_rst),.uart_clk(uart_clk),.uart_rec_datah(uart_rec_datah),.rec_readyh(rec_readyh),.rec_busyh(rec_busyh),.rec_datah(rec_datah)); 
    
endmodule

