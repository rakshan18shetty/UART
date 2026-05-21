`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.05.2026 14:21:11
// Design Name: 
// Module Name: u_xmit
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


module u_xmit(input sys_rst,input uart_clk,input xmitH,input [7:0] xmit_dataH,output reg xmit_doneH,output reg xmit_active,output reg uart_xmit_datah
    );
    reg [2:0] ct,nt;
    reg [3:0] count;
   reg [3:0] w_count;
    localparam IDLE=0;
    localparam START=1;
    localparam WAIT=2;
    localparam TX=3;
    localparam STOP=4;
    reg [7:0] data;
    
    
    always@(posedge uart_clk or negedge sys_rst)
        begin   
            if(!sys_rst)
                begin
                    ct<=IDLE;
                end
            else 
                begin
                    ct<=nt;
                end
        end
        
     always@(posedge uart_clk or negedge sys_rst)
        begin
       
            if(!sys_rst)
                begin
                    count<=4'b0000;
                end
            else begin
                if(nt==WAIT) begin
                    count<=count+1;
                    end
                else begin
                    count<=4'b0000;
                    end
            end
    end 
     
    always@(*)
        begin
        nt=ct;
            case(ct)
                IDLE: begin 
                    xmit_doneH=1'b1;
                    xmit_active=1'b0;
                    uart_xmit_datah=1'b1;
                    if(xmitH==1'b1)begin
                        nt=START;
                        data=xmit_dataH;end
                    w_count=9;
                end
                START: begin
                    xmit_doneH=1'b0;
                    xmit_active=1'b1;
                    uart_xmit_datah=1'b0;
                    nt=WAIT;
                    end
                WAIT: begin
                    if(w_count==4'd1) begin
                        if(count==4'b1111) begin
                            nt=STOP;
                            end
                        else
                            nt=WAIT;
                    end
                    else if(w_count!=4'd0) begin
                        if(count==4'b1111)begin
                            nt=TX;end
                        else 
                            nt=WAIT;
                    end
                    else begin
                        if(count==4'b1111)
                            nt=IDLE;
                        else
                            nt=WAIT;
                    end
               end
               TX: begin    
                 uart_xmit_datah=data[0];
                 data=data>>1;
                 w_count=w_count-1'b1;
                 nt=WAIT;
                 end
               STOP: begin
                 uart_xmit_datah=1'b1;
                 w_count=4'd0;
                 nt=WAIT;
               end
               default:nt=IDLE;  
                endcase
                end
                
endmodule


