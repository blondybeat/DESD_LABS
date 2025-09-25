library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;
        JOYSTICK_LENGHT  : integer := 10;
        CLK_PERIOD_NS   : integer := 10;
        TRIANGULAR_COUNTER_LENGHT    : integer := 10 -- Triangular wave period length
    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

-- CONSTANTS
constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000; -- Base period of the LFO counter in us (when the joystick is at the center)
constant LFO_COUNTER_BASE_PERIOD_CLK_CYCLES : integer := 1000 * LFO_COUNTER_BASE_PERIOD_US/CLK_PERIOD_NS; -- Base period of the LFO counter in clock cycles
constant ADJUSTMENT_FACTOR : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position

-- START DECREASING OR INCREASING THE MULTIPLICATION FACTOR IN THE NEXT CLOCK CYCLE  AFTER REACHING THESE NUMBERS
constant FACTOR_UPPER_LIMIT : signed(TRIANGULAR_COUNTER_LENGHT-1 downto 0) := to_signed(2**(TRIANGULAR_COUNTER_LENGHT)-1, TRIANGULAR_COUNTER_LENGHT); 
constant FACTOR_LOWER_LIMIT : signed(TRIANGULAR_COUNTER_LENGHT-1 downto 0) := to_signed(0, TRIANGULAR_COUNTER_LENGHT);

-- LFO PERIOD CONVERTED TO CLOCK CYCLES
signal lfo_period_converted : integer range 0 to (LFO_COUNTER_BASE_PERIOD_CLK_CYCLES);

-- BUFFERS FOR INPUT AND OUTPUT AUDIO DATA
signal audio_left : signed(CHANNEL_LENGHT - 1 downto 0);
signal audio_right : signed(CHANNEL_LENGHT - 1 downto 0);
signal audio_left_modulated : signed(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT-1 downto 0);
signal audio_right_modulated : signed(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT-1 downto 0);

-- STATES FOR ACQUIRING, MODULATING AND SENDING AUDIO DATA
type state_type is (GET_AUDIO_LEFT, GET_AUDIO_RIGHT, MODULATE, SEND_AUDIO_LEFT, SEND_AUDIO_RIGHT);
signal state : state_type := GET_AUDIO_LEFT;

-- STATES FOR CALCULATING THE ACTUAL VALUE OF THE TRIANGULAR WAVE
type modulation_type is (WAIT_PERIOD, CALCULATE_FACTOR);
signal modulation : modulation_type;

-- IDEA: RUN A COUNTER WHICH HAS THE VALUE OF THE ACTUAL LFO PERIOD IN CLOCK CYCLES
-- IF THE COUNTER REACHES THAT NUMBER, WE INCREASE/DECREASE THE TRIANGULAR WAVE VALUE BY ONE, DEPENDING ON THE COUNTING DIRECTION
type dir_type is (COUNT_UP, COUNT_DOWN);
signal dir : dir_type := COUNT_UP;
signal cycle_counter : integer range 0 to LFO_COUNTER_BASE_PERIOD_CLK_CYCLES := 0;

-- TRIANGULAR WAVE ACTUAL VALUE FROM 0 TO 1, IN 1024 STEPS
signal MULTIPLICATION_FACTOR : signed(TRIANGULAR_COUNTER_LENGHT-1 downto 0):= ((others => '0'));

begin  


	-- AXI COMMUNICATION LINES DEPENDING ON THE STATES
	with state select s_axis_tready <= 
		'1' when GET_AUDIO_LEFT | GET_AUDIO_RIGHT,
		'0' when OTHERS;
		
	with state select m_axis_tvalid <= 
		'1' when SEND_AUDIO_LEFT,
		'1' when SEND_AUDIO_RIGHT,
		'0' when OTHERS;
		
	with state select m_axis_tdata <= 
		std_logic_vector(audio_left) when SEND_AUDIO_LEFT,
		std_logic_vector(audio_right) when SEND_AUDIO_RIGHT,
		(others => '-') when OTHERS;
		
	with state select m_axis_tlast <= 
		'1' when SEND_AUDIO_RIGHT,
		'0' when OTHERS;


	process(aclk)
	begin
		
		if aresetn = '0' then
				state <= GET_AUDIO_LEFT;
		elsif rising_edge(aclk) then
				case state is
                    -- SAVING THE AUDIO CHANNELS INTO REGISTERS, IF WE ENABLED THE MODULATION, WE NEED TO MULTIPLY THE DATA WITH A FRACTION
					-- THIS FRACTION IS MULTIPLICATION_FACTOR / 1024, SINCE WE DON'T WANT A BOOST IN THE VOLUME, WHEN THE FACTOR IS 1024 WE KEEP THE ORIGINAL VOLUME
					-- THEREFORE FIRST WE MULTIPLY, THEN IN THE NEXT PHASE WE SHIFT BY 10 BITS, WHICH IS EQUIVALENT TO A DIVISION BY 1024
					
					-- THESE 2 STATES TAKE CARE OF THE AUDIO ACQUISITION AND MULTIPLICATION IF NECESSARY
					when GET_AUDIO_LEFT => 
						if s_axis_tvalid = '1' then
							if s_axis_tlast = '0' then
								audio_left_modulated <= signed(s_axis_tdata) * MULTIPLICATION_FACTOR;
								audio_left <= signed(s_axis_tdata);
							end if;
							state <= GET_AUDIO_RIGHT;
						end if;
					
					when GET_AUDIO_RIGHT => 
						if s_axis_tvalid = '1' then
							if s_axis_tlast = '1' then
								audio_right_modulated <= signed(s_axis_tdata) * MULTIPLICATION_FACTOR;
								audio_right <= signed(s_axis_tdata);
							end if;
							state <= MODULATE;
						end if;						
					
                    -- THIS STATE TAKES CARE OF THE DIVISION	
					when MODULATE => 
					    if lfo_enable = '1' then
		  		      		audio_left <= resize(shift_right(audio_left_modulated, TRIANGULAR_COUNTER_LENGHT), CHANNEL_LENGHT);
			 			    audio_right <= resize(shift_right(audio_right_modulated, TRIANGULAR_COUNTER_LENGHT), CHANNEL_LENGHT);
						end if;
						state <= SEND_AUDIO_LEFT;
					
                    -- SENDING AUDIO OUT	
					when SEND_AUDIO_LEFT =>
						if m_axis_tready = '1' then
							state <= SEND_AUDIO_RIGHT;
						end if;
					
					when SEND_AUDIO_RIGHT =>
						if m_axis_tready = '1' then
							state <= GET_AUDIO_LEFT;
						end if;
					
				end case;	
		    
		end if;	
	end process;
	
	modulation_prc : process(aclk)
	begin
		
    	if aresetn = '0' then
	       		cycle_counter <= 0;
			    modulation <= WAIT_PERIOD;
		elsif rising_edge(aclk) then
               
                -- UPDATE LFO_PERIOD IN EACH CLOCK CYCLE
			    lfo_period_converted <= LFO_COUNTER_BASE_PERIOD_CLK_CYCLES - ADJUSTMENT_FACTOR * to_integer(unsigned(lfo_period));

                -- CHANGE DIRECTIONS DEPENDING ON THE COUNTER VALUE
			    if MULTIPLICATION_FACTOR = FACTOR_UPPER_LIMIT then
				    dir <= COUNT_DOWN;
	           		end if;
			    if MULTIPLICATION_FACTOR = FACTOR_LOWER_LIMIT then
				    dir <= COUNT_UP;
			    end if;
			
			    case modulation is

                    -- THIS STATE RUNS THE LFO COUNTER FOR THE PERIOD
				    when WAIT_PERIOD => 
					   if cycle_counter >= lfo_period_converted - 1 then 
						  modulation <= CALCULATE_FACTOR;
						  cycle_counter <= 0;
					   else
						  cycle_counter <= cycle_counter + 1;
				    	end if;
				    
                    -- IN THIS STATE WE CALCULATE THE NUMERATOR OF THE FRACTION, WHICH INCREASES OR DECREASES BY ONE AFTER EACH LFO PERIOD
				    when CALCULATE_FACTOR =>
					   if dir = COUNT_UP then 
					       MULTIPLICATION_FACTOR <= MULTIPLICATION_FACTOR + to_signed(1, TRIANGULAR_COUNTER_LENGHT);
					   elsif dir = COUNT_DOWN then
						  MULTIPLICATION_FACTOR <= MULTIPLICATION_FACTOR - to_signed(1, TRIANGULAR_COUNTER_LENGHT);					
					   end if;
				       modulation <= WAIT_PERIOD;
			         end case;
		    
		end if;
		
	end process;

end architecture;