library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_multiplier is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_multiplier;
-- THE IDEA IS TO USE THE SAME APPROACH USED ALSO IN THE BALANCE CONTROLLER, BUT IN THIS CASE I WANT TO CONTROL APPLY THE SAME VOLUME IN BOTH CHANNELS
-- SINCE THE JOYSTICK COORDINATES ARE UNSIGNED WE NEED TO OFFSET THEM, THE CENTER POSITION IS 512
-- WE CALCULATE THE JOYSTICK UNIT AS (volume - 512) / 2**(VOLUME_STEP_2), THIS VALUE CAN BE POSITIVE OR NEGATIVE 
-- WE CAN USE IT AS AN EXPONENT OF 2 TO CALCULATE THE GAIN, SO IF IT'S NEGATIVE WE WILL NEED TO CONVERT IT IN POSITIVE VALUE
-- WE KEEP THE CHANNELS SEPARATED SINCE IT'S EASIER TO MANAGE THE TLAST SIGNAL
-- TO APPLY THE VOLUME WE SHIFT THE AUDIO DATA LEFT OR RIGHT BASED ON THE JOYSTICK UNIT VALUE

architecture Behavioral of volume_multiplier is
   --FSM DECLARATION
   type state_type is (GET_AUDIO_LEFT, GET_AUDIO_RIGHT, VOLUME_CALCULATION, SEND_LEFT, SEND_RIGHT);
   signal state : state_type := GET_AUDIO_LEFT;
   --SIGNAL DECLARATION
   signal left_channel : signed(TDATA_WIDTH-1 downto 0);
   signal right_channel : signed(TDATA_WIDTH-1 downto 0);
   --OUTPUT SIGNALS
   signal left_out : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
   signal right_out : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
   --JOYSTICK UNIT SIGNAL
   signal joystick_unit : integer range -8 to 8; 
   



begin

    joystick_unit <= (to_integer(unsigned(volume)) - 512) / 2**(VOLUME_STEP_2);

	with state select s_axis_tready <= 
	     '1' when GET_AUDIO_LEFT | GET_AUDIO_RIGHT,
	     '0' when OTHERS;

	with state select m_axis_tvalid <=
		'1' when SEND_LEFT | SEND_RIGHT,
		'0' when OTHERS;

	with state select m_axis_tdata <=
	   std_logic_vector(left_out) when SEND_LEFT,
	   std_logic_vector(right_out) when SEND_RIGHT,
	   (others => '-') when OTHERS;

	with state select m_axis_tlast <=
		'1' when SEND_RIGHT,
		'0' when OTHERS;


	process(aclk)
	begin
		
		    if aresetn = '0' then
				state <= GET_AUDIO_LEFT;
			elsif rising_edge(aclk) then
				case state is 
					when GET_AUDIO_LEFT => 
				    	if s_axis_tvalid = '1' then
					       	if s_axis_tlast = '0' then
							    left_channel <= signed(s_axis_tdata);
							    state <= GET_AUDIO_RIGHT;
						     end if;
						 end if;
					
					when GET_AUDIO_RIGHT => 
					   if s_axis_tvalid = '1' then
						  if s_axis_tlast = '1' then
							 right_channel <= signed(s_axis_tdata); 
							 state <= VOLUME_CALCULATION;
						  end if; 
					   end if;
					
					-- CALCULATE THE VOLUME BASED ON THE JOYSTICK UNIT
					-- IF THE JOYSTICK UNIT IS POSITIVE WE SHIFT LEFT MEANING WE INCREASE THE VOLUME, 
					-- IF IT'S NEGATIVE WE SHIFT RIGHT MEANING WE DECREASE THE VOLUME
					-- IF IT'S ZERO WE KEEP THE VOLUME AS IT IS
					-- WE NEED TO RESIZE THE OUTPUT TO MATCH THE M_AXIS_TDATA WIDTH

					when VOLUME_CALCULATION =>
						if joystick_unit > 0 then
							left_out <= resize(shift_left(left_channel, joystick_unit), m_axis_tdata'length);
							right_out <= resize(shift_left(right_channel, joystick_unit), m_axis_tdata'length);
						elsif joystick_unit < 0 then
							left_out <= resize(shift_right(left_channel, -(joystick_unit)), m_axis_tdata'length);
							right_out <= resize(shift_right(right_channel, -(joystick_unit)), m_axis_tdata'length);
						else
						    left_out <= resize(left_channel, m_axis_tdata'length);
						    right_out <= resize(right_channel, m_axis_tdata'length);
						end if;
						state <= SEND_LEFT;

						
					when SEND_LEFT => 
						if m_axis_tready = '1' then
							state <= SEND_RIGHT;
						end if;
						
					when SEND_RIGHT =>
						if m_axis_tready = '1' then
							state <= GET_AUDIO_LEFT;
						end if;
				end case;
			
		end if;
	end process;
end Behavioral;
