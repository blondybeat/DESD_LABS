library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter_tb is
end moving_average_filter_tb;

architecture Behavioral of moving_average_filter_tb is

    component moving_average_filter
        generic (
            FILTER_ORDER_POWER : integer := 5;
            TDATA_WIDTH        : positive := 24
        );
        port (
            aclk         : in  std_logic;
            aresetn      : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tlast  : in  std_logic;
            s_axis_tready : out std_logic;
            m_axis_tvalid : out std_logic;
            m_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            m_axis_tlast  : out std_logic;
            m_axis_tready : in  std_logic
        );
    end component;

    -- Parameters
    constant TDATA_WIDTH : integer := 24;
    constant  clk_period: TIME  := 10 ns;
    constant  reset: TIME  := 4*clk_period; 

    -- Signals
    signal aclk         : std_logic := '0';
    signal aresetn      : std_logic := '0';
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast  : std_logic := '0';
    signal s_axis_tready : std_logic;
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tlast  : std_logic;
    signal m_axis_tready : std_logic := '1';

begin
    
    dut: moving_average_filter
        generic map (
            FILTER_ORDER_POWER => 5,
            TDATA_WIDTH        => TDATA_WIDTH
        )
        port map (
            aclk         => aclk,
            aresetn      => aresetn,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tready => s_axis_tready,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tready => m_axis_tready
        );

    --------- clock ----------
    aclk <= not aclk after clk_period/2;
    ----------------------------

  
    
    averaging_filter : process
    begin
        aresetn <= '0';
        wait for 10 ns;
        aresetn <= '1';
        wait for 30 ns;
    
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(1, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tdata <= std_logic_vector(to_signed(2, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
       

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(30, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tdata <= std_logic_vector(to_signed(40, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(50, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tdata <= std_logic_vector(to_signed(60, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
      

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(70, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tdata <= std_logic_vector(to_signed(80, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
       

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(90, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
   

        s_axis_tdata <= std_logic_vector(to_signed(100, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
       

        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(110, TDATA_WIDTH));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        

        s_axis_tdata <= std_logic_vector(to_signed(120, TDATA_WIDTH));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
     
        s_axis_tvalid <= '0';
        wait;
    end process;
end Behavioral;