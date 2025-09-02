--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
--Date        : Tue Sep  2 18:26:29 2025
--Host        : mate running 64-bit Ubuntu 22.04.5 LTS
--Command     : generate_target zcu102_zpulse_wrapper.bd
--Design      : zcu102_zpulse_wrapper
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
        clk_10_out       : out std_logic;
        clk_out_250      : out std_logic;
        locked_0         : out std_logic;
        tx_data          : out std_logic_vector (511 downto 0);
        tx_diffctrl      : out std_logic_vector (39 downto 0);
        tx_inhibit       : out std_logic_vector (7 downto 0);
        tx_postcursor    : out std_logic_vector (39 downto 0);
        tx_precursor     : out std_logic_vector (39 downto 0);
        txusr_in         : in std_logic
    );
end overlay_wrapper;

architecture STRUCTURE of overlay_wrapper is
    component zcu102_zpulse is
        port (
            CLK_IN_300_clk_n : in std_logic;
            CLK_IN_300_clk_p : in std_logic;
            clk_out_250      : out std_logic;
            txusr_in         : in std_logic;
            tx_data          : out std_logic_vector (511 downto 0);
            clk_10_out       : out std_logic;
            locked_0         : out std_logic;
            tx_inhibit       : out std_logic_vector (7 downto 0);
            tx_diffctrl      : out std_logic_vector (39 downto 0);
            tx_postcursor    : out std_logic_vector (39 downto 0);
            tx_precursor     : out std_logic_vector (39 downto 0)
        );
    end component zcu102_zpulse;
begin
    zcu102_zpulse_i : component zcu102_zpulse
        port map(
            CLK_IN_300_clk_n           => CLK_IN_300_clk_n,
            CLK_IN_300_clk_p           => CLK_IN_300_clk_p,
            clk_10_out                 => clk_10_out,
            clk_out_250                => clk_out_250,
            locked_0                   => locked_0,
            tx_data(511 downto 0)      => tx_data(511 downto 0),
            tx_diffctrl(39 downto 0)   => tx_diffctrl(39 downto 0),
            tx_inhibit(7 downto 0)     => tx_inhibit(7 downto 0),
            tx_postcursor(39 downto 0) => tx_postcursor(39 downto 0),
            tx_precursor(39 downto 0)  => tx_precursor(39 downto 0),
            txusr_in                   => txusr_in
        );
    end STRUCTURE;