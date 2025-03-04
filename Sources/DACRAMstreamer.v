// -------------------------------------------------------------------------------------------------
// Copyright (C) 2023 Advanced Micro Devices, Inc
// SPDX-License-Identifier: MIT
// ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
`timescale 1ns / 1ps

module DACRAMstreamer #( parameter DWIDTH = 64, parameter MEM_SIZE_BYTES = 262144, parameter USE_VECTOR_COUNT = 0 ) (
  (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ, MEM_SIZE 262144, MEM_WIDTH 64" *)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A DIN" *)
  output wire [DWIDTH-1:0] portA_cpu_wdata, // Data In Bus (optional)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A WE" *)
  output [DWIDTH/8-1:0] portA_we, // Byte Enables (optional)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A EN" *)
  output reg portA_en, // Chip Enable Signal (optional)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A DOUT" *)
  input wire [DWIDTH-1:0] portA_cpu_rdata, // Data Out Bus (optional)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A ADDR" *)
  output reg [31:0] portAcpu_addr, /// Address Signal (required)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A CLK" *)
  output wire portA_clk, // Clock Signal (required)

  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A RST" *)
  output wire portA_rst, // Reset Signal (required)

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_clk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF AXIS, ASSOCIATED_RESET axis_aresetn" *)
  input wire axis_clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
  input  wire              axis_aresetn,
  output reg  [DWIDTH-1:0] axis_tdata,       // luckily rest of AXIS is inferred properly
  input [31:0] ram_addr_limit);

//   reg [$clog2(MEM_SIZE_BYTES/(DWIDTH/8))-1:0] vcnt;
  wire [31:0] ramAddressLimit;
  reg counter = 0;
  
  assign portA_cpu_wdata = 0;
  assign portA_clk       = axis_clk;
  assign portA_rst       = ~axis_aresetn;
  assign portA_we        = 0;
  assign ramAddressLimit = ram_addr_limit;
  
  always @(posedge axis_clk) begin
    axis_tdata <= portA_cpu_rdata;

    if (~axis_aresetn) begin
  	end else begin
  		portA_en    <= 1'b1;
        if (portAcpu_addr == ramAddressLimit) begin
            portAcpu_addr <= 0;
        end else begin 
            portAcpu_addr <= portAcpu_addr + DWIDTH/8;
        end
  	end
  end
endmodule
