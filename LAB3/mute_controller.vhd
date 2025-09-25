library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		mute			: in std_logic
	);
end mute_controller;
-- THE MUTE CONTROLLER SIMPLY MUTES THE AUDIO SIGNALS BY SETTING THEM TO ZERO WHEN THE MUTE SIGNAL IS HIGH

architecture Behavioral of mute_controller is
	--FSM DECLARATION
	type state_type is (IDLE, MUTE_STATE);
    signal state : state_type := IDLE;

	--INTERNAL AXI SIGNALS
	signal m_axis_tlast_int : std_logic := '0';
	signal m_axis_tvalid_int : std_logic := '0';
	signal m_axis_tdata_int : std_logic_vector(TDATA_WIDTH-1 downto 0);

begin

	with state select s_axis_tready <= 
	     '1' when IDLE,
	     '0' when OTHERS;
	
    m_axis_tvalid <= m_axis_tvalid_int;
	m_axis_tlast <= m_axis_tlast_int;
	m_axis_tdata <= m_axis_tdata_int;
	
	process(aclk, aresetn)
	begin
		
		if aresetn = '0' then
		   state <= IDLE;
		   m_axis_tvalid_int <= '0';
		   m_axis_tlast_int <= '0';
		
		elsif rising_edge(aclk) then
		    case state is
				when IDLE =>
					if s_axis_tvalid = '1' then
					    if mute = '1' then
						  m_axis_tdata_int <= (others => '0');
					    else
						  m_axis_tdata_int <= s_axis_tdata;
					    end if;
						m_axis_tlast_int <= s_axis_tlast;
						m_axis_tvalid_int <= '1';
						state <= MUTE_STATE;
				 	    
					end if;
				when MUTE_STATE =>
				    if m_axis_tready = '1' then
					   m_axis_tvalid_int <= '0';
					   state <= IDLE;
					end if;
				
			  end case;
		    
	    end if;
	end process;

end Behavioral;
