library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE :=16 --256*256 GREY PIXELS
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE :=16
        );
        port (
            clk   : in std_logic;
            aresetn : in std_logic;
    
            addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout: out std_logic_vector(7 downto 0);
            din: in std_logic_vector(7 downto 0);
            we: in std_logic
        );
    end component;

    --FSM 
	type state_type is (IDLE, WRITE_STATE, READ_STATE);
	signal state : state_type := IDLE;
	--BRAM SIGNALS
	signal bram_dout : std_logic_vector(7 downto 0);
	signal bram_we : std_logic;
	signal bram_addr : std_logic_vector(ADDR_WIDTH-1 downto 0); 
	signal bram_din : std_logic_vector(7 downto 0);
	signal s_axis_tready_int : std_logic; 
	signal pixel_count : natural range 0 to 2**ADDR_WIDTH := 0; --TO COUNT THE NUMBER OF THE PIXELS I STORE IN THE BRAM
	signal bram_addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others =>'0'); 
	signal start_conv_reg : std_logic := '0'; -- THIS DELAYS THE START_CONV SIGNAL WITH ONE CLOCK CYCLE AND THUS WE CAN FINISH WRITING
    
    --WE STORED ALL THE GREY PIXELS IN THE BRAM DURING THE WRITE STATE, 
    --THEN I CAN START THE CONVOLUTION, WE READ THE ADRESS FROM THE IMG_CONV MODULE AND WITH THAT
    --WE SELECT THE RIGHT GREY PIXEL FROM THE BRAM THANKS TO THE BRAM_CONTROLLER
  

begin

	s_axis_tready <= s_axis_tready_int;
        
	bram_inst: bram_controller
	generic map (
		ADDR_WIDTH => ADDR_WIDTH  
	)
	port map (
		clk => clk,
		aresetn => aresetn,
		addr => bram_addr,
		dout => bram_dout,
		din => bram_din,
		we => bram_we
	);
    
	-- IN ORDER TO DRIVE THE BRAM ADDRESS WITH TWO DIFFERENT SIGNALS WE HAVE TO MULTIPLEX THEM
	with state select bram_addr <= 
		(others => '0') when IDLE,								-- WHEN WRITING WE FEED THE ADDRESS RELEVANT TO THE PIXEL_COUNT
		bram_addr_reg when WRITE_STATE,							-- WHEN READING WE FEED THE CONV_ADDR FROM THE CONVOLUTION MODULE
		conv_addr when READ_STATE;								-- THIS WAY IN THE MOMENT EITHER OF THESE CHANGE, THE UPGRADED VALUE CAN BE SEEN IMMEDIATELY AT THE BRAM'S INPUT
																
	with state select conv_data <= 
		(others => '0') when IDLE,
		(others => '0') when WRITE_STATE,
		bram_dout(6 downto 0) when READ_STATE; 					-- IT TAKES THE BRAM CONTROLLER ONE CLOCK CYCLE TO PUT THE DATA OUUT TO THE REQUESTED ADDRESS
																-- THIS WAY THE CONVOLUTION MODULE CAN ACCESS THE DATA WITH THE MIMINUM POSSIBLE DELAY
	FSM : process(state, clk, aresetn)							-- WHEN WRITING WE FEED THE ADDRESS RELEVANT TO THE PIXEL_COUNT
	begin														-- WHEN READING WE FEED THE CONV_ADDR FROM THE CONVOLUTION MODULE
		if aresetn = '0' then									-- THIS WAY IN THE MOMENT EITHER OF THESE CHANGE, THE UPGRADED VALUE CAN BE SEEN IMMEDIATELY AT THE BRAM'S INPUT
			state <= IDLE;
			bram_we <= '0';
			start_conv <= '0';
			bram_addr_reg <= (others => '0'); 
			pixel_count <= 0;   
			s_axis_tready_int <= '0';
			write_ok <= '0';
			overflow <= '0';
			underflow <= '0';  
		elsif rising_edge(clk) then

			case state is 
				when IDLE =>
					s_axis_tready_int <= '1';    
					write_ok <= '0';
					overflow <= '0';
					underflow <= '0';
					pixel_count <= 0; 
					bram_we <= '0';
					start_conv <= '0'; 
					state <= WRITE_STATE;
				when WRITE_STATE => 							-- WE ARE RUNNNING A COUNTER THAT IS INDICATIONG WHICH BRAM ADDRESS WE WRITE TO
					if s_axis_tvalid = '1' and s_axis_tready_int = '1' then
						bram_we <= '1';							-- ENABLING WRITING TO THE BRAM
						bram_din <= s_axis_tdata;				-- WRITING INPUT DATA INTO THE BRAM CONTROLLER INPUT
						bram_addr_reg <= std_logic_vector(to_unsigned(pixel_count, ADDR_WIDTH));
						pixel_count <= pixel_count + 1;

						if s_axis_tlast = '1' then				-- HANDLING THE NUMBER OF ARRIVED PIXELS AFTER WE DETECT TLAST
							s_axis_tready_int <= '0';			
							if pixel_count = (2**ADDR_WIDTH)-1 then
								write_ok <= '1';
								start_conv_reg <= '1';			-- STARTING CONVOLUTION WITH ONE CLOCK CYCLE DELAY
							elsif pixel_count >= (2**ADDR_WIDTH) then 
								overflow <= '1';
								start_conv_reg <= '1';
							else 
								underflow <= '1';
								start_conv_reg <= '1';
							end if;
						end if;
                    end if;
                    
					if start_conv_reg = '1' then 				-- CREATING PULSES FROM THE SIGNALS
							start_conv_reg <= '0';
							start_conv <= '1'; 
							write_ok <= '0';
							overflow <= '0';
                            underflow <= '0';
							bram_we <= '0';
							state <= READ_STATE;
					end if;
				when READ_STATE => 
					start_conv <= '0';							-- CREATING A SINGLE PULSE RATHER THAN A CONTINUOUS SIGNAL
					pixel_count <= 0;							-- PULLING THE COUNTER TO 0 SO AFTER RECEIVING A NEXT IMAGE WE CAN WRITE AGAIN
					if done_conv = '1' then						-- ALSO, RESETTING TO IDLE STATE AFTER THE CONVOLUTION IS FINISHED IN ORDER TO BE ABLE TO RECEIVE ANOTHER IMAGE
					   state <= IDLE; 
					end if;							
				when OTHERS =>
						state <= IDLE;
				end case;                       
			end if;            
	end process;
end architecture;
