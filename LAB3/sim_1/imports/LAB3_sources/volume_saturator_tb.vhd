library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity volume_saturator_tb is
end volume_saturator_tb;

architecture Behavioral of volume_saturator_tb is
    
    component volume_saturator
        Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND	: integer := 2**15-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**15		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
        );
    end component;
    
    -- Constants
    constant TDATA_WIDTH : positive := 24;
    constant VOLUME_WIDTH	: positive := 10;
    constant VOLUME_STEP_2	: positive := 6;		-- i.e., balance_values_per_step = 2**BALANCE_STEP_2
    constant  HIGHER_BOUND	: integer := 2**15-1;	
    constant  LOWER_BOUND : integer := -2**15 ;
    
    -- Signals
    signal aclk			: std_logic := '0';
    signal aresetn			: std_logic := '0';
    signal s_axis_tvalid	: std_logic := '0';
    signal s_axis_tdata	: std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
    signal s_axis_tready	: std_logic := '0';
    signal s_axis_tlast	: std_logic := '0';
    
    signal m_axis_tvalid	: std_logic := '0';
    signal m_axis_tdata	: std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tready	: std_logic := '1';
    signal m_axis_tlast	: std_logic := '0';
    
    constant  clk_period: TIME  := 10 ns;


    

begin

    dut: volume_saturator
        generic map (
            TDATA_WIDTH		=> TDATA_WIDTH,
            VOLUME_WIDTH	=> VOLUME_WIDTH,
            VOLUME_STEP_2	=> VOLUME_STEP_2,
            HIGHER_BOUND    => HIGHER_BOUND,
            LOWER_BOUND     => LOWER_BOUND
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
            m_axis_tlast	=> m_axis_tlast
        );

    --------- clock ----------
    aclk <= not aclk after 5 ns;
    ----------------------------

    balance_process : process 
    begin
        aresetn <= '0';
        wait for 10 ns;
        aresetn <= '1';
        wait for 30 ns;
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(100, 32));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(2**16, 32));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        wait for 100 ns;


        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(2**17, 32));
        s_axis_tlast <= '0';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_signed(-(2**16), 32));
        s_axis_tlast <= '1';
        wait until rising_edge(aclk) and s_axis_tready = '1';
        s_axis_tvalid <= '0';
        wait for clk_period;
        
        wait for 100 ns;

        wait;

    end process;

end Behavioral;