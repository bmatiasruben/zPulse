library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity BRAM_streamer_data is
    generic (
        -- AXI Stream data width
        g_DWIDTH : integer := 64;
        MEM_SIZE_BYTES : integer := 65536
    );
    port (
        -- gpio inputs
        i_addr_limit : in std_logic_vector(31 downto 0);
        -- inputs AXI
        i_axis_clk : in std_logic;
        i_axis_aresetn : in std_logic;
        o_axis_tdata : out std_logic_vector(g_DWIDTH - 1 downto 0);

        -- BRAM interface
        i_bram_din : in std_logic_vector(g_DWIDTH - 1 downto 0);
        o_bram_clk : out std_logic;
        o_bram_rst : out std_logic;
        o_bram_en : out std_logic;
        o_bram_we : out std_logic_vector(g_DWIDTH/8 - 1 downto 0);
        o_bram_addr : out std_logic_vector(31 downto 0);
        o_bram_dout : out std_logic_vector(g_DWIDTH - 1 downto 0)
    );
end BRAM_streamer_data;

architecture Behavioral of BRAM_streamer_data is
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER of o_bram_dout : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of o_bram_we : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of o_bram_clk : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of o_bram_rst : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of o_bram_addr : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of o_bram_en : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";
    attribute X_INTERFACE_PARAMETER of i_bram_din : signal is "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 64";

    attribute X_INTERFACE_INFO of o_bram_dout : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA DIN";
    attribute X_INTERFACE_INFO of o_bram_we : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA WE";
    attribute X_INTERFACE_INFO of o_bram_clk : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA CLK";
    attribute X_INTERFACE_INFO of o_bram_rst : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA RST";
    attribute X_INTERFACE_INFO of o_bram_addr : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA ADDR";
    attribute X_INTERFACE_INFO of o_bram_en : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA EN";
    attribute X_INTERFACE_INFO of i_bram_din : signal is "xilinx.com:interface:bram:1.0 BRAM_DATA DOUT";

    signal r_bram_addr : unsigned(31 downto 0) := (others => '0');

begin

    o_bram_dout <= (others => '0');
    o_bram_clk <= i_axis_clk;
    o_bram_rst <= not i_axis_aresetn;
    o_bram_we <= (others => '0');
    o_bram_addr <= std_logic_vector(r_bram_addr);

    process (i_axis_clk)
    begin
        if rising_edge(i_axis_clk) then
            o_axis_tdata <= i_bram_din;
            if (i_axis_aresetn = '0') then
                r_bram_addr <= (others => '0');
            else
                o_bram_en <= '1';
                if r_bram_addr >= unsigned(i_addr_limit) then
                    r_bram_addr <= (others => '0');
                else
                    r_bram_addr <= r_bram_addr + g_DWIDTH/8;
                end if;
            end if;
        end if;
    end process;

end Behavioral;