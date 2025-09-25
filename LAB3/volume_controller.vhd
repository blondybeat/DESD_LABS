library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**23		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0); --signed
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_controller;
-- THIS MODULE IS A COMBINATION OF THE VOLUME MULTIPLIER AND THE VOLUME SATURATOR
-- IT TAKES THE AUDIO DATA AND THE VOLUME CONTROL SIGNAL AND APPLIES THE VOLUME,
-- IF NECESSARY IT SATURATE THE RESULTING AUDIO DATA TO A GIVEN RANGE
architecture Behavioral of volume_controller is
	component volume_multiplier is
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
	end component;

	component volume_saturator is
		Generic (
		   TDATA_WIDTH		: positive := 24;
		   VOLUME_WIDTH	    : positive := 10;
		   VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		   HIGHER_BOUND	    : integer := 2**15-1;	-- Inclusive
		   LOWER_BOUND		: integer := -2**15		-- Inclusive
	);
	    Port (
		   aclk			    : in std_logic;
		   aresetn			: in std_logic;

		   s_axis_tvalid	: in std_logic;
		   s_axis_tdata	    : in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		   s_axis_tlast	    : in std_logic;
		   s_axis_tready	: out std_logic;

		   m_axis_tvalid	: out std_logic;
		   m_axis_tdata	    : out std_logic_vector(TDATA_WIDTH-1 downto 0);
		   m_axis_tlast	    : out std_logic;
		   m_axis_tready	: in std_logic
	);

	end component;
    

    signal m_axis_tvalid_int : std_logic;
	signal m_axis_tdata_int: std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
	signal m_axis_tready_int : std_logic;
	signal m_axis_tlast_int : std_logic;	

begin
   
	volume_multiplier_inst: volume_multiplier
	Generic map (
		TDATA_WIDTH => TDATA_WIDTH,
		VOLUME_WIDTH => VOLUME_WIDTH,
		VOLUME_STEP_2 => VOLUME_STEP_2
	)
	Port map (
		aclk => aclk,
		aresetn => aresetn,

		s_axis_tvalid => s_axis_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast => s_axis_tlast,
		s_axis_tready => s_axis_tready,

		m_axis_tvalid => m_axis_tvalid_int,
		m_axis_tdata => m_axis_tdata_int,
		m_axis_tlast => m_axis_tlast_int,
		m_axis_tready => m_axis_tready_int,

		volume => volume
	);
	
	volume_saturator_inst: volume_saturator
	Generic map (
		TDATA_WIDTH => TDATA_WIDTH,
		VOLUME_WIDTH => VOLUME_WIDTH,
		VOLUME_STEP_2 => VOLUME_STEP_2,
		HIGHER_BOUND => HIGHER_BOUND,
		LOWER_BOUND => LOWER_BOUND
	)
	Port map (
		aclk => aclk,
		aresetn => aresetn,

		s_axis_tvalid => m_axis_tvalid_int,
		s_axis_tdata => m_axis_tdata_int,
		s_axis_tlast => m_axis_tlast_int,
		s_axis_tready => m_axis_tready_int,

		m_axis_tvalid => m_axis_tvalid,
		m_axis_tdata => m_axis_tdata,
		m_axis_tlast => m_axis_tlast,
		m_axis_tready => m_axis_tready
	);
	

end Behavioral;
