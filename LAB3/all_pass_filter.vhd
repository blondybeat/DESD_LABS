library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity all_pass_filter is
	generic (
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
		m_axis_tready	: in std_logic
	);
end all_pass_filter;

-- THIS ENTITY IS A SIMPLE ALL PASS FILTER THAT PASSES THE AUDIO DATA WITHOUT ANY MODIFICATION
architecture Behavioral of all_pass_filter is
	type state_type is (IDLE, SEND);
	signal state : state_type := IDLE;
	signal m_axis_tdata_int : std_logic_vector(TDATA_WIDTH-1 downto 0);
	signal m_axis_tlast_int : std_logic;

begin
	m_axis_tdata <= m_axis_tdata_int;
	m_axis_tlast <= m_axis_tlast_int;
    
	with state select s_axis_tready <= 
	     '1' when IDLE,
	     '0' when OTHERS;
	with state select m_axis_tvalid <=
	     '1' when SEND,
	     '0' when OTHERS;
	
	process(aclk, aresetn)
	begin
		
		if aresetn = '0' then
			state <= IDLE;
			m_axis_tlast_int <= '0';
			m_axis_tdata_int <= (others => '0');
			
		elsif rising_edge(aclk) then
			   case state is
				when IDLE =>
					if s_axis_tvalid = '1' then
						m_axis_tdata_int <= s_axis_tdata;
						m_axis_tlast_int <= s_axis_tlast;
						state <= SEND;
					end if;

				when SEND =>
					if m_axis_tready = '1' then
						state <= IDLE;
					end if;
			
			  end case;
		    
		end if;
	end process;

end Behavioral;
