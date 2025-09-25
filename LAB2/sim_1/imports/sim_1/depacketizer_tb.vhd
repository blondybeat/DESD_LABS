

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity depacketizer_tb is
    Generic (
         HEADER : integer := 16#FF# ;
         FOOTER : integer := 16#F1# 
    );
end depacketizer_tb;

architecture Behavioral of depacketizer_tb is
    Component depacketizer
    Generic (
        HEADER: INTEGER :=16#FF#; --255
        FOOTER: INTEGER :=16#F1#  --241
    );
    Port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic;
        m_axis_tlast : out std_logic
            

        );
    end component;

    constant  clk_period: TIME  := 10 ns;
    constant  RESET_WND: TIME  := 4*clk_period; 
    
    constant   TB_CLK_INIT :  STD_LOGIC    := '0';
    constant   TB_RESET_INIT: STD_LOGIC    := '0';
   
-- Signals
    signal clk            : std_logic := TB_CLK_INIT;
    signal aresetn         : std_logic := TB_RESET_INIT;

    signal s_axis_tdata   : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tvalid  : std_logic := '0';
    signal s_axis_tready  : std_logic;

    signal m_axis_tdata   : std_logic_vector(7 downto 0);
    signal m_axis_tvalid  : std_logic;
    signal m_axis_tready  : std_logic := '1';
    signal m_axis_tlast   : std_logic;



    begin
    dut: depacketizer
        Generic Map(
            HEADER                  => 16#FF# ,
            FOOTER                  => 16#F1# 
        )
        Port Map(
            clk                     => clk,
            aresetn                 => ARESETN,
            s_axis_tdata            => S_AXIS_TDATA,
            s_axis_tvalid           => S_AXIS_TVALID,
            s_axis_tready           => S_AXIS_TREADY,
            m_axis_tdata            => M_AXIS_TDATA,
            m_axis_tvalid           => M_AXIS_TVALID,
            m_axis_tready           => M_AXIS_TREADY,
            m_axis_tlast            => M_AXIS_TLAST
        );



    ---------- clock ----------
    clk <= not clk after clk_period/2;
    ----------------------------
    ----- Reset Process --------
    reset_wave :process
    begin
        ARESETN <= TB_RESET_INIT;
        wait for RESET_WND;
        
        ARESETN <= not ARESETN;
        wait;
    end process;   
    ----------------------------
   
    -- Test Process-------------
    axi_process : process
    begin
    
    s_axis_tdata <= (others => '0');
    wait for RESET_WND;
    -- HEADER
    s_axis_tdata <= x"FF";
    s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0';
    wait for clk_period;

    -- RGB 1
    s_axis_tdata <= x"11"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    s_axis_tdata <= x"22"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    s_axis_tdata <= x"33"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    -- RGB 2
    s_axis_tdata <= x"44"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    s_axis_tdata <= x"55"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    s_axis_tdata <= x"66"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0'; wait for clk_period;

    -- FOOTER
    s_axis_tdata <= x"F1"; s_axis_tvalid <= '1';
    wait until rising_edge(clk) and s_axis_tready = '1';
    s_axis_tvalid <= '0';
    wait;
end process;
end behavioral;