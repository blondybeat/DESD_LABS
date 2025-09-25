library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity digilent_jstk2 is
	generic (
		DELAY_US		: integer := 25;    -- Delay (in us) between two packets
		CLKFREQ		 	: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ 	: integer := 66_666 -- Frequency of the SPI SCLK clock signal (in Hz)
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

		-- Joystick and button values read from the module
		jstk_x			: out std_logic_vector(9 downto 0);
		jstk_y			: out std_logic_vector(9 downto 0);
		btn_jstk		: out std_logic;
		btn_trigger		: out std_logic;

		-- LED color to send to the module
		led_r			: in std_logic_vector(7 downto 0);
		led_g			: in std_logic_vector(7 downto 0);
		led_b			: in std_logic_vector(7 downto 0)
	);
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is

	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
	constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";

	-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
	------------------------------------------------------------
	constant DELAY_IN_CLK_CYCLES : integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;
	
	-- WE USE THE STANDARD 5 BYTE PACKET FOR THE SPI COMMUNICATION, SO WE HAVE 5 BYTES: SET COMMAND, RED, GREEN, BLUE, DUMMY
	-- ONE STATE FOR EACH BYTE, PLUS ONE FOR WAITING THE DELAY
	type state_set_rgb_type is (IDLE, SEND_SETLEDRGB, SEND_RED, SEND_GREEN, SEND_BLUE, DUMMY);
	signal state_set_rgb : state_set_rgb_type;
	signal cycle_counter : integer range 0 to DELAY_IN_CLK_CYCLES - 1 := 0;
	
	-- IN ORDER TO SEND THE NEWEST COORDINATES DATA WE NEED TO WAIT UNTIL WE HAVE ALL THE POSITIONS AND BUTTONS, THEN SET THE OUTPUT PORTS
	-- THE PACKET STRUCTURE IS THE FOLLOWING: 5 BYTES, FIRST smpX (LOW BYTE), smpX (HIGH BYTE), SAME FOR Y, THEN BUTTONS
	-- WE CAN SET THE OUTPUT PORTS AS THE LAST BYTE ARRIVES WITH THE BUTTONS INFORMATION, THE COORDINATES WE CAN STORE IN BUFFERS IN THE MEANTIME
	type state_jstk_type is (X_LOW_BYTE, X_HIGH_BYTE, Y_LOW_BYTE, Y_HIGH_BYTE, SEND_COORDINATES);
	signal state_jstk : state_jstk_type := X_LOW_BYTE;
	signal jstk_x_buffer : std_logic_vector(9 downto 0);
	signal jstk_y_buffer : std_logic_vector(9 downto 0);

	
begin

	with state_set_rgb select m_axis_tdata <= 
		CMDSETLEDRGB when SEND_SETLEDRGB,
		led_r when SEND_RED, 
		led_g when SEND_GREEN,
		led_b when SEND_BLUE,
		(others => '-') when OTHERS;
	
	with state_set_rgb select m_axis_tvalid <= 
		'0' when IDLE,
		'1' when OTHERS;
		
	
	process(aclk)
	begin
        if rising_edge(aclk) then
		    if aresetn = '0' then
				cycle_counter <= 0;
				state_set_rgb <= IDLE;
			else
				case state_set_rgb is 
					when IDLE => 
						if cycle_counter = DELAY_IN_CLK_CYCLES - 1 then
							cycle_counter <= 0;
							state_set_rgb <= SEND_SETLEDRGB;
						else
							cycle_counter <= cycle_counter + 1;
						end if;
						
					when SEND_SETLEDRGB => 
						if m_axis_tready = '1' then 
							state_set_rgb <= SEND_RED;
						end if;
						
					when SEND_RED => 
						if m_axis_tready = '1' then 
							state_set_rgb <= SEND_GREEN;
						end if;
						
					when SEND_GREEN => 
						if m_axis_tready = '1' then 
							state_set_rgb <= SEND_BLUE;
						end if;
					
					when SEND_BLUE => 
						if m_axis_tready = '1' then 
							state_set_rgb <= DUMMY;
						end if;
						
					when DUMMY => 
						if m_axis_tready = '1' then 
							state_set_rgb <= IDLE;
						end if;			
				end case;
			end if;
		end if;
	end process;
	
	process(aclk)
	begin
		if rising_edge(aclk) then
		    if aresetn = '0' then
				state_jstk <= X_LOW_BYTE;

			else

			    if s_axis_tvalid = '1' then
					case state_jstk is
						when X_LOW_BYTE => 
							jstk_x_buffer(7 downto 0) <= s_axis_tdata;
							state_jstk <= X_HIGH_BYTE;
				
						when X_HIGH_BYTE =>
							jstk_x_buffer(9 downto 8) <= s_axis_tdata(1 downto 0);
							state_jstk <= Y_LOW_BYTE;
							
						when Y_LOW_BYTE => 
							jstk_y_buffer(7 downto 0) <= s_axis_tdata;
							state_jstk <= Y_HIGH_BYTE;
							
						when Y_HIGH_BYTE => 
							jstk_y_buffer(9 downto 8) <= s_axis_tdata(1 downto 0);
							state_jstk <= SEND_COORDINATES;
							
						when SEND_COORDINATES => 
							btn_jstk <= s_axis_tdata(0);
							btn_trigger <= s_axis_tdata(1);
							jstk_x <= jstk_x_buffer;
							jstk_y <= jstk_y_buffer;
							state_jstk <= X_LOW_BYTE;
					end case;
				end if;
			end if;
		end if;
    end process;
end architecture;
