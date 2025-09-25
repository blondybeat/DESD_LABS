library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller_tb is
end balance_controller_tb;

architecture Behavioral of balance_controller_tb is
    
    component balance_controller
        generic (
            TDATA_WIDTH		: positive := 24;
            BALANCE_WIDTH	: positive := 10;
            BALANCE_STEP_2	: positive := 6
        );
        port (
            aclk			: in std_logic;
            aresetn			: in std_logic;

            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tready	: out std_logic;
            s_axis_tlast	: in std_logic;

            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
            m_axis_tready	: in std_logic;
            m_axis_tlast	: out std_logic;

            balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
        );
    end component;
    
    -- Constants
    constant TDATA_WIDTH : positive := 24;
    constant BALANCE_WIDTH	: positive := 10;
    constant BALANCE_STEP_2	: positive := 6;		-- i.e., balance_values_per_step = 2**BALANCE_STEP_2
    constant  clk_period: TIME  := 10 ns;
    constant  reset: TIME  := 4*clk_period; 
    
    -- Signals
    signal aclk			: std_logic := '0';
    signal aresetn			: std_logic := '0';
    signal s_axis_tvalid	: std_logic;
    signal s_axis_tdata	: std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal s_axis_tready	: std_logic;
    signal s_axis_tlast	: std_logic;
    
    signal m_axis_tvalid	: std_logic;
    signal m_axis_tdata	: std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tready	: std_logic := '1';
    signal m_axis_tlast	: std_logic;

    signal balance	: std_logic_vector(BALANCE_WIDTH-1 downto 0);

begin

    dut: balance_controller
        generic map (
            TDATA_WIDTH		=> TDATA_WIDTH,
            BALANCE_WIDTH	=> BALANCE_WIDTH,
            BALANCE_STEP_2	=> BALANCE_STEP_2
        )
        port map (
            aclk			=> aclk,
            aresetn			=> aresetn,
            s_axis_tvalid	=> s_axis_tvalid,
            s_axis_tdata	=> s_axis_tdata,
            s_axis_tready	=> s_axis_tready,
            s_axis_tlast	=> s_axis_tlast,
            m_axis_tvalid	=> m_axis_tvalid,
            m_axis_tdata	=> m_axis_tdata,
            m_axis_tready	=> m_axis_tready,
            m_axis_tlast	=> m_axis_tlast,
            balance			=> balance
        );

    --------- clock ----------
    aclk <= not aclk after clk_period/2;
    ----------------------------

    balance_process : process 
    begin
        aresetn <= '0';
        wait for 10 ns;
        aresetn <= '1';
        wait for 30 ns;

        balance <= std_logic_vector(to_unsigned(512 + 2**BALANCE_STEP_2 * 2, BALANCE_WIDTH)); --gain = 4
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(100, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(200, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        wait for 100 ns;

        balance <= std_logic_vector(to_unsigned(512 - 2**BALANCE_STEP_2 , BALANCE_WIDTH)); --gain = 1/2

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(400, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(800, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        wait for 100 ns;

        wait;

    end process;

end Behavioral;