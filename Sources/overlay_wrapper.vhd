--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2024.2 (win64) Build 5239630 Fri Nov 08 22:35:27 MST 2024
--Date        : Wed Feb 19 22:20:23 2025
--Host        : SILICON running 64-bit major release  (build 9200)
--Command     : generate_target overlay_wrapper.bd
--Design      : overlay_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity overlay_wrapper is
  port (
    CLK_IN_300_clk_n : in STD_LOGIC;
    CLK_IN_300_clk_p : in STD_LOGIC;
    clk_10_out : out STD_LOGIC;
    clk_out_250 : out STD_LOGIC;
    locked_0 : out STD_LOGIC;
    tx_data : out STD_LOGIC_VECTOR ( 511 downto 0 );
    txusr_in : in STD_LOGIC
  );
end overlay_wrapper;

architecture STRUCTURE of overlay_wrapper is
  component overlay is
  port (
    CLK_IN_300_clk_n : in STD_LOGIC;
    CLK_IN_300_clk_p : in STD_LOGIC;
    clk_out_250 : out STD_LOGIC;
    txusr_in : in STD_LOGIC;
    tx_data : out STD_LOGIC_VECTOR ( 511 downto 0 );
    clk_10_out : out STD_LOGIC;
    locked_0 : out STD_LOGIC
  );
  end component overlay;
begin
overlay_i: component overlay
     port map (
      CLK_IN_300_clk_n => CLK_IN_300_clk_n,
      CLK_IN_300_clk_p => CLK_IN_300_clk_p,
      clk_10_out => clk_10_out,
      clk_out_250 => clk_out_250,
      locked_0 => locked_0,
      tx_data(511 downto 0) => tx_data(511 downto 0),
      txusr_in => txusr_in
    );
end STRUCTURE;
