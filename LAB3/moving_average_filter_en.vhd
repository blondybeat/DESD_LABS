library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter_en is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		enable_filter	: in std_logic
	);
end moving_average_filter_en;
-- THIS MODULE IS A SWITCH BETWEEN THE MOVING AVERAGE FILTER AND AN ALL PASS FILTER
-- THE MOVING AVERAGE FILTER IS ENABLED WHEN enable_filter = '1', OTHERWISE THE ALL PASS FILTER IS USED
-- THE ALL PASS FILTER PASSES THE AUDIO DATA WITHOUT ANY MODIFICATION
architecture Behavioral of moving_average_filter_en is

	signal filter_tready : std_logic;
	signal filter_tvalid : std_logic;
	signal filter_tlast : std_logic;
	signal filter_tdata : std_logic_vector(TDATA_WIDTH-1 downto 0);

	signal allpass_tready : std_logic;
	signal allpass_tvalid : std_logic;
	signal allpass_tlast : std_logic;
	signal allpass_tdata : std_logic_vector(TDATA_WIDTH-1 downto 0);

	component moving_average_filter is  
	Generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH			: positive := 24
	    );
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);

	end component;

	component all_pass_filter is
	generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
    end component;
		


begin
	s_axis_tready <= filter_tready when enable_filter = '1' else allpass_tready;
	m_axis_tvalid <= filter_tvalid when enable_filter = '1' else allpass_tvalid;
	m_axis_tlast <= filter_tlast when enable_filter = '1' else allpass_tlast;
	m_axis_tdata <= filter_tdata when enable_filter = '1' else allpass_tdata;

	moving_average_filter_inst: moving_average_filter
	 generic map(
		FILTER_ORDER_POWER => FILTER_ORDER_POWER,
		TDATA_WIDTH => TDATA_WIDTH
	)
	 port map(
		aclk => aclk,
		aresetn => aresetn,
		s_axis_tvalid => s_axis_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast => s_axis_tlast,
		s_axis_tready => filter_tready,
		m_axis_tvalid => filter_tvalid,
		m_axis_tdata => filter_tdata,
		m_axis_tlast => filter_tlast,
		m_axis_tready => m_axis_tready
	);

	all_pass_filter_inst: all_pass_filter
	 generic map(
		TDATA_WIDTH => TDATA_WIDTH
	)
	 port map(
		aclk => aclk,
		aresetn => aresetn,
		s_axis_tvalid => s_axis_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast => s_axis_tlast,
		s_axis_tready => allpass_tready,
		m_axis_tvalid => allpass_tvalid,
		m_axis_tdata => allpass_tdata,
		m_axis_tlast => allpass_tlast,
		m_axis_tready => m_axis_tready
	);

end Behavioral;
