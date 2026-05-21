module uart_ref_model #(
    parameter XTAL_CLK = 100_000_000,
    parameter BAUD     = 2400,
    parameter WORD_LEN = 8
)(
    input  wire              sys_clk,
    input  wire              sys_rst,

    // TX interface
    input  wire              xmitH,
    input  wire [WORD_LEN-1:0] xmit_dataH,

    // RX interface
    input  wire              uart_rec_datah,

    // TX outputs
    output reg               uart_xmit_datah,
    output reg               xmit_doneH,
    output reg               xmit_active,

    // RX outputs
    output reg               rec_readyh,
    output reg               rec_busyh,
    output reg [WORD_LEN-1:0] rec_datah,
    output wire              uart_clk_out
);

// ============================================================
// Clock generation
// ============================================================
localparam BAUD_DIV = (XTAL_CLK / (BAUD * 16 * 2)) - 1;

reg        uart_clk;
reg [31:0] clk_cnt;

assign uart_clk_out = uart_clk;

always @(posedge sys_clk or negedge sys_rst) begin
    if (!sys_rst) begin
        uart_clk <= 1'b0;
        clk_cnt  <= 32'd0;
    end
    else begin
        if (clk_cnt == BAUD_DIV) begin
            uart_clk <= ~uart_clk;
            clk_cnt  <= 32'd0;
        end
        else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end
end

// ============================================================
// TX – purely event-driven (posedge xmitH), unchanged
// ============================================================
integer            tx_i;
reg [WORD_LEN-1:0] tx_data;

initial begin
    uart_xmit_datah = 1'b1;
    xmit_doneH      = 1'b1;
    xmit_active     = 1'b0;
end

always @(posedge xmitH) begin
    tx_data         = xmit_dataH;
    xmit_active     = 1'b1;
    xmit_doneH      = 1'b0;

    // START bit
    uart_xmit_datah = 1'b0;
    repeat (16) @(posedge uart_clk);

    // DATA bits – LSB first
    for (tx_i = 0; tx_i < WORD_LEN; tx_i = tx_i + 1) begin
        uart_xmit_datah = tx_data[0];
        tx_data         = tx_data >> 1;
        repeat (16) @(posedge uart_clk);
    end

    // STOP bit
    uart_xmit_datah = 1'b1;
    repeat (16) @(posedge uart_clk);

    xmit_active = 1'b0;
    xmit_doneH  = 1'b1;
end

// ============================================================
// RX – 2-stage synchroniser
// ============================================================
reg [1:0] f_syn;
reg       prev_rx;

always @(posedge uart_clk or negedge sys_rst) begin
    if (!sys_rst) begin
        f_syn   <= 2'b11;
        prev_rx <= 1'b1;
    end
    else begin
        f_syn[1] <= uart_rec_datah;
        f_syn[0] <= f_syn[1];
        prev_rx  <= f_syn[0];
    end
end

// ============================================================
// RX – reset-only block (keeps reset separate from data path)
// ============================================================
always @(negedge sys_rst) begin
    rec_readyh <= 1'b1;
    rec_busyh  <= 1'b0;
    rec_datah  <= {WORD_LEN{1'b0}};
end

// ============================================================
// RX – receive logic
// FIX: separated from reset, and all data bits now sampled
//      with a full repeat(16) so f_syn[0] is always settled
//      before we read it (non-blocking writes in the
//      synchroniser block complete before the next posedge).
// ============================================================
integer            rx_i;
reg [WORD_LEN-1:0] rx_temp;

initial begin
    rec_readyh = 1'b1;
    rec_busyh  = 1'b0;
    rec_datah  = {WORD_LEN{1'b0}};
    rx_temp    = {WORD_LEN{1'b0}};
end

always @(posedge uart_clk) begin
    // Detect falling edge on synchronised RX → start bit
    if (prev_rx == 1'b1 && f_syn[0] == 1'b0) begin

        rec_busyh  <= 1'b1;
        rec_readyh <= 1'b0;

        // --------------------------------------------------
        // Wait to mid-point of start bit (8 more ticks).
        // After these 8 ticks f_syn[0] has been updated by
        // the synchroniser block, so the read below is valid.
        // --------------------------------------------------
        repeat (8) @(posedge uart_clk);

        if (f_syn[0] == 1'b0) begin   // valid start bit

            // ----------------------------------------------
            // DATA BITS – all 8 bits use repeat(16) so that
            // every sample happens at the true mid-bit point
            // and f_syn[0] is always settled.
            // ----------------------------------------------
            for (rx_i = 0; rx_i < WORD_LEN; rx_i = rx_i + 1) begin
                repeat (16) @(posedge uart_clk);
                rx_temp = {f_syn[0], rx_temp[WORD_LEN-1:1]};  // LSB-first shift-in
            end

            // ----------------------------------------------
            // STOP BIT – wait one full bit period then check
            // ----------------------------------------------
            repeat (16) @(posedge uart_clk);

            if (f_syn[0] == 1'b1) begin
                // Valid frame – latch received byte
                rec_datah  <= rx_temp;
                rec_readyh <= 1'b1;
                rec_busyh  <= 1'b0;
            end
            else begin
                // Framing error – output zeros
                rec_datah  <= {WORD_LEN{1'b0}};
                rec_readyh <= 1'b1;
                rec_busyh  <= 1'b0;
            end

        end
        else begin
            // False start (glitch) – return to idle
            rec_busyh  <= 1'b0;
            rec_readyh <= 1'b1;
        end

    end
end

endmodule
