library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity depacketizer is
	generic (
		HEADER: INTEGER :=16#FF#; --255
		FOOTER: INTEGER :=16#F1#  --241
	);
	port (
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
end entity depacketizer;

architecture rtl of depacketizer is
    

	signal s_axis_tready_int  : std_logic := '1';							-- INTERNAL AXI4 SIGNALS
	signal m_axis_tvalid_int : std_logic := '0';
    
	signal inside_packet : std_logic := '0';								-- INDICATES THAT WE ARE INSIDE THE PACKET
	signal send_last : std_logic := '0'; 									-- FLAG TO SEND THE LAST DATA BEFORE THE FOOTER
    
    
	type type_sr is array(1 downto 0) of std_logic_vector(7 downto 0);		-- THE IDEA IS TO CREATE A SHIFT REGISTER IN WHICH WE STORE THE INPUT DATA 
	signal sr: type_sr := (others => (others => '0'));						-- THIS IS DONE IN ORDER TO BE ABLE TO SEND A TLAST SIGNAL THE SAME TIME WE SEND THE LAST DATA BYTE
     
    
begin
	s_axis_tready <= s_axis_tready_int;
	m_axis_tvalid <= m_axis_tvalid_int;
   
	process(clk, aresetn)
	begin
		if aresetn = '0' then

			m_axis_tvalid_int <= '0';
			s_axis_tready_int <= '1';
			m_axis_tlast <= '0';
			send_last <= '0';
			inside_packet <= '0';
			sr <= (others => (others => '0'));
			m_axis_tlast <= '0';

		elsif rising_edge(clk) then
			-- SLAVE LOGIC --
			if s_axis_tvalid = '1' and s_axis_tready_int = '1' then
				sr <= sr(0) & s_axis_tdata;									-- WHEN WE HAVE VALID DATA ENTERING, WE PUT EVERYTHING INTO THE SR
				if inside_packet = '0' then
					if s_axis_tdata = std_logic_vector(to_unsigned(HEADER, m_axis_tdata'length)) then
						inside_packet <= '1';
					end if;
				else
					if sr(0) = std_logic_vector(to_unsigned(HEADER, m_axis_tdata'length)) then			-- IF THE LAST BYTE OF THE SR IS THE HEADER, WE DON'T SEND IT BUT KEEP READY HIGH	
						s_axis_tready_int <= '1';
					else																				-- IF IT ISN'T, IT MEANS WE HAVE DATA AND WE SEND IT OUT ON THE MASTER DATA BUS
						s_axis_tready_int <= '0';                       
					end if;
					if s_axis_tdata = std_logic_vector(to_unsigned(FOOTER, s_axis_tdata'length)) then 	-- FLAG THAT HELPS US SENDING TLAST SIGNAL WHEN THE HEADER ARRIVES
						send_last <= '1';
					end if;
				end if;
			end if;
			
			-- MASTER LOGIC
			if s_axis_tready_int = '0' and ( m_axis_tready = '1' or m_axis_tvalid_int = '0' ) then	
				if sr(1) /= std_logic_vector(to_unsigned(HEADER, m_axis_tdata'length)) then				-- IF WE HAVE VALID DATA IN THE SR BUT ONLY IN THE LAST BYTE (SR(0)), THAT MEANS THE FIRST BYTE IS THE HEADER
					m_axis_tvalid_int <= '1';															-- IF WE DON'T HAVE THE HEADER WE CAN SEND OUT THE FIRST BYTE (SR(1))
					m_axis_tdata <= sr(1);
				else
					m_axis_tvalid_int <= '0';															-- NOT PULLING READY HIGH IF WE HAVE THE HEADER IN THE SR
					s_axis_tready_int <= '1';
				end if;
				if send_last = '1' then																	-- SENDING TLAST AFTER DETECTING THE FOOTER
					m_axis_tlast <= '1';
					inside_packet <= '0';
					send_last <= '0';
				else
					m_axis_tlast <= '0';
				end if;
			end if;
			
			-- AXI HANDSHAKE --
			if m_axis_tvalid_int = '1' and m_axis_tready = '1' then
				m_axis_tvalid_int <= '0';
				s_axis_tready_int <= '1';
    
			end if;
			
		end if;
	end process;
   

end architecture;


