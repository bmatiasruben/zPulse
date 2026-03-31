--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2025.2 (lin64) Build 6299465 Fri Nov 14 12:34:56 MST 2025
--Date        : Tue Mar 31 14:12:57 2026
--Host        : mate running 64-bit Ubuntu 25.10
--Command     : generate_target zcu102_zpulse_wrapper.bd
--Design      : zcu102_zpulse_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity zcu102_zpulse_wrapper is
  port (
    CLK_IN_300_clk_n : in STD_LOGIC;
    CLK_IN_300_clk_p : in STD_LOGIC;
    clk_100_in : in STD_LOGIC;
    clk_10_out : out STD_LOGIC;
    clk_10mhz_in : in STD_LOGIC;
    clk_out_100 : out STD_LOGIC;
    clk_out_250 : out STD_LOGIC;
    ext_clk_locked : out STD_LOGIC;
    internal_clk_locked : out STD_LOGIC;
    tx_data : out STD_LOGIC_VECTOR ( 511 downto 0 );
    tx_diffctrl : out STD_LOGIC_VECTOR ( 39 downto 0 );
    tx_inhibit : out STD_LOGIC_VECTOR ( 7 downto 0 );
    tx_postcursor : out STD_LOGIC_VECTOR ( 39 downto 0 );
    tx_precursor : out STD_LOGIC_VECTOR ( 39 downto 0 );
    txusr_in : in STD_LOGIC
  );
end zcu102_zpulse_wrapper;

architecture STRUCTURE of zcu102_zpulse_wrapper is
  component zcu102_zpulse is
  port (
    CLK_IN_300_clk_n : in STD_LOGIC;
    CLK_IN_300_clk_p : in STD_LOGIC;
    clk_out_250 : out STD_LOGIC;
    txusr_in : in STD_LOGIC;
    clk_10_out : out STD_LOGIC;
    internal_clk_locked : out STD_LOGIC;
    clk_10mhz_in : in STD_LOGIC;
    ext_clk_locked : out STD_LOGIC;
    clk_out_100 : out STD_LOGIC;
    tx_inhibit : out STD_LOGIC_VECTOR ( 7 downto 0 );
    tx_data : out STD_LOGIC_VECTOR ( 511 downto 0 );
    tx_postcursor : out STD_LOGIC_VECTOR ( 39 downto 0 );
    tx_diffctrl : out STD_LOGIC_VECTOR ( 39 downto 0 );
    tx_precursor : out STD_LOGIC_VECTOR ( 39 downto 0 );
    clk_100_in : in STD_LOGIC
  );
  end component zcu102_zpulse;
begin
zcu102_zpulse_i: component zcu102_zpulse
     port map (
      CLK_IN_300_clk_n => CLK_IN_300_clk_n,
      CLK_IN_300_clk_p => CLK_IN_300_clk_p,
      clk_100_in => clk_100_in,
      clk_10_out => clk_10_out,
      clk_10mhz_in => clk_10mhz_in,
      clk_out_100 => clk_out_100,
      clk_out_250 => clk_out_250,
      ext_clk_locked => ext_clk_locked,
      internal_clk_locked => internal_clk_locked,
      tx_data(511 downto 0) => tx_data(511 downto 0),
      tx_diffctrl(39 downto 0) => tx_diffctrl(39 downto 0),
      tx_inhibit(7 downto 0) => tx_inhibit(7 downto 0),
      tx_postcursor(39 downto 0) => tx_postcursor(39 downto 0),
      tx_precursor(39 downto 0) => tx_precursor(39 downto 0),
      txusr_in => txusr_in
    );
end STRUCTURE;
