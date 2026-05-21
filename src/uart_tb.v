`timescale 1ns/1ps
`include "top.v"
`include "uart_ref_model.v"
module uart_tb;


reg sys_clk, sys_rst, xmitH;
reg [7:0] xmit_dataH;
reg uart_rec_datah;

wire dut_xmit_doneH;
wire dut_xmit_active;
wire dut_uart_xmit_datah;
wire dut_rec_readyh;
wire dut_rec_busyh;
wire [7:0] dut_rec_datah;
wire dut_uart_clk;

wire ref_xmit_doneH;
wire ref_xmit_active;
wire ref_uart_xmit_datah;
wire ref_rec_readyh;
wire ref_rec_busyh;
wire [7:0] ref_rec_datah;
wire ref_uart_clk;

integer pass_count = 0;
integer fail_count = 0;
integer test_count = 0;

top dut(
    .sys_clk(sys_clk), .sys_rst(sys_rst),
    .xmitH(xmitH), .xmit_dataH(xmit_dataH),
    .uart_rec_datah(uart_rec_datah),
    .xmit_doneH(dut_xmit_doneH), .xmit_active(dut_xmit_active),
    .uart_xmit_datah(dut_uart_xmit_datah),
    .rec_readyh(dut_rec_readyh), .rec_busyh(dut_rec_busyh),
    .rec_datah(dut_rec_datah)
);
assign dut_uart_clk=dut.uart_clk;

uart_ref_model ref(
    .sys_clk(sys_clk), .sys_rst(sys_rst),
    .xmitH(xmitH), .xmit_dataH(xmit_dataH),
    .uart_rec_datah(uart_rec_datah),
    .xmit_doneH(ref_xmit_doneH), .xmit_active(ref_xmit_active),
    .uart_xmit_datah(ref_uart_xmit_datah),
    .rec_readyh(ref_rec_readyh), .rec_busyh(ref_rec_busyh),
    .rec_datah(ref_rec_datah), .uart_clk_out(ref_uart_clk)
);

initial begin sys_clk = 0; forever #5 sys_clk = ~sys_clk; end

initial begin $dumpfile("uart_tb.vcd"); $dumpvars(0, uart_tb); end

task wait_both_done;
    begin
        wait (dut_xmit_doneH == 1'b1);
        wait (ref_xmit_doneH == 1'b1);
        @(posedge dut_uart_clk);
    end
endtask

function compare_tx(dut_xmit_doneH,dut_xmit_active,dut_uart_xmit_datah,ref_xmit_doneH,ref_xmit_active,ref_uart_xmit_datah);
    begin
        compare_tx = (dut_xmit_doneH     === ref_xmit_doneH)     &&
                     (dut_xmit_active     === ref_xmit_active)     &&
                     (dut_uart_xmit_datah === ref_uart_xmit_datah);
    end
endfunction

function compare_rx(dut_rec_readyh,ref_rec_readyh,dut_rec_busyh,ref_rec_busyh,dut_rec_datah,ref_rec_datah);
    begin
        compare_rx = (dut_rec_readyh === ref_rec_readyh) &&
                     (dut_rec_busyh  === ref_rec_busyh)  &&
                     (dut_rec_datah  === ref_rec_datah);
    end
endfunction

task display_mismatch_tx;
    begin
        $display("  DUT_tx: doneH=%b active=%b serial=%b",
                 dut_xmit_doneH, dut_xmit_active, dut_uart_xmit_datah);
        $display("  REF_tx: doneH=%b active=%b serial=%b",
                 ref_xmit_doneH, ref_xmit_active, ref_uart_xmit_datah);
    end
endtask

task display_mismatch_rx;
    begin
        $display("  DUT_rx: readyh=%b busyh=%b datah=0x%02X",
                 dut_rec_readyh, dut_rec_busyh, dut_rec_datah);
        $display("  REF_rx: readyh=%b busyh=%b datah=0x%02X",
                 ref_rec_readyh, ref_rec_busyh, ref_rec_datah);
    end
endtask

task apply_test_tx;
    input        xmith;
    input [7:0]  xmit_datah;
    input [80*8:1] test_name;
    begin
        wait (dut_xmit_doneH == 1'b1);
        wait (ref_xmit_doneH == 1'b1);
        @(posedge dut_uart_clk);
        xmitH = xmith; xmit_dataH = xmit_datah;
        @(posedge dut_uart_clk);
        xmitH = 0;
        wait_both_done;
        test_count = test_count + 1;
        if (compare_tx(dut_xmit_doneH,ref_xmit_doneH,dut_xmit_active,ref_xmit_active,dut_uart_xmit_datah,ref_uart_xmit_datah)) begin
            $display("[PASS] %s xmit_dataH=0x%02X", test_name, xmit_datah);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s xmit_dataH=0x%02X", test_name, xmit_datah);
            display_mismatch_tx;
            fail_count = fail_count + 1;
        end
    end
endtask

task send_frame;
    input [7:0] data;
    integer b;
    reg [7:0] shift;
    begin
        shift = data;
        uart_rec_datah = 0;
        repeat(16) @(posedge dut_uart_clk);
        for (b = 0; b < 8; b = b + 1) begin
            uart_rec_datah = shift[0];
            shift = shift >> 1;
            repeat(16) @(posedge dut_uart_clk);
        end
        uart_rec_datah = 1;
        repeat(16) @(posedge dut_uart_clk);
    end
endtask

task apply_test_rx;
    input [7:0]    data;
    input [80*8:1] test_name;
    begin
        send_frame(data);
        wait (dut_rec_readyh == 1'b1);
        wait (ref_rec_readyh == 1'b1);
        repeat(4) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (compare_rx(dut_rec_readyh,ref_rec_readyh,dut_rec_busyh,ref_rec_busyh,dut_rec_datah,ref_rec_datah)) begin
            $display("[PASS] %s data=0x%02X", test_name, data);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s data=0x%02X", test_name, data);
            display_mismatch_rx;
            fail_count = fail_count + 1;
        end
    end
endtask

task test_transmitter;
    begin
        apply_test_tx(1, 8'hA5, "TX: normal byte 0xA5");
        apply_test_tx(1, 8'h00, "TX: all-zeros");
        apply_test_tx(1, 8'hFF, "TX: all-ones");
        apply_test_tx(1, 8'h55, "TX: alternating 0x55");
        apply_test_tx(1, 8'hAA, "TX: alternating 0xAA");
        apply_test_tx(1, 8'h3C, "TX: active/done complement");

        test_count = test_count + 1;
        if (dut_uart_xmit_datah === 1'b1) begin
            $display("[PASS] TX: serial line idle=1");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TX: serial line idle=1");
            fail_count = fail_count + 1;
        end

        xmitH = 0; xmit_dataH = 8'hDE;
        repeat(10) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (dut_xmit_doneH === 1'b1 && dut_xmit_active === 1'b0) begin
            $display("[PASS] TX: xmitH=0 does not start TX");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TX: xmitH=0 does not start TX");
            fail_count = fail_count + 1;
        end

        wait (dut_xmit_doneH == 1'b1);
        @(posedge dut_uart_clk);
        xmitH = 1; xmit_dataH = 8'hAA;
        @(posedge dut_uart_clk);
        xmitH = 0;
        repeat(50) @(posedge dut_uart_clk);
        xmit_dataH = 8'hFF;
        wait_both_done;
        repeat(40) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (dut_rec_datah === 8'hAA) begin
            $display("[PASS] TX: mid-TX data change ignored (got 0xAA)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TX: mid-TX data change ignored (got 0x%02X)", dut_rec_datah);
            fail_count = fail_count + 1;
        end
    end
endtask

task test_receiver;
    integer b;
    reg [7:0] fdata;
    begin
        apply_test_rx(8'h45, "RX: normal byte 0x45");
        apply_test_rx(8'h00, "RX: all-zeros");
        apply_test_rx(8'hFF, "RX: all-ones");
        apply_test_rx(8'hA5, "RX: 0xA5");

        uart_rec_datah = 1;
        repeat(10) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (dut_rec_readyh === 1'b1 && dut_rec_busyh === 1'b0) begin
            $display("[PASS] RX: idle readyh=1 busyh=0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RX: idle readyh=1 busyh=0");
            display_mismatch_rx;
            fail_count = fail_count + 1;
        end

        uart_rec_datah = 1;
        repeat(40) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (dut_rec_busyh === 1'b0 && dut_rec_readyh === 1'b1) begin
            $display("[PASS] RX: no start bit stays idle");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RX: no start bit stays idle");
            display_mismatch_rx;
            fail_count = fail_count + 1;
        end

        fdata = 8'h55;
        uart_rec_datah = 0;
        repeat(16) @(posedge dut_uart_clk);
        for (b = 0; b < 8; b = b + 1) begin
            uart_rec_datah = fdata[0];
            fdata = fdata >> 1;
            repeat(16) @(posedge dut_uart_clk);
        end
        uart_rec_datah = 0;
        repeat(16) @(posedge dut_uart_clk);
        uart_rec_datah = 1;
        repeat(20) @(posedge dut_uart_clk);
        test_count = test_count + 1;
        if (dut_rec_datah === ref_rec_datah) begin
            $display("[PASS] RX: framing error dut=0x%02X ref=0x%02X",
                     dut_rec_datah, ref_rec_datah);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RX: framing error dut=0x%02X ref=0x%02X",
                     dut_rec_datah, ref_rec_datah);
            fail_count = fail_count + 1;
        end

        test_count = test_count + 1;
        if (dut_xmit_active !== dut_xmit_doneH) begin
            $display("[PASS] TX: active != doneH");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TX: active == doneH at same time");
            fail_count = fail_count + 1;
        end

        test_count = test_count + 1;
        if (dut_rec_readyh !== dut_rec_busyh) begin
            $display("[PASS] RX: readyh != busyh");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RX: readyh == busyh at same time");
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    sys_rst = 0; xmitH = 0;
    xmit_dataH = 8'h00; uart_rec_datah = 1;
    #200; sys_rst = 1;
    @(posedge dut_uart_clk);
    @(posedge dut_uart_clk);
    $display("--- Testing Transmitter ---");
    test_transmitter;
    $display("--- Testing Receiver ---");
    uart_rec_datah = 1;
    test_receiver;
    $display("-------------------------------");
    $display("Total : %0d", test_count);
    $display("Pass  : %0d", pass_count);
    $display("Fail  : %0d", fail_count);
    if (fail_count == 0)
        $display("ALL CASES PASSED");
    else
        $display("SOME CASES FAILED");
    $display("-------------------------------");
    #100; $finish;
end

initial begin
    #50_000_000;
    $display("[WATCHDOG] Timeout!");
    $finish;
end

endmodule

