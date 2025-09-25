library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_saturator is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND	: integer := 2**15-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**15		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end volume_saturator;
-- THE IDEA IS TO SATURATE THE AUDIO SIGNALS COMING FROM THE VOLUME MULTIPLIER TO A GIVEN RANGE
-- THE RANGE IS DEFINED BY THE HIGHER_BOUND AND LOWER_BOUND GENERICS
-- WE ALWAYS KEEP THE RIGHT AND LEFT CHANNELS SEPARATED SINCE IT'S EASIER TO MANAGE THE TLAST SIGNAL

architecture Behavioral of volume_saturator is
    --FSM DECLARATION
	type state_type is (GET_AUDIO_LEFT, GET_AUDIO_RIGHT, SATURATE, SEND_LEFT, SEND_RIGHT);
    signal state : state_type := GET_AUDIO_LEFT;
	
	--INTERNAL SIGNALS
	signal left_channel : signed(TDATA_WIDTH -1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
	signal right_channel : signed(TDATA_WIDTH -1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);	
	
	--OUTPUT SIGNALS
	signal left_out : signed(TDATA_WIDTH-1 downto 0);
	signal right_out : signed(TDATA_WIDTH-1 downto 0);
	signal data_out : signed(TDATA_WIDTH-1 downto 0);

begin

	with state select m_axis_tdata <= 
		std_logic_vector(left_out) when SEND_LEFT,
		std_logic_vector(right_out) when SEND_RIGHT,
		(others => '-') when OTHERS;
		
		with state select m_axis_tlast <=
			'1' when SEND_RIGHT,
			'0' WHEN OTHERS;
			
		with state select s_axis_tready <= 
			'1' when GET_AUDIO_LEFT | GET_AUDIO_RIGHT,
			'0' when OTHERS;
			
		with state select m_axis_tvalid <= 
			'1' when SEND_LEFT | SEND_RIGHT,
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
							state <= SATURATE;
						end if;
					end if;
						
					when SATURATE => 
						if left_channel >= HIGHER_BOUND then
							left_out <= to_signed(HIGHER_BOUND, TDATA_WIDTH);
						elsif left_channel <= LOWER_BOUND then
							left_out <= to_signed(LOWER_BOUND, TDATA_WIDTH);
						else
							left_out <= resize(left_channel, TDATA_WIDTH);
						end if;
						
						if right_channel >= HIGHER_BOUND then
							right_out <= to_signed(HIGHER_BOUND, TDATA_WIDTH);
						elsif right_channel <= LOWER_BOUND then
							right_out <= to_signed(LOWER_BOUND, TDATA_WIDTH);
						else
							right_out <= resize(right_channel, TDATA_WIDTH);
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
