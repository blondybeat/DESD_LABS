---------- DEFAULT LIBRARIES -------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;	-- For LOG **FOR A CONSTANT!!**
------------------------------------


entity rgb2gray is
 Port (
		clk				: in std_logic;
		resetn			: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(7 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(7 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic
	);
end rgb2gray;

architecture Behavioral of rgb2gray is

	component division_lut is
		generic(
			SUM_WIDTH: POSITIVE := 9
		);
		Port (
			clk	: in std_logic;
			resetn : in std_logic;
			
			data_in : integer range 0 to 2**SUM_WIDTH -1;
			result : out std_logic_vector(6 downto 0);
			done : out std_logic;
			start : in std_logic
		);
	end component;

    --TDATA IS 8 BIT BUT R G B ARE IN THE RANGE 0 TO 127 (the color information is 7 bit, i don't use the MSB)
	--MAX SUM IS 3*127 = 381
	constant MAX_SUM : integer := 381;												-- MAXIMUM VALUE OF PIXEL SUMS
	constant SUM_WIDTH : integer := integer(ceil(log2(real(MAX_SUM+1)))); 			-- 9 BITS WIDE
	--INTERNAL SIGNALS
	signal s_axis_tready_int : std_logic := '1';
	signal m_axis_tvalid_int : std_logic := '0';
	signal m_axis_tdata_int : std_logic_vector(7 downto 0);
	
	signal send_last : std_logic := '0';											-- FLAG TO SEND THE LAST PIXEL
	signal red_color : std_logic_vector(6 downto 0);
	signal green_color : std_logic_vector(6 downto 0);
	signal blue_color : std_logic_vector(6 downto 0);
    type pixel_type is array (0 to 2) of std_logic_vector(6 downto 0);				-- DIFFERENTIATING PIXEL COLORS
	signal pixel : pixel_type := (others => (others => '0'));
	
	signal start_conversion : std_logic := '0';
	signal index : integer range 0 to 2 := 0;
	signal sum : integer range 0 to 2**SUM_WIDTH -1 := 0;
	signal result_div : std_logic_vector(6 downto 0);								-- RESULT OF DIVISION BY 3
	signal done_div : std_logic := '0';												
	signal start_div : std_logic := '0';
	signal start: std_logic := '0';
	signal m_axis_tlast_int : std_logic := '0';

begin
																					-- ASSIGNING INTERNAL SIGNALS, ALSO COLOR VALUES
	s_axis_tready <= s_axis_tready_int;
	m_axis_tvalid <= m_axis_tvalid_int;
	m_axis_tdata <= m_axis_tdata_int;
	red_color <= pixel(0);
	green_color <= pixel(1);
	blue_color <= pixel(2);
	m_axis_tlast <= m_axis_tlast_int;
	
	process(clk, resetn) 
	begin
		if resetn = '0' then
			m_axis_tvalid_int <= '0';
			s_axis_tready_int <= '0';
			m_axis_tdata_int <= (others => '0');
			pixel <= (others => (others => '0'));
			index <= 0;
			start_conversion <= '0';
			m_axis_tlast_int <= '0';
			s_axis_tready_int <= '0';
			start_div <= '0';
			send_last <= '0';
			sum <= 0;
			
			
		elsif rising_edge(clk) then 												
			if start = '0' then
				s_axis_tready_int <= '1';
				start <= '1';
			end if;
           
			if start_conversion = '1' then											-- CREATING PULSES FROM THE SIGNALS
				start_conversion <= '0';
			end if;

			if start_div = '1' then
				start_div <= '0';
			end if;
			
			if s_axis_tvalid = '1' and s_axis_tready_int = '1' then					-- WE PLACE THE COLOR INFORMATION INTO A 3 * 7-BIT WIDE REGISTER
				pixel(index) <= s_axis_tdata(6 downto 0);							-- 7 BIT COLOR INFORMATION
               
				if index = 2 then													-- WHEN ALL 3 COLORS ARRIVED WE START THE CONVERSION AND STOP RECEIVING DATA
					start_conversion <= '1';
					index <= 0;
					s_axis_tready_int <= '0';
					
				else
					index <= index + 1;
					start_conversion <= '0';
				end if;
				if s_axis_tlast = '1' then											-- LAST BYTE FLAG FOR SENDING TLAST
					send_last <= '1';
				end if;
			end if;
			if start_conversion = '1' then 											-- BIT PADDING OF 2 BITS BECAUSE WE ARE SUMMING 3 COLORS, TO AVOID OVERFLOW
				sum <= to_integer(('0'&'0'&unsigned(red_color)) + ('0'&'0'&unsigned(green_color)) + ('0'&'0'&unsigned(blue_color)));
				start_div <= '1';
			end if;
            
			if m_axis_tready = '1' or m_axis_tvalid_int = '0' then
				if done_div = '1' then												-- OUTPUTTING THE DATA WHEN THE DIVISION IS DONE
					m_axis_tvalid_int <= '1';
					m_axis_tdata_int <= '0'& result_div;
				else
					m_axis_tvalid_int <= '0';
				end if;
				
				if send_last = '1' then												-- SENDING TLAST
					m_axis_tlast_int <= '1';
					send_last <= '0';
				end if;
			
			end if;

			if m_axis_tvalid_int = '1' and m_axis_tready = '1' then					-- AXI HANDSHAKE
				m_axis_tvalid_int <= '0';
				s_axis_tready_int <= '1';
				if m_axis_tlast_int <= '1' then
					m_axis_tlast_int <= '0';
				end if;
			end if;
       
       
			
		end if;
	end process;
    
	-- INSTANTIATION OF THE DIVISION MODULE
	division_inst: division_lut
	generic map (
		SUM_WIDTH => SUM_WIDTH  
	)
	port map (
		clk => clk,
		resetn => resetn,
		data_in => sum,
		result => result_div,
		done => done_div,
		start => start_div
	);


end Behavioral;

