library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity packetizer is
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
end entity packetizer;

architecture rtl of packetizer is

	signal send_header : std_logic := '1';									-- SIGNAL THAT INDICATES THAT THE HEADER HAS NOT YET BEEN SENT       
	signal send_footer : std_logic := '0';									-- SIGNAL THAT INDICATES THE FOOTER IS BEING SENT
	signal send_last : std_logic := '0';									-- SIGNAL TO HELP DEAL WITH TLAST
	signal received_data : std_logic := '0';								-- SIGNAL STATING THAT WE RECEIVED AND BUFFERED THE INPUT DATA
	signal next_data_out: std_logic_vector(7 downto 0);						-- BUFFERING INPUT DATA
	signal m_axis_tdata_int : std_logic_vector(7 downto 0);
	signal m_axis_tvalid_int : std_logic := '0';
	signal s_axis_tready_int  : std_logic := '0';							-- READY IS ONLY PULLED TO '1' AFTER WE SENT THE HEADER

begin
    
	s_axis_tready <= s_axis_tready_int;										-- INTERNAL SIGNAL DECLARATION
	m_axis_tvalid <= m_axis_tvalid_int;
	m_axis_tdata <= m_axis_tdata_int;
    

	process(clk, aresetn) 
	begin
		if aresetn = '0' then
			m_axis_tvalid_int <= '0';
			s_axis_tready_int <= '0';										-- STILL '0' READY
			received_data <= '0';
			send_footer <= '0';
			next_data_out <= (others => '0');
			send_header <= '1';
			send_last <= '0';
        
		elsif rising_edge(clk) then
		
			-- SLAVE LOGIC, PULLING S_AXIS_TREADY HIGH ONLY AFTER SENDING THE HEADER
			if s_axis_tvalid = '1' and send_header = '1' then				-- VALID DATA ON THE SLAVE SIDE INDICATES THAT WE CAN SEND THE HEADER
				m_axis_tdata_int <= std_logic_vector(to_unsigned(HEADER, s_axis_tdata'length)); -- DIRECTLY ON DATA LINE
				send_header <= '0';
				m_axis_tvalid_int <= '1';
			elsif s_axis_tvalid = '1' and s_axis_tready_int = '1' then		-- AFTER WE PULLED READY HIGH WE BUFFER THE FIRST INCOMING DATA
				next_data_out <= s_axis_tdata;
				received_data <= '1';
				s_axis_tready_int <= '0';
				if s_axis_tlast = '1' then									-- ARRIVAL OF TLAST INDICATES THAT NEXT WE HAVE TO SEND THE FOOTER
					send_footer <= '1';
				end if;
			end if;
            
			-- MASTER LOGIC --
			if m_axis_tready = '1' or m_axis_tvalid_int = '0' then
				if received_data = '1' and send_last = '0' then
					m_axis_tdata_int <= next_data_out;
					m_axis_tvalid_int <= '1';
					received_data <= '0';
				elsif received_data = '1' and send_last = '1' then
					m_axis_tdata_int <= std_logic_vector(to_unsigned(FOOTER, s_axis_tdata'length));
					m_axis_tvalid_int <= '1';
					received_data <= '0';
					send_footer <= '0';
					send_header <= '1';
					send_last <= '0';
				end if;				
			end if;
            
            -- HANDSHAKE --
			if m_axis_tready = '1' and m_axis_tvalid_int = '1' then
				m_axis_tvalid_int <= '0';
				s_axis_tready_int <= '1';
				if send_footer = '1' then
					send_last <= '1';										-- SAYING THAT THE FOOTER IS READY TO BE SENT
					received_data <= '1';
				elsif m_axis_tdata_int = std_logic_vector(to_unsigned(FOOTER, s_axis_tdata'length)) then 
				    m_axis_tvalid_int <= '0';
				    s_axis_tready_int <= '0'; 								-- PULLING S_AXIS_TREADY_INT BACK TO '0' FOR BEING ABLE TO RECEIVE MORE IMAGES
				end if;
			end if;     
		end if;

	end process;
 
    

end architecture;

