library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity rgb2gray_tb is
--  Port ( );
end rgb2gray_tb;

architecture Behavioral of rgb2gray_tb is
    
    component rgb2gray
        Port (
            clk             : in std_logic;
            resetn          : in std_logic;

            m_axis_tvalid   : out std_logic;
            m_axis_tdata    : out std_logic_vector(7 downto 0);
            m_axis_tready   : in std_logic;
            m_axis_tlast    : out std_logic;

            s_axis_tvalid   : in std_logic;
            s_axis_tdata    : in std_logic_vector(7 downto 0);
            s_axis_tready   : out std_logic;
            s_axis_tlast    : in std_logic
        );
    end component;

    signal clk             : std_logic := '0';
    signal resetn          : std_logic := '0';

    signal s_axis_tvalid   : std_logic := '0';
    signal s_axis_tdata    : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tready   : std_logic;
    signal s_axis_tlast    : std_logic := '0';

    signal m_axis_tvalid   : std_logic;
    signal m_axis_tdata    : std_logic_vector(7 downto 0);
    signal m_axis_tready   : std_logic := '1';
    signal m_axis_tlast    : std_logic;

    constant clk_period : time := 10 ns;

begin

    dut: rgb2gray
        port map (
            clk => clk,
            resetn => resetn,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast
        );

    ---------- clock ----------
    clk <= not clk after clk_period/2;
    ----------------------------
    rgb2gray_inst : process
    begin
        resetn <= '0';
        wait for 10 ns;
        resetn <= '1';
        s_axis_tvalid <= '0';
        wait for 10 ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(1,8));
        s_axis_tvalid <= '1';
        --wait for 10 ns;
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(66,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(2,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tvalid <= '0';
        
        wait for 4*clk_period;
        s_axis_tdata <= std_logic_vector(to_unsigned(20,8));
        s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(10,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(20,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tvalid <= '0';
        wait until rising_edge(clk);
    
        wait for 4*clk_period;
        s_axis_tdata <= std_logic_vector(to_unsigned(127,8));
        s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(127,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tdata <= std_logic_vector(to_unsigned(127,8));
        wait until rising_edge(clk) and s_axis_tready = '1';
        --wait for 10ns;
        s_axis_tvalid <= '0';
        wait until rising_edge(clk);
        s_axis_tlast <= '1';
        wait;
        
    end process;

end Behavioral;