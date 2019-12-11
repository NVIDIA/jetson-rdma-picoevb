/*
 * Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

`timescale 1ns / 1ps

module top(
    // PCIe
    input perst_n,
    input refclk_p,
    input refclk_n,
    input [7:0] per_p,
    input [7:0] per_n,
    output [7:0] pet_p,
    output [7:0] pet_n,
    // DDR4
    input ddr_sys_clk_p,
    input ddr_sys_clk_n,
    output [16:0] ddr_adr,
    output [1:0] ddr_ba,
    output ddr_cke,
    output ddr_cs_n,
    inout [7:0] ddr_dm_dbi_n,
    inout [63:0] ddr_dq,
    inout [7:0] ddr_dqs_c,
    inout [7:0] ddr_dqs_t,
    output ddr_odt,
    output ddr_bg,
    output ddr_par,
    output ddr_reset_n,
    output ddr_ten,
    output ddr_act_n,
    output ddr_ck_c,
    output ddr_ck_t,
    // IO
    output [7:0] leds,
    input [7:0] switches,
    inout [7:0] iocon
);
    assign ddr_par = 1'b0;
    assign ddr_ten = 1'b0;

    wire perst_n_buf;
    IBUF pcie_rst_ibuf(
        .I(perst_n),
        .O(perst_n_buf)
    );

    wire sys_clk;
    wire sys_clk_gt;
    IBUFDS_GTE3 pcie_clk_ibuf(
        .I(refclk_p),
        .IB(refclk_n),
        .CEB(1'b0),
        .O(sys_clk_gt),
        .ODIV2(sys_clk)
    );

    wire user_lnk_up;
    wire axi_aclk;
    wire axi_aresetn;
    wire irq_gpio0;
    wire irq_gpio1;
    wire irq_ddr4 = 1'b0;
    wire usr_irq_ack;
    wire msi_enable;
    wire [2:0] msi_vector_width;
    // XDMA -> DDR4 data
    wire xdma_axi_awready;
    wire xdma_axi_wready;
    wire [1:0] xdma_axi_bid;
    wire [1:0] xdma_axi_bresp;
    wire xdma_axi_bvalid;
    wire xdma_axi_arready;
    wire [1:0] xdma_axi_rid;
    wire [255:0] xdma_axi_rdata;
    wire [1:0] xdma_axi_rresp;
    wire xdma_axi_rlast;
    wire xdma_axi_rvalid;
    wire [1:0] xdma_axi_awid;
    wire [63:0] xdma_axi_awaddr;
    wire [7:0] xdma_axi_awlen;
    wire [2:0] xdma_axi_awsize;
    wire [1:0] xdma_axi_awburst;
    wire [2:0] xdma_axi_awprot;
    wire xdma_axi_awvalid;
    wire xdma_axi_awlock;
    wire [3:0] xdma_axi_awcache;
    wire [255:0] xdma_axi_wdata;
    wire [31:0] xdma_axi_wstrb;
    wire xdma_axi_wlast;
    wire xdma_axi_wvalid;
    wire xdma_axi_bready;
    wire [1:0] xdma_axi_arid;
    wire [63:0] xdma_axi_araddr;
    wire [7:0] xdma_axi_arlen;
    wire [2:0] xdma_axi_arsize;
    wire [1:0] xdma_axi_arburst;
    wire [2:0] xdma_axi_arprot;
    wire xdma_axi_arvalid;
    wire xdma_axi_arlock;
    wire [3:0] xdma_axi_arcache;
    wire xdma_axi_rready;
    // XDMA -> AXI-Lite XBAR
    wire [31:0] xdma_axil_awaddr;
    wire [2:0] xdma_axil_awprot;
    wire xdma_axil_awvalid;
    wire xdma_axil_awready;
    wire [31:0] xdma_axil_wdata;
    wire [3:0] xdma_axil_wstrb;
    wire xdma_axil_wvalid;
    wire xdma_axil_wready;
    wire xdma_axil_bvalid;
    wire [1:0] xdma_axil_bresp;
    wire xdma_axil_bready;
    wire [31:0] xdma_axil_araddr;
    wire [2:0] xdma_axil_arprot;
    wire xdma_axil_arvalid;
    wire xdma_axil_arready;
    wire [31:0] xdma_axil_rdata;
    wire [1:0] xdma_axil_rresp;
    wire xdma_axil_rvalid;
    wire xdma_axil_rready;
    xdma_0 xdma(
        .sys_clk(sys_clk),
        .sys_clk_gt(sys_clk_gt),
        .sys_rst_n(perst_n_buf),
        .user_lnk_up(user_lnk_up),
        .pci_exp_rxp(per_p),
        .pci_exp_rxn(per_n),
        .pci_exp_txp(pet_p),
        .pci_exp_txn(pet_n),
        .axi_aclk(axi_aclk),
        .axi_aresetn(axi_aresetn),
        .usr_irq_req(irq_gpio0 | irq_gpio1 | irq_ddr4),
        .usr_irq_ack(usr_irq_ack),
        .msi_enable(msi_enable),
        .msi_vector_width(msi_vector_width),
        .m_axi_awready(xdma_axi_awready),
        .m_axi_wready(xdma_axi_wready),
        .m_axi_bid(xdma_axi_bid),
        .m_axi_bresp(xdma_axi_bresp),
        .m_axi_bvalid(xdma_axi_bvalid),
        .m_axi_arready(xdma_axi_arready),
        .m_axi_rid(xdma_axi_rid),
        .m_axi_rdata(xdma_axi_rdata),
        .m_axi_rresp(xdma_axi_rresp),
        .m_axi_rlast(xdma_axi_rlast),
        .m_axi_rvalid(xdma_axi_rvalid),
        .m_axi_awid(xdma_axi_awid),
        .m_axi_awaddr(xdma_axi_awaddr),
        .m_axi_awlen(xdma_axi_awlen),
        .m_axi_awsize(xdma_axi_awsize),
        .m_axi_awburst(xdma_axi_awburst),
        .m_axi_awprot(xdma_axi_awprot),
        .m_axi_awvalid(xdma_axi_awvalid),
        .m_axi_awlock(xdma_axi_awlock),
        .m_axi_awcache(xdma_axi_awcache),
        .m_axi_wdata(xdma_axi_wdata),
        .m_axi_wstrb(xdma_axi_wstrb),
        .m_axi_wlast(xdma_axi_wlast),
        .m_axi_wvalid(xdma_axi_wvalid),
        .m_axi_bready(xdma_axi_bready),
        .m_axi_arid(xdma_axi_arid),
        .m_axi_araddr(xdma_axi_araddr),
        .m_axi_arlen(xdma_axi_arlen),
        .m_axi_arsize(xdma_axi_arsize),
        .m_axi_arburst(xdma_axi_arburst),
        .m_axi_arprot(xdma_axi_arprot),
        .m_axi_arvalid(xdma_axi_arvalid),
        .m_axi_arlock(xdma_axi_arlock),
        .m_axi_arcache(xdma_axi_arcache),
        .m_axi_rready(xdma_axi_rready),
        .m_axil_awaddr(xdma_axil_awaddr),
        .m_axil_awprot(xdma_axil_awprot),
        .m_axil_awvalid(xdma_axil_awvalid),
        .m_axil_awready(xdma_axil_awready),
        .m_axil_wdata(xdma_axil_wdata),
        .m_axil_wstrb(xdma_axil_wstrb),
        .m_axil_wvalid(xdma_axil_wvalid),
        .m_axil_wready(xdma_axil_wready),
        .m_axil_bvalid(xdma_axil_bvalid),
        .m_axil_bresp(xdma_axil_bresp),
        .m_axil_bready(xdma_axil_bready),
        .m_axil_araddr(xdma_axil_araddr),
        .m_axil_arprot(xdma_axil_arprot),
        .m_axil_arvalid(xdma_axil_arvalid),
        .m_axil_arready(xdma_axil_arready),
        .m_axil_rdata(xdma_axil_rdata),
        .m_axil_rresp(xdma_axil_rresp),
        .m_axil_rvalid(xdma_axil_rvalid),
        .m_axil_rready(xdma_axil_rready),
        .int_qpll1lock_out(), // Debug port so unconnected; output [0:0]
        .int_qpll1outrefclk_out(), // Debug port so unconnected; output [0:0]
        .int_qpll1outclk_out() // Debug port so unconnected; output [0:0]
    );

    // AXI CDC -> DDR4 data
    wire axi_cdc_aclk;
    wire axi_cdc_aresetn;
    wire axi_cdc_awready;
    wire axi_cdc_wready;
    wire [1:0] axi_cdc_bid;
    wire [1:0] axi_cdc_bresp;
    wire axi_cdc_bvalid;
    wire axi_cdc_arready;
    wire [1:0] axi_cdc_rid;
    wire [255:0] axi_cdc_rdata;
    wire [1:0] axi_cdc_rresp;
    wire axi_cdc_rlast;
    wire axi_cdc_rvalid;
    wire [1:0] axi_cdc_awid;
    wire [30:0] axi_cdc_awaddr;
    wire [7:0] axi_cdc_awlen;
    wire [2:0] axi_cdc_awsize;
    wire [1:0] axi_cdc_awburst;
    wire [2:0] axi_cdc_awprot;
    wire axi_cdc_awvalid;
    wire axi_cdc_awlock;
    wire [3:0] axi_cdc_awcache;
    wire [255:0] axi_cdc_wdata;
    wire [31:0] axi_cdc_wstrb;
    wire axi_cdc_wlast;
    wire axi_cdc_wvalid;
    wire axi_cdc_bready;
    wire [1:0] axi_cdc_arid;
    wire [30:0] axi_cdc_araddr;
    wire [7:0] axi_cdc_arlen;
    wire [2:0] axi_cdc_arsize;
    wire [1:0] axi_cdc_arburst;
    wire [2:0] axi_cdc_arprot;
    wire axi_cdc_arvalid;
    wire axi_cdc_arlock;
    wire [3:0] axi_cdc_arcache;
    wire axi_cdc_rready;
    axi_clock_converter_0 axi_cdc(
      .s_axi_aclk(axi_aclk),
      .s_axi_aresetn(axi_aresetn),
      .s_axi_awid(xdma_axi_awid),
      .s_axi_awaddr(xdma_axi_awaddr[30:0]),
      .s_axi_awlen(xdma_axi_awlen),
      .s_axi_awsize(xdma_axi_awsize),
      .s_axi_awburst(xdma_axi_awburst),
      .s_axi_awlock(xdma_axi_awlock),
      .s_axi_awcache(xdma_axi_awcache),
      .s_axi_awprot(xdma_axi_awprot),
      .s_axi_awregion(4'h0),
      .s_axi_awqos(4'h0),
      .s_axi_awvalid(xdma_axi_awvalid),
      .s_axi_awready(xdma_axi_awready),
      .s_axi_wdata(xdma_axi_wdata),
      .s_axi_wstrb(xdma_axi_wstrb),
      .s_axi_wlast(xdma_axi_wlast),
      .s_axi_wvalid(xdma_axi_wvalid),
      .s_axi_wready(xdma_axi_wready),
      .s_axi_bid(xdma_axi_bid),
      .s_axi_bresp(xdma_axi_bresp),
      .s_axi_bvalid(xdma_axi_bvalid),
      .s_axi_bready(xdma_axi_bready),
      .s_axi_arid(xdma_axi_arid),
      .s_axi_araddr(xdma_axi_araddr[30:0]),
      .s_axi_arlen(xdma_axi_arlen),
      .s_axi_arsize(xdma_axi_arsize),
      .s_axi_arburst(xdma_axi_arburst),
      .s_axi_arlock(xdma_axi_arlock),
      .s_axi_arcache(xdma_axi_arcache),
      .s_axi_arprot(xdma_axi_arprot),
      .s_axi_arregion(4'h0),
      .s_axi_arqos(4'h0),
      .s_axi_arvalid(xdma_axi_arvalid),
      .s_axi_arready(xdma_axi_arready),
      .s_axi_rid(xdma_axi_rid),
      .s_axi_rdata(xdma_axi_rdata),
      .s_axi_rresp(xdma_axi_rresp),
      .s_axi_rlast(xdma_axi_rlast),
      .s_axi_rvalid(xdma_axi_rvalid),
      .s_axi_rready(xdma_axi_rready),
      .m_axi_aclk(axi_cdc_aclk),
      .m_axi_aresetn(axi_cdc_aresetn),
      .m_axi_awid(axi_cdc_awid),
      .m_axi_awaddr(axi_cdc_awaddr),
      .m_axi_awlen(axi_cdc_awlen),
      .m_axi_awsize(axi_cdc_awsize),
      .m_axi_awburst(axi_cdc_awburst),
      .m_axi_awlock(axi_cdc_awlock),
      .m_axi_awcache(axi_cdc_awcache),
      .m_axi_awprot(axi_cdc_awprot),
      .m_axi_awregion(),
      .m_axi_awqos(),
      .m_axi_awvalid(axi_cdc_awvalid),
      .m_axi_awready(axi_cdc_awready),
      .m_axi_wdata(axi_cdc_wdata),
      .m_axi_wstrb(axi_cdc_wstrb),
      .m_axi_wlast(axi_cdc_wlast),
      .m_axi_wvalid(axi_cdc_wvalid),
      .m_axi_wready(axi_cdc_wready),
      .m_axi_bid(axi_cdc_bid),
      .m_axi_bresp(axi_cdc_bresp),
      .m_axi_bvalid(axi_cdc_bvalid),
      .m_axi_bready(axi_cdc_bready),
      .m_axi_arid(axi_cdc_arid),
      .m_axi_araddr(axi_cdc_araddr),
      .m_axi_arlen(axi_cdc_arlen),
      .m_axi_arsize(axi_cdc_arsize),
      .m_axi_arburst(axi_cdc_arburst),
      .m_axi_arlock(axi_cdc_arlock),
      .m_axi_arcache(axi_cdc_arcache),
      .m_axi_arprot(axi_cdc_arprot),
      .m_axi_arregion(),
      .m_axi_arqos(),
      .m_axi_arvalid(axi_cdc_arvalid),
      .m_axi_arready(axi_cdc_arready),
      .m_axi_rid(axi_cdc_rid),
      .m_axi_rdata(axi_cdc_rdata),
      .m_axi_rresp(axi_cdc_rresp),
      .m_axi_rlast(axi_cdc_rlast),
      .m_axi_rvalid(axi_cdc_rvalid),
      .m_axi_rready(axi_cdc_rready)
    );

    // XBAR -> GPIO0
    wire [31:0] xbar_axil_gpio0_awaddr;
    wire [2:0] xbar_axil_gpio0_awprot;
    wire xbar_axil_gpio0_awvalid;
    wire xbar_axil_gpio0_awready;
    wire [31:0] xbar_axil_gpio0_wdata;
    wire [3:0] xbar_axil_gpio0_wstrb;
    wire xbar_axil_gpio0_wvalid;
    wire xbar_axil_gpio0_wready;
    wire xbar_axil_gpio0_bvalid;
    wire [1:0] xbar_axil_gpio0_bresp;
    wire xbar_axil_gpio0_bready;
    wire [31:0] xbar_axil_gpio0_araddr;
    wire [2:0] xbar_axil_gpio0_arprot;
    wire xbar_axil_gpio0_arvalid;
    wire xbar_axil_gpio0_arready;
    wire [31:0] xbar_axil_gpio0_rdata;
    wire [1:0] xbar_axil_gpio0_rresp;
    wire xbar_axil_gpio0_rvalid;
    wire xbar_axil_gpio0_rready;
    // XBAR -> GPIO1
    wire [31:0] xbar_axil_gpio1_awaddr;
    wire [2:0] xbar_axil_gpio1_awprot;
    wire xbar_axil_gpio1_awvalid;
    wire xbar_axil_gpio1_awready;
    wire [31:0] xbar_axil_gpio1_wdata;
    wire [3:0] xbar_axil_gpio1_wstrb;
    wire xbar_axil_gpio1_wvalid;
    wire xbar_axil_gpio1_wready;
    wire xbar_axil_gpio1_bvalid;
    wire [1:0] xbar_axil_gpio1_bresp;
    wire xbar_axil_gpio1_bready;
    wire [31:0] xbar_axil_gpio1_araddr;
    wire [2:0] xbar_axil_gpio1_arprot;
    wire xbar_axil_gpio1_arvalid;
    wire xbar_axil_gpio1_arready;
    wire [31:0] xbar_axil_gpio1_rdata;
    wire [1:0] xbar_axil_gpio1_rresp;
    wire xbar_axil_gpio1_rvalid;
    wire xbar_axil_gpio1_rready;

    axi_crossbar_0 xbar(
      .aclk(axi_aclk),
      .aresetn(axi_aresetn),
      .s_axi_awaddr(xdma_axil_awaddr),
      .s_axi_awprot(xdma_axil_awprot),
      .s_axi_awvalid(xdma_axil_awvalid),
      .s_axi_awready(xdma_axil_awready),
      .s_axi_wdata(xdma_axil_wdata),
      .s_axi_wstrb(xdma_axil_wstrb),
      .s_axi_wvalid(xdma_axil_wvalid),
      .s_axi_wready(xdma_axil_wready),
      .s_axi_bresp(xdma_axil_bresp),
      .s_axi_bvalid(xdma_axil_bvalid),
      .s_axi_bready(xdma_axil_bready),
      .s_axi_araddr(xdma_axil_araddr),
      .s_axi_arprot(xdma_axil_arprot),
      .s_axi_arvalid(xdma_axil_arvalid),
      .s_axi_arready(xdma_axil_arready),
      .s_axi_rdata(xdma_axil_rdata),
      .s_axi_rresp(xdma_axil_rresp),
      .s_axi_rvalid(xdma_axil_rvalid),
      .s_axi_rready(xdma_axil_rready),
      .m_axi_awaddr({xbar_axil_gpio0_awaddr, xbar_axil_gpio1_awaddr}),
      .m_axi_awprot({xbar_axil_gpio0_awprot, xbar_axil_gpio1_awprot}),
      .m_axi_awvalid({xbar_axil_gpio0_awvalid, xbar_axil_gpio1_awvalid}),
      .m_axi_awready({xbar_axil_gpio0_awready, xbar_axil_gpio1_awready}),
      .m_axi_wdata({xbar_axil_gpio0_wdata, xbar_axil_gpio1_wdata}),
      .m_axi_wstrb({xbar_axil_gpio0_wstrb, xbar_axil_gpio1_wstrb}),
      .m_axi_wvalid({xbar_axil_gpio0_wvalid, xbar_axil_gpio1_wvalid}),
      .m_axi_wready({xbar_axil_gpio0_wready, xbar_axil_gpio1_wready}),
      .m_axi_bresp({xbar_axil_gpio0_bresp, xbar_axil_gpio1_bresp}),
      .m_axi_bvalid({xbar_axil_gpio0_bvalid, xbar_axil_gpio1_bvalid}),
      .m_axi_bready({xbar_axil_gpio0_bready, xbar_axil_gpio1_bready}),
      .m_axi_araddr({xbar_axil_gpio0_araddr, xbar_axil_gpio1_araddr}),
      .m_axi_arprot({xbar_axil_gpio0_arprot, xbar_axil_gpio1_arprot}),
      .m_axi_arvalid({xbar_axil_gpio0_arvalid, xbar_axil_gpio1_arvalid}),
      .m_axi_arready({xbar_axil_gpio0_arready, xbar_axil_gpio1_arready}),
      .m_axi_rdata({xbar_axil_gpio0_rdata, xbar_axil_gpio1_rdata}),
      .m_axi_rresp({xbar_axil_gpio0_rresp, xbar_axil_gpio1_rresp}),
      .m_axi_rvalid({xbar_axil_gpio0_rvalid, xbar_axil_gpio1_rvalid}),
      .m_axi_rready({xbar_axil_gpio0_rready, xbar_axil_gpio1_rready})
    );

    wire ddr4_ui_reset;
    proc_sys_reset_0 ddr_reset_gen(
        .slowest_sync_clk(axi_cdc_aclk),
        .ext_reset_in(ddr4_ui_reset),
        .aux_reset_in(1'b0),
	.mb_debug_sys_rst(1'b0),
	.dcm_locked(1'b1),
	.mb_reset(),
	.bus_struct_reset(),
	.peripheral_reset(),
	.interconnect_aresetn(),
        .peripheral_aresetn(axi_cdc_aresetn)
    );

    ddr4_0 ddr4(
        .sys_rst(perst_n_buf),
        .c0_sys_clk_p(ddr_sys_clk_p),
        .c0_sys_clk_n(ddr_sys_clk_n),
        .c0_ddr4_act_n(ddr_act_n),
        .c0_ddr4_adr(ddr_adr),
        .c0_ddr4_ba(ddr_ba),
        .c0_ddr4_bg(ddr_bg),
        .c0_ddr4_cke(ddr_cke),
        .c0_ddr4_odt(ddr_odt),
        .c0_ddr4_cs_n(ddr_cs_n),
        .c0_ddr4_ck_t(ddr_ck_t),
        .c0_ddr4_ck_c(ddr_ck_c),
        .c0_ddr4_reset_n(ddr_reset_n),
        .c0_ddr4_dm_dbi_n(ddr_dm_dbi_n),
        .c0_ddr4_dq(ddr_dq),
        .c0_ddr4_dqs_c(ddr_dqs_c),
        .c0_ddr4_dqs_t(ddr_dqs_t),
        .c0_init_calib_complete(),
        .c0_ddr4_ui_clk(axi_cdc_aclk),
        .c0_ddr4_ui_clk_sync_rst(ddr4_ui_reset),
        .dbg_clk(),
        .c0_ddr4_aresetn(axi_cdc_aresetn),
        .c0_ddr4_s_axi_awid(axi_cdc_awid),
        .c0_ddr4_s_axi_awaddr(axi_cdc_awaddr),
        .c0_ddr4_s_axi_awlen(axi_cdc_awlen),
        .c0_ddr4_s_axi_awsize(axi_cdc_awsize),
        .c0_ddr4_s_axi_awburst(axi_cdc_awburst),
        .c0_ddr4_s_axi_awlock(axi_cdc_awlock),
        .c0_ddr4_s_axi_awcache(axi_cdc_awcache),
        .c0_ddr4_s_axi_awprot(axi_cdc_awprot),
        .c0_ddr4_s_axi_awqos(4'h0),
        .c0_ddr4_s_axi_awvalid(axi_cdc_awvalid),
        .c0_ddr4_s_axi_awready(axi_cdc_awready),
        .c0_ddr4_s_axi_wdata(axi_cdc_wdata),
        .c0_ddr4_s_axi_wstrb(axi_cdc_wstrb),
        .c0_ddr4_s_axi_wlast(axi_cdc_wlast),
        .c0_ddr4_s_axi_wvalid(axi_cdc_wvalid),
        .c0_ddr4_s_axi_wready(axi_cdc_wready),
        .c0_ddr4_s_axi_bready(axi_cdc_bready),
        .c0_ddr4_s_axi_bid(axi_cdc_bid),
        .c0_ddr4_s_axi_bresp(axi_cdc_bresp),
        .c0_ddr4_s_axi_bvalid(axi_cdc_bvalid),
        .c0_ddr4_s_axi_arid(axi_cdc_arid),
        .c0_ddr4_s_axi_araddr(axi_cdc_araddr),
        .c0_ddr4_s_axi_arlen(axi_cdc_arlen),
        .c0_ddr4_s_axi_arsize(axi_cdc_arsize),
        .c0_ddr4_s_axi_arburst(axi_cdc_arburst),
        .c0_ddr4_s_axi_arlock(axi_cdc_arlock),
        .c0_ddr4_s_axi_arcache(axi_cdc_arcache),
        .c0_ddr4_s_axi_arprot(axi_cdc_arprot),
        .c0_ddr4_s_axi_arqos(4'h0),
        .c0_ddr4_s_axi_arvalid(axi_cdc_arvalid),
        .c0_ddr4_s_axi_arready(axi_cdc_arready),
        .c0_ddr4_s_axi_rready(axi_cdc_rready),
        .c0_ddr4_s_axi_rid(axi_cdc_rid),
        .c0_ddr4_s_axi_rdata(axi_cdc_rdata),
        .c0_ddr4_s_axi_rresp(axi_cdc_rresp),
        .c0_ddr4_s_axi_rlast(axi_cdc_rlast),
        .c0_ddr4_s_axi_rvalid(axi_cdc_rvalid),
        .dbg_bus()
    );

    axi_gpio_0 gpio0(
        .s_axi_aclk(axi_aclk),
        .s_axi_aresetn(axi_aresetn),
        .s_axi_awaddr(xbar_axil_gpio0_awaddr[8:0]),
        .s_axi_awvalid(xbar_axil_gpio0_awvalid),
        .s_axi_awready(xbar_axil_gpio0_awready),
        .s_axi_wdata(xbar_axil_gpio0_wdata),
        .s_axi_wstrb(xbar_axil_gpio0_wstrb),
        .s_axi_wvalid(xbar_axil_gpio0_wvalid),
        .s_axi_wready(xbar_axil_gpio0_wready),
        .s_axi_bresp(xbar_axil_gpio0_bresp),
        .s_axi_bvalid(xbar_axil_gpio0_bvalid),
        .s_axi_bready(xbar_axil_gpio0_bready),
        .s_axi_araddr(xbar_axil_gpio0_araddr[8:0]),
        .s_axi_arvalid(xbar_axil_gpio0_arvalid),
        .s_axi_arready(xbar_axil_gpio0_arready),
        .s_axi_rdata(xbar_axil_gpio0_rdata),
        .s_axi_rresp(xbar_axil_gpio0_rresp),
        .s_axi_rvalid(xbar_axil_gpio0_rvalid),
        .s_axi_rready(xbar_axil_gpio0_rready),
        .ip2intc_irpt(irq_gpio0),
        .gpio_io_o(leds),
        .gpio2_io_i(switches)
    );

    wire [7:0] iocon_buf_i;
    wire [7:0] iocon_buf_o;
    wire [7:0] iocon_buf_t;
    genvar i;
    generate
        for (i = 0; i < 8 ; i = i + 1) begin
            IOBUF iocon_buf(
                .I(iocon_buf_i[i]),
                .IO(iocon[i]),
                .O(iocon_buf_o[i]),
                .T(iocon_buf_t[i])
            );
        end
    endgenerate

    axi_gpio_1 gpio1(
        .s_axi_aclk(axi_aclk),
        .s_axi_aresetn(axi_aresetn),
        .s_axi_awaddr(xbar_axil_gpio1_awaddr[8:0]),
        .s_axi_awvalid(xbar_axil_gpio1_awvalid),
        .s_axi_awready(xbar_axil_gpio1_awready),
        .s_axi_wdata(xbar_axil_gpio1_wdata),
        .s_axi_wstrb(xbar_axil_gpio1_wstrb),
        .s_axi_wvalid(xbar_axil_gpio1_wvalid),
        .s_axi_wready(xbar_axil_gpio1_wready),
        .s_axi_bresp(xbar_axil_gpio1_bresp),
        .s_axi_bvalid(xbar_axil_gpio1_bvalid),
        .s_axi_bready(xbar_axil_gpio1_bready),
        .s_axi_araddr(xbar_axil_gpio1_araddr[8:0]),
        .s_axi_arvalid(xbar_axil_gpio1_arvalid),
        .s_axi_arready(xbar_axil_gpio1_arready),
        .s_axi_rdata(xbar_axil_gpio1_rdata),
        .s_axi_rresp(xbar_axil_gpio1_rresp),
        .s_axi_rvalid(xbar_axil_gpio1_rvalid),
        .s_axi_rready(xbar_axil_gpio1_rready),
        .ip2intc_irpt(irq_gpio1),
        .gpio_io_i(iocon_buf_o),
        .gpio_io_o(iocon_buf_i),
        .gpio_io_t(iocon_buf_t)
    );
endmodule
