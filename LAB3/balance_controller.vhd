library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is
-- WE NEED TO OFFSET THE JOYSTICK COORDINATES SINCE THEY ARE UNSIGNED,
-- WE DECIDE TO USE THE UNSIGNED VALUE AND SUBTRACT 512 FROM IT SINCE IT'S THE CENTER POSITION OF THE JOYSTICK
-- IF BALANCE > 512 DECREASE LEFT CHANNEL
-- IF BALANCE < 512 DECREASE RIGHT CHANNEL
-- IF BALANCE = 512 NO CHANGE 
-- JOYSTICK UNIT = (BALANCE - 512)/2**(BALANCE_STEP_2)
-- GAIN = 2**JOYSTICK_UNIT  WE WILL DIVIDE FOR THIS GAIN
-- THE JOYSTICK UNIT CAN BE POSITIVE OR NEGATIVE, BUT SINCE IS THE EXPONENT OF OUR GAIN WE WILL STORE ONLY THE POSITIVE VALUE
-- WE NEED TO SEPARATE THE CHANNELS IN ORDER TO APPLY THE BALANCE CORRECTLY
signal left_channel, right_channel: signed (TDATA_WIDTH-1 downto 0);                        --INPUT CHANNEL SIGNALS
signal balanced_left : signed(TDATA_WIDTH-1 downto 0);                                      --OUTPUT BALANCED CHANNEL SIGNAL
signal balanced_right : signed(TDATA_WIDTH-1 downto 0);

--FSM DECLARATION
type state_type is (IDLE, CONTROL_STATE, BALANCE_STATE, SEND_LEFT, SEND_RIGHT);
signal state : state_type := IDLE;

signal joystick_unit : integer range -8 to 8;                        -- JOYSTICK UNIT = (BALANCE - 512)/2**(BALANCE_STEP_2)
signal balance_unit : natural range 0 to 8;                          -- TO STORE ONLY THE POSITIVE VALUE OF JOYSTICK UNIT

begin
    balance_unit <= - joystick_unit when to_integer(unsigned(balance)) < 512 else joystick_unit;
	
	with state select m_axis_tvalid <=
	     '1' when SEND_LEFT,
	     '1' when SEND_RIGHT,
         '0' when OTHERS;
			
	with state select s_axis_tready <= 
	     '1' when IDLE,
	     '0' when OTHERS;

	with state select m_axis_tdata <= 
		std_logic_vector(balanced_left) when SEND_LEFT,
		std_logic_vector(balanced_right) when SEND_RIGHT,
		(others => '0') when OTHERS;
		
	with state select m_axis_tlast <= 
		'1' when SEND_RIGHT,
		'0' when OTHERS;
	
	process(aclk,aresetn) 
	begin
		
		if aresetn = '0' then
		      state <= IDLE;
		elsif rising_edge(aclk) then
			  case state is 
				when IDLE =>
				    if s_axis_tvalid = '1' then
						if s_axis_tlast = '1' then
							right_channel <= signed(s_axis_tdata);
							state <= CONTROL_STATE;
						else 
							left_channel <= signed(s_axis_tdata);   	
						end if;
						
				    end if;
				when CONTROL_STATE =>
				    joystick_unit <= (to_integer(unsigned(balance)) - 512) / 2**(BALANCE_STEP_2); 
				    state <= BALANCE_STATE;
				
				-- SINCE WE NEED TO DIVIDE BY 2**BALANCE_UNIT THAT IS A POWER OF TWO WE USE A SHIFT TO THE RIGHT
				-- IF JOYSTICK UNIT IS POSITIVE WE DECREASE THE LEFT CHANNEL
				-- IF JOYSTICK UNIT IS NEGATIVE WE DECREASE THE RIGHT CHANNEL
				-- IF JOYSTICK UNIT IS ZERO WE KEEP THE CHANNELS UNCHANGED
				when BALANCE_STATE =>
				    if joystick_unit > 0 then
					   balanced_left <=  shift_right(left_channel, balance_unit);                             
					   balanced_right <= right_channel;
					elsif joystick_unit < 0 then
					   balanced_left <= left_channel;
					   balanced_right <= shift_right(right_channel, balance_unit);
					else
					   balanced_left <= left_channel;
					   balanced_right <= right_channel;
					end if;
                    state <= SEND_LEFT;
				
				when SEND_LEFT => 
				    if m_axis_tready = '1' then
						state <= SEND_RIGHT;
					end if;
				
				when SEND_RIGHT =>
				    if m_axis_tready = '1' then
						state <= IDLE;
					end if;     
				end case;
			
		end if;
	end process;    
				   
					

end Behavioral;
