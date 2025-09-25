
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_level_controller is
    generic(
        NUM_LEDS : positive := 16;
        CHANNEL_LENGHT  : positive := 24;
        refresh_time_ms: positive :=1;
        clock_period_ns: positive :=10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led    : out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic

    );
end led_level_controller;
-- THE IDEA IS TO USE A LOG SCALE TO LIGHT UP THE 16 LEDS BASED ON THE AVERAGE AUDIO LEVEL
-- THE AVERAGE AUDIO LEVEL IS CALCULATED FROM THE LEFT AND RIGHT CHANNELS IN MODULUS
-- TO GET A LOGSCALE WE USE A FUNCTION THAT RETURNS THE NUMBER OF LED THAT NEED TO LIGHT UP BASED ON THE FIRST BIT SET TO 1 FROM THE MSB IN THE AVERAGE AUDIO LEVEL
-- THIS SOLUTION IS MORE SENSITIVE WITH RESPECT TO THE ONE PROVIDED IN THE ENCRYPTED BITSTREAM
architecture Behavioral of led_level_controller is
-- FOR EXAMPLE IF I HAVE 2**8 THE 1 BIT POSITION IS 8 SO I WILL LIGHT UP 1 LED, IF I HAVE 2**9 THE 1 BIT POSITION IS 9 SO I WILL LIGHT UP 2 LEDS, AND SO ON
	function led_count_function(average : unsigned) return natural is
		variable count : natural := 0;
	begin
		loop_function:  for i in average'length-1 downto 0 loop
			  if average(i) = '1' then
				 count := i+1;
				 exit loop_function;
			  end if;
		  end loop loop_function;
		  if count <= 8 then
			  return 0;
		  else
			  return count-8; -- ADJUST COUNT TO MATCH THE NUMBER OF LEDS
		  end if;
		
	end led_count_function;

	constant REFRESH_TIME_CLK_CYCLES : positive := refresh_time_ms * 1_000_000 / clock_period_ns;
	
	-- LED VALUES CORRESPONDING TO THE THRESHOLDS (LIKE A LUT FOR THE LEDS)
    type led_value is array(0 to NUM_LEDS) of std_logic_vector(NUM_LEDS-1 downto 0);
    constant led_out : led_value := ( x"0000", x"0001", x"0003", x"0007", x"000F", 
                                        x"001F", x"003F", x"007F", x"00FF", x"01FF", 
                                        x"03FF", x"07FF", x"0FFF", x"1FFF", x"3FFF", 
                                        x"7FFF", x"FFFF"); 
    

    
    signal sum : signed(CHANNEL_LENGHT-1 downto 0) := (others => '0');
	signal refresh_time_counter : natural range 0 to REFRESH_TIME_CLK_CYCLES-1 := 0;
	
	-- FSM DECLARATION
	type state_type is (WAIT_REFRESH_TIME, GET_AUDIO_LEFT, GET_AUDIO_RIGHT, AVERAGE, SET_LED);
	signal state : state_type := WAIT_REFRESH_TIME;
	signal averaged_channels : unsigned(CHANNEL_LENGHT-1 downto 0) := (others => '0');
   
    signal led_count : natural range 0 to NUM_LEDS := 0; -- SIGNAL TO COUNT THE NUMBER OF LEDS TO LIGHT UP 

begin
	
	
	s_axis_tready <= '1';              -- ALWAYS READY TO RECEIVE TO NOT MESSED UP THE SOUND SINCE WE HAVE AN AXI BROADCAST INTERFACE IN THE BD
    led <= led_out(led_count);         -- ASSIGN THE LED OUTPUT BASED ON THE LED COUNT
	 
	
	process(aclk, aresetn)
     
	begin
	    
		if aresetn = '0' then
			state <= WAIT_REFRESH_TIME;
			refresh_time_counter <= 0;
			sum <= (others => '0');
			led_count <= 0;
        
        elsif rising_edge(aclk) then
			    case state is 
					when WAIT_REFRESH_TIME => 
						
						if refresh_time_counter = REFRESH_TIME_CLK_CYCLES-1 then
							refresh_time_counter <= 0;
							sum <= (others => '0');
							state <= GET_AUDIO_LEFT;
						else
							refresh_time_counter <= refresh_time_counter + 1;
						end if;
						
					when GET_AUDIO_LEFT =>                                 -- FIRST WE RECEIVE THE LEFT CHANNEL
						if s_axis_tvalid = '1' then
							if s_axis_tlast = '0' then
                                if signed(s_axis_tdata) >= 0 then
								   sum <= sum + signed(s_axis_tdata);
                                else
                                   sum <= sum - signed(s_axis_tdata);
                                end if;
                                    
							end if;
							state <= GET_AUDIO_RIGHT;
						end if;
						
					when GET_AUDIO_RIGHT =>                           -- THEN WE RECEIVE THE RIGHT CHANNEL
						if s_axis_tvalid = '1' then
							if s_axis_tlast = '1' then
							    if signed(s_axis_tdata) >= 0 then
								   sum <= sum + signed(s_axis_tdata);
                                else
                                   sum <= sum - signed(s_axis_tdata);
                                end if;
							end if;
							state <= AVERAGE;
						end if;
						
					when AVERAGE => 
						averaged_channels <= unsigned(sum) / 2;       -- AVERAGE THE LEFT AND RIGHT CHANNELS, WE CAN DIRECTLY DIVIDE BY 2 
						state <= SET_LED;
						
					when SET_LED => 
                        led_count <= led_count_function(averaged_channels);
					    state <= WAIT_REFRESH_TIME;
				end case;
			
		end if;
		
	end process;
    

end Behavioral;

