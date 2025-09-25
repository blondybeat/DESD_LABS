


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity packetizer_tb is
    Generic (
        HEADER : integer := 16#FF# ;
        FOOTER : integer := 16#F1# 
   );
end packetizer_tb;
    
architecture Behavioral of packetizer_tb is
   
    constant  clk_period: TIME  := 10 ns;
    constant  RESET_WND: TIME  := 4*clk_period; 
    
    constant   TB_CLK_INIT :  STD_LOGIC    := '0';
    constant   TB_RESET_INIT: STD_LOGIC    := '0';
   
-- Signals
    signal clk            : std_logic := '0';
    signal aresetn         : std_logic := '0';

    signal s_axis_tdata   : std_logic_vector(7 downto 0);
    signal s_axis_tvalid  : std_logic := '0';
    signal s_axis_tready  : std_logic;
    signal s_axis_tlast   : std_logic;

    signal m_axis_tdata   : std_logic_vector(7 downto 0);
    signal m_axis_tvalid  : std_logic;
    signal m_axis_tready  : std_logic := '1';
    
    Component packetizer 
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic 
        
    );
    end component;


    

begin
    dut: packetizer
     generic map(
        HEADER => HEADER,
        FOOTER => FOOTER
    )
     port map(
        clk => clk,
        aresetn => aresetn,
        s_axis_tdata => s_axis_tdata,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tready => s_axis_tready,
        s_axis_tlast => s_axis_tlast,
        m_axis_tdata => m_axis_tdata,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tready => m_axis_tready
    );

    --------- clock ----------
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

    axi_process : process
    begin
        s_axis_tdata <= (others => '0');
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';
        
        wait for RESET_WND;

        
        s_axis_tdata <= x"11"; s_axis_tvalid <= '1'; s_axis_tlast <= '0';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

        s_axis_tdata <= x"22"; s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

        s_axis_tdata <= x"33"; s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

    
        s_axis_tdata <= x"44"; s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

        s_axis_tdata <= x"55"; s_axis_tvalid <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

        s_axis_tdata <= x"66"; s_axis_tvalid <= '1'; s_axis_tlast <= '1';
        wait until rising_edge(clk) and s_axis_tready = '1';
        s_axis_tvalid <= '0'; wait for clk_period;

 

        -- End transmission
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';
        wait;
    end process;

end Behavioral;
