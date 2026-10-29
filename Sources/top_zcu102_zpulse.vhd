-- -------------------------------------------------------------------------------------------------
--  Copyright (C) 2025 Matías Rubén Bolaños Wagner
--  SPDX-License-Identifier: GPL-3.0-or-later
-- -------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

library xpm;
use xpm.vcomponents.all;

entity Top is
    port (
        clk_gt_internal_n : in std_logic;
        clk_gt_internal_p : in std_logic;
        user_si570_clk_p  : in std_logic;
        user_si570_clk_n  : in std_logic;

        gthtxp_out : out std_logic_vector(7 downto 0);
        gthtxn_out : out std_logic_vector(7 downto 0);

        clk_10mhz_in  : in std_logic;
        clk_10mhz_out : out std_logic;
        o_led         : out std_logic_vector(7 downto 0)
    );
end Top;

architecture Behavioral of Top is

    signal w_bufg_to_rxusrclk              : std_logic_vector(7 downto 0);
    signal w_bufg_to_rxusrclk2             : std_logic_vector(7 downto 0);
    signal w_bufg_to_txusrclk              : std_logic_vector(7 downto 0);
    signal w_bufg_to_txusrclk2             : std_logic_vector(7 downto 0);
    signal w_rxusrclk                      : std_logic;
    signal w_rxusrclk2                     : std_logic;
    signal w_txusrclk                      : std_logic;
    signal w_txusrclk2                     : std_logic;
    signal w_clk_out_250                   : std_logic;
    signal mgtrefclk_internal_single_ended : std_logic;
    signal mgtrefclk_external_single_ended : std_logic;
    signal odiv2_to_bufg_gt                : std_logic;
    signal tx_data                         : std_logic_vector(511 downto 0);
    signal w_txoutclk                      : std_logic_vector(7 downto 0);
    signal w_rxoutclk                      : std_logic_vector(7 downto 0);
    signal w_qpll0outrefclk                : std_logic_vector(1 downto 0);
    signal tx_inhibit                      : std_logic_vector(7 downto 0) := (others => '1');
    signal tx_postcursor                   : std_logic_vector(39 downto 0);
    signal tx_precursor                    : std_logic_vector(39 downto 0);
    signal tx_diffctrl                     : std_logic_vector(39 downto 0);
    signal w_clk_10_out                    : std_logic;
    signal w_clk_100                       : std_logic;
    signal w_ext_clk_locked                : std_logic;
    signal w_clk_to_bufg                   : std_logic;
    signal w_clk_100_int                   : std_logic;
    signal w_clk_to_gt                     : std_logic;
    signal gt_tx_inhibit                   : std_logic_vector(7 downto 0);

    -- TX phase control: every channel is aligned, channel 0 is the reference (offset fixed at 0)
    -- and channels 1 to 7 are adjustable
    type t_word_array is array (0 to 7) of std_logic_vector(31 downto 0);
    signal phase_ctrl                      : t_word_array;
    signal phase_ctrl_ref                  : std_logic_vector(31 downto 0);
    signal phase_status                    : t_word_array;
    signal w_clk_ctrl                      : std_logic;
    signal tx_reset_done                   : std_logic_vector(0 downto 0);
    signal tx_aligned                      : std_logic_vector(7 downto 0);
    signal drpclk                          : std_logic_vector(7 downto 0);
    signal drpaddr                         : std_logic_vector(79 downto 0);
    signal drpdi                           : std_logic_vector(127 downto 0);
    signal drpen                           : std_logic_vector(7 downto 0);
    signal drpwe                           : std_logic_vector(7 downto 0);
    signal drpdo                           : std_logic_vector(127 downto 0);
    signal drprdy                          : std_logic_vector(7 downto 0);
    signal txpippmen                       : std_logic_vector(7 downto 0);
    signal txpippmovrden                   : std_logic_vector(7 downto 0);
    signal txpippmpd                       : std_logic_vector(7 downto 0);
    signal txpippmsel                      : std_logic_vector(7 downto 0);
    signal txpippmstepsize                 : std_logic_vector(39 downto 0);
    signal txbufstatus                     : std_logic_vector(15 downto 0);

    -- waveform address reset: from the PS (clk_ctrl) to all streamers (txusrclk2)
    signal w_addr_reset_ctrl               : std_logic_vector(0 downto 0);
    signal w_addr_reset_txusr              : std_logic;

begin

    o_led(7 downto 2) <= (others => '0');
    o_led(1)          <= w_ext_clk_locked;
    -- o_led(7 downto 5) <= w_clock_selector(2 downto 0);
    clk_10mhz_out <= w_clk_10_out;
    w_clk_to_gt   <= w_clk_100 when w_ext_clk_locked = '1' else w_clk_100_int;

    GTX_Wizard : entity work.gtwizard_ultrascale_0
        port map(
            -- Inputs
            gtwiz_userclk_tx_active_in => "1",
            gtwiz_userclk_rx_active_in => "1",
            -- gtwiz_buffbypass_tx_reset_in       => "0",
            -- gtwiz_buffbypass_tx_start_user_in  => "0",
            gtwiz_reset_clk_freerun_in         => w_clk_out_250,
            gtwiz_reset_all_in                 => "0",
            gtwiz_reset_tx_pll_and_datapath_in => "0",
            gtwiz_reset_tx_datapath_in         => "0",
            gtwiz_reset_rx_pll_and_datapath_in => "0",
            gtwiz_reset_rx_datapath_in         => "0",
            -- Data --
            gtwiz_userdata_tx_in => tx_data,
            -- Clocks --
            gtrefclk00_in(0)  => '0',
            gtrefclk00_in(1)  => '0',
            gtgrefclk0_in(0)  => w_clk_to_gt,
            gtgrefclk0_in(1)  => w_clk_to_gt,
            qpll0refclksel_in => "111111",
            txinhibit_in      => gt_tx_inhibit,
            -- TX phase interpolator / DRP (driven by tx_phase_ctrl)
            drpaddr_in         => drpaddr,
            drpclk_in          => drpclk,
            drpdi_in           => drpdi,
            drpen_in           => drpen,
            drpwe_in           => drpwe,
            txpippmen_in       => txpippmen,
            txpippmovrden_in   => txpippmovrden,
            txpippmpd_in       => txpippmpd,
            txpippmsel_in      => txpippmsel,
            txpippmstepsize_in => txpippmstepsize,
            gthrxn_in         => "00000000",
            gthrxp_in         => "00000000",
            rxusrclk_in(0)    => w_rxusrclk,
            rxusrclk_in(1)    => w_rxusrclk,
            rxusrclk_in(2)    => w_rxusrclk,
            rxusrclk_in(3)    => w_rxusrclk,
            rxusrclk_in(4)    => w_rxusrclk,
            rxusrclk_in(5)    => w_rxusrclk,
            rxusrclk_in(6)    => w_rxusrclk,
            rxusrclk_in(7)    => w_rxusrclk,

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
            gtwiz_reset_tx_done_out       => tx_reset_done,
            gtwiz_reset_rx_done_out       => open,
            gtwiz_userdata_rx_out         => open,
            qpll0outclk_out               => w_qpll0outrefclk,
            qpll0outrefclk_out            => open,
            gthtxn_out                    => gthtxn_out,
            gthtxp_out                    => gthtxp_out,
            gtpowergood_out               => open,
            txpostcursor_in               => tx_postcursor,
            txprecursor_in                => tx_precursor,
            txdiffctrl_in                 => tx_diffctrl,

            rxoutclk_out => w_rxoutclk,
            txoutclk_out => w_txoutclk,

            rxpmaresetdone_out => open,
            txpmaresetdone_out => open,
            drpdo_out          => drpdo,
            drprdy_out         => drprdy,
            txbufstatus_out    => txbufstatus
        );

    -- TX phase control

    drpclk <= (others => w_clk_ctrl);

    -- Channel 0 is the phase reference: it is aligned like the others (with the TX buffer on its
    -- latency is otherwise random after every reset) but its offset stays at 0. TX_PROGCLK_SEL is
    -- PREPI, so moving the channel 0 PI does not move TXOUTCLK / txusrclk.
    -- Only realign [17] and reset [31] are taken from its GPIO: apply = 1, target = 0.
    phase_ctrl(0) <= phase_ctrl_ref(31 downto 17) & '1' & x"0000";

    gen_phase_ctrl : for i in 0 to 7 generate
        tx_phase_ctrl_inst : entity work.tx_phase_ctrl
            port map(
                i_clk_sys         => w_clk_ctrl,
                i_tx_reset_done   => tx_reset_done(0),
                i_ctrl            => phase_ctrl(i),
                o_status          => phase_status(i),
                o_aligned         => tx_aligned(i),
                i_clk_txusr       => w_txusrclk2,
                i_txbufstatus     => txbufstatus(2 * i),
                o_txpippmen       => txpippmen(i),
                o_txpippmovrden   => txpippmovrden(i),
                o_txpippmsel      => txpippmsel(i),
                o_txpippmpd       => txpippmpd(i),
                o_txpippmstepsize => txpippmstepsize(5 * i + 4 downto 5 * i),
                o_drpaddr         => drpaddr(10 * i + 9 downto 10 * i),
                o_drpen           => drpen(i),
                o_drpdi           => drpdi(16 * i + 15 downto 16 * i),
                i_drprdy          => drprdy(i),
                i_drpdo           => drpdo(16 * i + 15 downto 16 * i),
                o_drpwe           => drpwe(i)
            );
    end generate; -- gen_phase_ctrl

    -- keep a channel quiet until its phase alignment is done
    gt_tx_inhibit <= tx_inhibit or not tx_aligned;

    -- One synchronizer for all streamers, so that every channel leaves the address reset on the
    -- same txusrclk2 cycle (independent synchronizers could resolve one cycle apart)
    addr_reset_cdc : xpm_cdc_single
        generic map(DEST_SYNC_FF => 4, INIT_SYNC_FF => 0, SIM_ASSERT_CHK => 0, SRC_INPUT_REG => 1)
        port map(
            src_clk  => w_clk_ctrl,
            src_in   => w_addr_reset_ctrl(0),
            dest_clk => w_txusrclk2,
            dest_out => w_addr_reset_txusr
        );

    -- Block design

    bd : entity work.zcu102_zpulse_wrapper
        port map(
            CLK_IN_300_clk_n    => user_si570_clk_n,
            CLK_IN_300_clk_p    => user_si570_clk_p,
            clk_out_100         => w_clk_100,
            clk_out_250         => w_clk_out_250,
            txusr_in            => w_txusrclk2,
            clk_10_out          => w_clk_10_out,
            clk_10mhz_in        => clk_10mhz_in,
            clk_100_in          => w_clk_to_gt,
            ext_clk_locked      => w_ext_clk_locked,
            tx_data             => tx_data,
            tx_inhibit          => tx_inhibit,
            internal_clk_locked => o_led(0),
            tx_postcursor       => tx_postcursor,
            tx_precursor        => tx_precursor,
            tx_diffctrl         => tx_diffctrl,
            clk_ctrl            => w_clk_ctrl,
            phase_ctrl_0        => phase_ctrl_ref,
            phase_status_0      => phase_status(0),
            addr_reset_out      => w_addr_reset_ctrl,
            addr_reset_in       => w_addr_reset_txusr,
            phase_ctrl_1        => phase_ctrl(1),
            phase_ctrl_2        => phase_ctrl(2),
            phase_ctrl_3        => phase_ctrl(3),
            phase_ctrl_4        => phase_ctrl(4),
            phase_ctrl_5        => phase_ctrl(5),
            phase_ctrl_6        => phase_ctrl(6),
            phase_ctrl_7        => phase_ctrl(7),
            phase_status_1      => phase_status(1),
            phase_status_2      => phase_status(2),
            phase_status_3      => phase_status(3),
            phase_status_4      => phase_status(4),
            phase_status_5      => phase_status(5),
            phase_status_6      => phase_status(6),
            phase_status_7      => phase_status(7)
        );

    IBUFDS_GTE4_int_inst : IBUFDS_GTE4
    generic map(
        REFCLK_EN_TX_PATH  => '0',  -- Refer to Transceiver User Guide
        REFCLK_HROW_CK_SEL => "00", -- Refer to Transceiver User Guide
        REFCLK_ICNTL_RX    => "00"  -- Refer to Transceiver User Guide
    )
    port map(
        O     => mgtrefclk_internal_single_ended, -- 1-bit output: Refer to Transceiver User Guide
        ODIV2 => w_clk_to_bufg,                   -- 1-bit output: Refer to Transceiver User Guide
        CEB   => '0',                             -- 1-bit input: Refer to Transceiver User Guide
        I     => clk_gt_internal_p,               -- 1-bit input: Refer to Transceiver User Guide
        IB    => clk_gt_internal_n                -- 1-bit input: Refer to Transceiver User Guide
    );
    BUFG_GT_to_REFCLK : BUFG_GT
    port map(
        O       => w_clk_100_int, -- 1-bit output: Buffer
        CE      => '1',           --CE,           -- 1-bit input: Buffer enable
        CEMASK  => '1',           --CEMASK,   -- 1-bit input: CE Mask
        CLR     => '0',           --CLR,         -- 1-bit input: Asynchronous clear
        CLRMASK => '0',           --CLRMASK, -- 1-bit input: CLR Mask
        DIV     => "000",         --DIV,         -- 3-bit input: Dynamic divide Value
        -- I => bufg_to_txusrclk_in_s(0)              -- 1-bit input: Buffer
        I => w_clk_to_bufg -- 1-bit input: Buffer
    );

    BUFG_GT_to_TXUSR_CLK_2 : BUFG_GT
    port map(
        O       => w_txusrclk2, -- 1-bit output: Buffer
        CE      => '1',         --CE,           -- 1-bit input: Buffer enable
        CEMASK  => '1',         --CEMASK,   -- 1-bit input: CE Mask
        CLR     => '0',         --CLR,         -- 1-bit input: Asynchronous clear
        CLRMASK => '0',         --CLRMASK, -- 1-bit input: CLR Mask
        DIV     => "001",       --DIV,         -- 3-bit input: Dynamic divide Value
        -- I => bufg_to_txusrclk_in_s(0)              -- 1-bit input: Buffer
        I => w_txoutclk(0) -- 1-bit input: Buffer
    );
    BUFG_GT_to_TXUSR_CLK : BUFG_GT
    port map(
        O       => w_txusrclk, -- 1-bit output: Buffer
        CE      => '1',        --CE,           -- 1-bit input: Buffer enable
        CEMASK  => '1',        --CEMASK,   -- 1-bit input: CE Mask
        CLR     => '0',        --CLR,         -- 1-bit input: Asynchronous clear
        CLRMASK => '0',        --CLRMASK, -- 1-bit input: CLR Mask
        DIV     => "000",      --DIV,         -- 3-bit input: Dynamic divide Value
        -- I => bufg_to_txusrclk_in_s(0)              -- 1-bit input: Buffer
        I => w_txoutclk(0) -- 1-bit input: Buffer
    );

    -- tx_usr_clk <= w_txusrclk2;
    -- clk_out_10 <= w_clk_out_250;
end Behavioral;