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
use IEEE.STD_LOGIC_1164.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;
entity overlay_wrapper is
    port (
        CLK_IN_300_clk_n : in std_logic;
        CLK_IN_300_clk_p : in std_logic;
        clk_10_out : out std_logic;
        clk_out_250 : out std_logic;
        locked_0 : out std_logic;
        tx_data : out std_logic_vector (511 downto 0);
        tx_inhibit : out std_logic_vector (7 downto 0);
        txusr_in : in std_logic
    );
end overlay_wrapper;

architecture STRUCTURE of overlay_wrapper is
    component overlay is
        port (
            CLK_IN_300_clk_n : in std_logic;
            CLK_IN_300_clk_p : in std_logic;
            clk_out_250 : out std_logic;
            txusr_in : in std_logic;
            tx_data : out std_logic_vector (511 downto 0);
            tx_inhibit : out std_logic_vector (7 downto 0);
            clk_10_out : out std_logic;
            locked_0 : out std_logic
        );
    end component overlay;
begin
    overlay_i : component overlay
        port map(
            CLK_IN_300_clk_n => CLK_IN_300_clk_n,
            CLK_IN_300_clk_p => CLK_IN_300_clk_p,
            clk_10_out => clk_10_out,
            clk_out_250 => clk_out_250,
            locked_0 => locked_0,
            tx_data(511 downto 0) => tx_data(511 downto 0),
            tx_inhibit(7 downto 0) => tx_inhibit(7 downto 0),
            txusr_in => txusr_in
        );
    end STRUCTURE;