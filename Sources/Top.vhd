----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/07/2025 08:45:44 PM
-- Design Name: 
-- Module Name: Top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Top is
    port (
        clk_n : in std_logic;
        clk_p : in std_logic;

        user_si570_clk_p : in std_logic;
        user_si570_clk_n : in std_logic;

        gthtxp_out : out std_logic_vector(7 downto 0);
        gthtxn_out : out std_logic_vector(7 downto 0);

        clk_out_10 : out std_logic;
        o_led : out std_logic_vector(7 downto 0)
    );
end Top;

architecture Behavioral of Top is

    signal w_bufg_to_rxusrclk : std_logic_vector(7 downto 0);
    signal w_bufg_to_rxusrclk2 : std_logic_vector(7 downto 0);
    signal w_bufg_to_txusrclk : std_logic_vector(7 downto 0);
    signal w_bufg_to_txusrclk2 : std_logic_vector(7 downto 0);
    signal w_rxusrclk : std_logic;
    signal w_rxusrclk2 : std_logic;
    signal w_txusrclk : std_logic;
    signal w_txusrclk2 : std_logic;
    signal w_clk_out_250 : std_logic;
    signal mgtrefclk_single_ended : std_logic;
    signal odiv2_to_bufg_gt : std_logic;
    signal tx_data : std_logic_vector(511 downto 0);
    signal w_txoutclk : std_logic_vector(7 downto 0);
    signal w_rxoutclk : std_logic_vector(7 downto 0);
    signal w_qpll0outrefclk : std_logic_vector(1 downto 0);

begin

    o_led(7 downto 1) <= (others => '0');

    -- bufg_clocks : for i in 0 to 7 generate
    --     w_bufg_to_rxusrclk(i) <= w_rxusrclk;
    --     w_bufg_to_rxusrclk2(i) <= w_rxusrclk2;
    --     w_bufg_to_txusrclk(i) <= w_txusrclk;
    --     w_bufg_to_txusrclk2(i) <= w_txusrclk2;
    -- end generate; -- bufg_clocks

    GTX_Wizard : entity work.gtwizard_ultrascale_0
        port map(
            -- Inputs
            gtwiz_userclk_tx_active_in => "1",
            gtwiz_userclk_rx_active_in => "1",
            gtwiz_buffbypass_tx_reset_in => "0",
            gtwiz_buffbypass_tx_start_user_in => "0",
            gtwiz_reset_clk_freerun_in => w_clk_out_250,
            gtwiz_reset_all_in => "0",
            gtwiz_reset_tx_pll_and_datapath_in => "0",
            gtwiz_reset_tx_datapath_in => "0",
            gtwiz_reset_rx_pll_and_datapath_in => "0",
            gtwiz_reset_rx_datapath_in => "0",
            -- Data --
            gtwiz_userdata_tx_in => tx_data,
            -- Clocks --
            gtrefclk00_in(0) => mgtrefclk_single_ended,
            gtrefclk00_in(1) => mgtrefclk_single_ended,
            gthrxn_in => "00000000",
            gthrxp_in => "00000000",
            rxusrclk_in(0) => w_rxusrclk,
            rxusrclk_in(1) => w_rxusrclk,
            rxusrclk_in(2) => w_rxusrclk,
            rxusrclk_in(3) => w_rxusrclk,
            rxusrclk_in(4) => w_rxusrclk,
            rxusrclk_in(5) => w_rxusrclk,
            rxusrclk_in(6) => w_rxusrclk,
            rxusrclk_in(7) => w_rxusrclk,

            txusrclk_in(0) => w_txusrclk,
            txusrclk_in(1) => w_txusrclk,
            txusrclk_in(2) => w_txusrclk,
            txusrclk_in(3) => w_txusrclk,
            txusrclk_in(4) => w_txusrclk,
            txusrclk_in(5) => w_txusrclk,
            txusrclk_in(6) => w_txusrclk,
            txusrclk_in(7) => w_txusrclk,

            rxusrclk2_in(0) => w_rxusrclk2,
            rxusrclk2_in(1) => w_rxusrclk2,
            rxusrclk2_in(2) => w_rxusrclk2,
            rxusrclk2_in(3) => w_rxusrclk2,
            rxusrclk2_in(4) => w_rxusrclk2,
            rxusrclk2_in(5) => w_rxusrclk2,
            rxusrclk2_in(6) => w_rxusrclk2,
            rxusrclk2_in(7) => w_rxusrclk2,

            txusrclk2_in(0) => w_txusrclk2,
            txusrclk2_in(1) => w_txusrclk2,
            txusrclk2_in(2) => w_txusrclk2,
            txusrclk2_in(3) => w_txusrclk2,
            txusrclk2_in(4) => w_txusrclk2,
            txusrclk2_in(5) => w_txusrclk2,
            txusrclk2_in(6) => w_txusrclk2,
            txusrclk2_in(7) => w_txusrclk2,

            -- Outputs
            gtwiz_reset_rx_cdr_stable_out => open,
            gtwiz_reset_tx_done_out => open,
            gtwiz_reset_rx_done_out => open,
            gtwiz_userdata_rx_out => open,
            qpll0outclk_out => w_qpll0outrefclk,
            qpll0outrefclk_out => open,
            gthtxn_out => gthtxn_out,
            gthtxp_out => gthtxp_out,
            gtpowergood_out => open,

            rxoutclk_out => w_rxoutclk,
            txoutclk_out => w_txoutclk,

            rxpmaresetdone_out => open,
            txpmaresetdone_out => open
        );

    -- Block design

    bd : entity work.overlay_wrapper
        port map(
            CLK_IN_300_clk_n => user_si570_clk_n,
            CLK_IN_300_clk_p => user_si570_clk_p,
            clk_out_250 => w_clk_out_250,
            txusr_in => w_txusrclk2,
            clk_10_out => clk_out_10,
            tx_data => tx_data,
            locked_0 => o_led(0)
        );

    IBUFDS_GTE4_inst : IBUFDS_GTE4
    generic map(
        REFCLK_EN_TX_PATH => '0', -- Refer to Transceiver User Guide
        REFCLK_HROW_CK_SEL => "00", -- Refer to Transceiver User Guide
        REFCLK_ICNTL_RX => "00" -- Refer to Transceiver User Guide
    )
    port map(
        O => mgtrefclk_single_ended, -- 1-bit output: Refer to Transceiver User Guide
        ODIV2 => odiv2_to_bufg_gt, -- 1-bit output: Refer to Transceiver User Guide
        CEB => '0', -- 1-bit input: Refer to Transceiver User Guide
        I => clk_p, -- 1-bit input: Refer to Transceiver User Guide
        IB => clk_n -- 1-bit input: Refer to Transceiver User Guide
    );

    BUFG_GT_to_TXUSR_CLK_2 : BUFG_GT
    port map(
        O => w_txusrclk2, -- 1-bit output: Buffer
        CE => '1', --CE,           -- 1-bit input: Buffer enable
        CEMASK => '1', --CEMASK,   -- 1-bit input: CE Mask
        CLR => '0', --CLR,         -- 1-bit input: Asynchronous clear
        CLRMASK => '0', --CLRMASK, -- 1-bit input: CLR Mask
        DIV => "001", --DIV,         -- 3-bit input: Dynamic divide Value
        -- I => bufg_to_txusrclk_in_s(0)              -- 1-bit input: Buffer
        I => w_txoutclk(0) -- 1-bit input: Buffer
    );
    BUFG_GT_to_TXUSR_CLK : BUFG_GT
    port map(
        O => w_txusrclk, -- 1-bit output: Buffer
        CE => '1', --CE,           -- 1-bit input: Buffer enable
        CEMASK => '1', --CEMASK,   -- 1-bit input: CE Mask
        CLR => '0', --CLR,         -- 1-bit input: Asynchronous clear
        CLRMASK => '0', --CLRMASK, -- 1-bit input: CLR Mask
        DIV => "000", --DIV,         -- 3-bit input: Dynamic divide Value
        -- I => bufg_to_txusrclk_in_s(0)              -- 1-bit input: Buffer
        I => w_txoutclk(0) -- 1-bit input: Buffer
    );

    -- tx_usr_clk <= w_txusrclk2;
    -- clk_out_10 <= w_clk_out_250;
end Behavioral;