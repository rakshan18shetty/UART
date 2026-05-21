`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.05.2026 20:46:57
// Design Name: 
// Module Name: baudrate
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


module baudrate#(parameter xtal=100000000,parameter baud=2400)(input sys_clk,input sys_rst,output reg uart_clk);
    
    reg [31:0] count;
    always@(posedge sys_clk or negedge sys_rst) 
        begin
            if(!sys_rst)
                begin
                    count<=0;
                    uart_clk<=1'b0;
                end
            else 
                begin
                    if(count==($clog2(xtal/(baud*16*2))))
                        begin
                            uart_clk<=~uart_clk;
                            count<=0;
                        end
                    else begin
                        count<=count+1;
                        uart_clk<=uart_clk;
                end
        end
        end
                            
endmodule

