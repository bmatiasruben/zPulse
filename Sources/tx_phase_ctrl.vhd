-- -------------------------------------------------------------------------------------------------
--  SPDX-License-Identifier: GPL-3.0-or-later
-- -------------------------------------------------------------------------------------------------
--  Per-channel fine phase control for zPulse.
--
--  Wraps one CERN tx_phase_aligner (https://gitlab.cern.ch/HPTD/tx_phase_aligner) and adds a
--  setpoint controller so that software only has to write an absolute phase offset (in TX PI
--  codes, relative to the phase reached after the automatic alignment). Keeping both the target
--  and the current offset within one UI (0 to 63) makes the shortest modular path the direct one.
--
--  Control word (i_ctrl, from AXI GPIO, clk_sys domain):
--      [5:0]  target phase offset in PI codes, 0 to 63 (1 UI = 64 codes on GTH, coarser shifts
--             are done with the waveform delay in whole UIs)
--      [16]   apply: while '1' the internal target follows [5:0]; while '0' the last target is
--             held (the AXI GPIO is reset by every ol.reset(), the setpoint must survive it)
--      [17]   fine realign request (rising edge)
--      [31]   aligner reset (active high)
--
--  Status word (o_status, to AXI GPIO):
--      [6:0]   current phase offset (PI codes, relative to the aligned position)
--      [14:8]  raw accumulated PI phase (tx_pi_phase_o)
--      [16]    tx aligned
--      [17]    busy (current offset /= target)
--      [18]    GT TX reset done
-- -------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tx_phase_ctrl is
    port (
        -- system / DRP clock (also clocks the AXI GPIO that drives i_ctrl)
        i_clk_sys : in std_logic;
        -- GT TX reset done (asynchronous to i_clk_sys)
        i_tx_reset_done : in std_logic;

        -- software interface
        i_ctrl : in std_logic_vector(31 downto 0);
        o_status : out std_logic_vector(31 downto 0);
        o_aligned : out std_logic;

        -- GT interface
        i_clk_txusr : in std_logic;
        i_txbufstatus : in std_logic;
        o_txpippmen : out std_logic;
        o_txpippmovrden : out std_logic;
        o_txpippmsel : out std_logic;
        o_txpippmpd : out std_logic;
        o_txpippmstepsize : out std_logic_vector(4 downto 0);
        o_drpaddr : out std_logic_vector(9 downto 0);
        o_drpen : out std_logic;
        o_drpdi : out std_logic_vector(15 downto 0);
        i_drprdy : in std_logic;
        i_drpdo : in std_logic_vector(15 downto 0);
        o_drpwe : out std_logic
    );
end tx_phase_ctrl;

architecture Behavioral of tx_phase_ctrl is

    constant c_SETTLE_CYCLES : integer := 7;
    constant c_TIMEOUT_CYCLES : integer := 65535;

    type t_state is (IDLE, WAIT_DONE, SETTLE);
    signal r_state : t_state := IDLE;

    signal r_tx_reset_done_meta : std_logic := '0';
    signal r_tx_reset_done_sync : std_logic := '0';
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of r_tx_reset_done_meta, r_tx_reset_done_sync : signal is "TRUE";

    signal w_aligner_reset : std_logic;
    signal w_aligned : std_logic;
    signal r_aligned : std_logic := '0';
    signal w_tx_pi_phase : std_logic_vector(6 downto 0);
    signal w_ps_done : std_logic;

    signal r_ps_strobe : std_logic := '0';
    signal r_ps_inc_ndec : std_logic := '0';

    signal r_base : unsigned(6 downto 0) := (others => '0');
    signal r_target : unsigned(6 downto 0) := (others => '0');
    signal w_offset : unsigned(6 downto 0);
    signal w_diff : unsigned(6 downto 0);
    signal r_counter : integer range 0 to c_TIMEOUT_CYCLES := 0;

begin

    -- GT reset done synchronizer
    process (i_clk_sys)
    begin
        if rising_edge(i_clk_sys) then
            r_tx_reset_done_meta <= i_tx_reset_done;
            r_tx_reset_done_sync <= r_tx_reset_done_meta;
        end if;
    end process;

    w_aligner_reset <= (not r_tx_reset_done_sync) or i_ctrl(31);

    w_offset <= unsigned(w_tx_pi_phase) - r_base;
    w_diff <= r_target - w_offset;

    -- Setpoint controller: moves the PI one code at a time along the shortest path
    process (i_clk_sys)
    begin
        if rising_edge(i_clk_sys) then
            r_aligned <= w_aligned;
            r_ps_strobe <= '0';

            if i_ctrl(16) = '1' then
                r_target <= unsigned('0' & i_ctrl(5 downto 0));
            end if;

            if w_aligner_reset = '1' or w_aligned = '0' then
                r_state <= IDLE;
            else
                -- latch the phase reached by the automatic alignment
                if r_aligned = '0' then
                    r_base <= unsigned(w_tx_pi_phase);
                end if;

                case r_state is
                    when IDLE =>
                        if r_aligned = '1' and w_diff /= 0 then
                            r_ps_inc_ndec <= not w_diff(6); -- diff < 64 -> increment
                            r_ps_strobe <= '1';
                            r_counter <= 0;
                            r_state <= WAIT_DONE;
                        end if;

                    when WAIT_DONE =>
                        if w_ps_done = '1' or r_counter = c_TIMEOUT_CYCLES then
                            r_counter <= 0;
                            r_state <= SETTLE;
                        else
                            r_counter <= r_counter + 1;
                        end if;

                    when SETTLE =>
                        if r_counter = c_SETTLE_CYCLES then
                            r_state <= IDLE;
                        else
                            r_counter <= r_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    o_aligned <= w_aligned;

    o_status(6 downto 0) <= std_logic_vector(w_offset);
    o_status(7) <= '0';
    o_status(14 downto 8) <= w_tx_pi_phase;
    o_status(15) <= '0';
    o_status(16) <= w_aligned;
    o_status(17) <= '1' when w_diff /= 0 or r_state /= IDLE else '0';
    o_status(18) <= r_tx_reset_done_sync;
    o_status(31 downto 19) <= (others => '0');

    tx_phase_aligner_inst : entity work.tx_phase_aligner
        generic map(
            g_DRP_NPORT_CTRL => true,
            g_DRP_ADDR_TXPI_PPM_CFG => "010011010",
            g_DEVICE => "GTH"
        )
        port map(
            clk_sys_i => i_clk_sys,
            reset_i => w_aligner_reset,

            tx_aligned_o => w_aligned,

            tx_pi_phase_calib_i => (others => '0'),
            tx_ui_align_calib_i => '0',
            tx_fifo_fill_pd_max_i => x"00040000",
            tx_fine_realign_i => i_ctrl(17),

            ps_strobe_i => r_ps_strobe,
            ps_inc_ndec_i => r_ps_inc_ndec,
            ps_phase_step_i => "0001",
            ps_done_o => w_ps_done,

            tx_pi_phase_o => w_tx_pi_phase,
            tx_pi_phase_pre_cal_o => open,

            tx_fifo_fill_pd_o => open,

            clk_txusr_i => i_clk_txusr,
            tx_fifo_fill_level_i => i_txbufstatus,

            txpippmen_o => o_txpippmen,
            txpippmovrden_o => o_txpippmovrden,
            txpippmsel_o => o_txpippmsel,
            txpippmpd_o => o_txpippmpd,
            txpippmstepsize_o => o_txpippmstepsize,

            drpaddr_o => o_drpaddr(8 downto 0),
            drpen_o => o_drpen,
            drpdi_o => o_drpdi,
            drprdy_i => i_drprdy,
            drpdo_i => i_drpdo,
            drpwe_o => o_drpwe
        );

    o_drpaddr(9) <= '0';

end Behavioral;
