library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- (i-1,j-1) (i-1,j) (i-1,j+1)
-- (i,j-1)   (i,j)   (i,j+1)
-- (i+1,j-1) (i+1,j) (i+1,j+1)
-- (i,j) IS THE PIXEL INTERESTED IN THE CONVOLUTION, FROM WHICH WE DETERMINATES THE COORDINATES OF THE OTHERS PIXEL
-- WE DON'T NEED TO STORE THE 9 PIXELS IN A MATRIX, BUT WE CAN TAKE EACH PIXEL FROM THE BRAM AND DO THE PRODUCT AND THEN SUM ALL
-- WE NEED AN ARRAY FOR THE COORDINATES TO DERIVE THE PIXEL ADRESS IN THE BRAM 
-- IN THE BRAM THE GREY PIXELS ARE STORED SEQUENTIALLY SO WE NEED TO CONVERT THE COORDINATES IN A LINEAR ADRESS i_index*N_COLS+j_index

-- THIS MODULE DOESN'T WORK PROPERLY WITH THE BOARD

entity img_conv is
    generic(
                                                                                   --256*256 IMAGE DIMENSION
        LOG2_N_COLS: POSITIVE :=8;
        LOG2_N_ROWS: POSITIVE :=8
    );
    port (

        clk   : in std_logic;
        aresetn : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic; 
        m_axis_tlast : out std_logic;
        
        conv_addr: out std_logic_vector(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);        -- LINEAR ADRESS TO THE BRAM
        conv_data: in std_logic_vector(6 downto 0);                                 -- GREY PIXEL

        start_conv: in std_logic;
        done_conv: out std_logic
        
    );
end entity img_conv;

architecture rtl of img_conv is
    constant N_COLS : integer := 2**LOG2_N_COLS;
    constant N_ROWS : integer := 2**LOG2_N_ROWS;
                                                                                    --INTERNAL AXI4 SIGNAL DECLARATION
    signal m_axis_tlast_int : std_logic := '0';
    signal m_axis_tvalid_int: std_logic := '0';

    type conv_mat_type is array(0 to 2, 0 to 2) of integer;
    constant conv_mat : conv_mat_type := ((-1,-1,-1),(-1,8,-1),(-1,-1,-1));
    signal i, j : integer range 0 to N_ROWS-1 := 0; --N_ROWS = N_COLS = 256
    type coordinates_type is array (0 to 8) of integer range -1 to 1;
    signal coordinates_i : coordinates_type := (-1, -1, -1, 0, 0, 0, 1, 1, 1);      -- RELATIVE COORDINATES ARRAYS
    signal coordinates_j : coordinates_type := (-1, 0, 1, -1, 0, 1, -1, 0, 1);
    signal index: natural range 0 to 9 := 0;                                        -- INDEX FOR THE COORDINATES
    signal i_index, j_index : integer range -1 to 256;
    signal addr_pixel : natural range 0 to N_ROWS*N_COLS-1;                         -- LINEAR ADRESS FOR THE PIXEL IN THE BRAM
                                                              
                                                                                    -- SIGNALS TO CONTROL THE CALCULATIONS OF THE COORDINATES, THE SUM AND THE PRODUCTS OF THE CELLS 
    signal send_pixel : std_logic := '0';                     
    signal send_addr : std_logic := '0';                      
    signal send_coordinates : std_logic := '0';
    signal resize_result : std_logic := '0';
    signal wait_data : std_logic := '0';
    signal done_product : std_logic := '0';
    
    signal conv_result : unsigned(7 downto 0);                                      -- FINAL RESULT OF THE CONVOLUTION
    signal cells_product : signed(15 downto 0) := (others => '0');                  -- PRODUCT OF CELLS
    signal cells_sum : signed(15 downto 0) := (others => '0');                      -- SUM OF THE PRODUCTS
    signal conv_coeff : signed(7 downto 0);                                         -- CELLS OF CONVOLUTION MATRIX
    signal sum_ready : std_logic := '0';
    signal done_conv_int : std_logic := '0';                                        -- DONE CONV INTERNAL SIGNAL
    signal start_conv_int : std_logic := '0';
    
    type state_type is (IDLE, READ_DATA, SEND_DATA);
    signal state : state_type := IDLE;
begin
    m_axis_tvalid <= m_axis_tvalid_int;
    m_axis_tlast <= m_axis_tlast_int;
    done_conv <= done_conv_int;
    
    FSM : process(state, clk, aresetn)
    begin
        
        if aresetn = '0' then
            
            state <= IDLE;
            m_axis_tvalid_int <= '0';
            m_axis_tlast_int <= '0';
            done_conv_int <= '0';
            index <= 0;
            i <= 0;
            j <= 0;
            cells_sum <= (others => '0');
            done_product <= '0';
            send_coordinates <= '0';
            send_addr <= '0';
            send_pixel <= '0';
            wait_data <= '0';
            resize_result <= '0';

        elsif rising_edge(clk) then
            case state is
                
                when IDLE =>
                     if start_conv = '1' then
                        start_conv_int <= '1';
                        cells_sum <= (others => '0');
                        index <= 0;
                     end if;

                     if start_conv_int = '1' then
                        start_conv_int <= '0';
                        state <= READ_DATA;
                     end if;
                     if done_conv_int = '1' then                          -- TO BE ABLE TO START A NEW CONVOLUTION
                        done_conv_int <= '0';
                     end if;
                
                when READ_DATA =>
                    if send_pixel = '0' and send_coordinates ='0' and send_addr = '0' and wait_data = '0' and sum_ready = '0' then
                        if index < 9 then
                           i_index <= i + coordinates_i(index);                                                                        -- FOR EACH PIXEL (i,j) LOOP THROUGH TH 3*3 CONV MATRIX USING THE RELATIVE COORDINATES ARRAYS
                           j_index <= j + coordinates_j(index);
                           send_coordinates <= '1';
                           conv_coeff <= to_signed(conv_mat(coordinates_i(index)+1, coordinates_j(index)+1), conv_coeff'length);       -- CELL OF THE CONV MATRIX
                        end if;
                    elsif send_coordinates = '1' then
                        send_coordinates <= '0';
                        if i_index < 0 or i_index >= N_ROWS or j_index < 0 or j_index >= N_COLS then                                   -- CHECK BOUNDS, IF OUT I CONSIDER ZERO CELL VALUE
                           index <= index + 1;   
                        else
                           addr_pixel <= i_index*N_COLS+j_index;                                                                       -- OR I CONVERT TO A LINEAR BRAM ADDRESS
                           send_addr <= '1';
                        end if;

                    elsif send_addr = '1' then    
                        conv_addr <= std_logic_vector(to_unsigned(addr_pixel, conv_addr'length));                                      -- SEND THE ADDRESS TO THE BRAM
                        wait_data <= '1';
                        send_addr <= '0';
                    elsif wait_data = '1'  then
                        wait_data <= '0';                                                                                              -- WAIT FOR THE DATA , LATENCY FOR THE BRAM
                        send_pixel <= '1';
                    
                    elsif send_pixel = '1' then
                        cells_product <= (signed('0'&conv_data)) * conv_coeff;                                                         -- DO THE PRODUCT BEETWEEN SIGNED SO I NEED TO CONVERT THE 7 BIT UNSIGNED CONV DATA IN A 8 BIT SIGNED
                        sum_ready <= '1';
                        send_pixel <= '0';
                    elsif sum_ready = '1' then
                        cells_sum <= cells_sum + cells_product;                                                                        -- ADD THE PRODUCT TO THE SUM
                        sum_ready <= '0';
                        index <= index + 1;
                   
                    end if;
        
            
                    if index = 9 and sum_ready = '0' and resize_result = '0' then
                       state <= SEND_DATA;
                       done_product <= '1';
                       resize_result <= '1';
                       if cells_sum < 0 then                                                                                           -- CLIP CELLS SUM TO 0-127
                          conv_result <= (others => '0');
                       elsif cells_sum > 127 then
                       conv_result <= to_unsigned(127, conv_result'length);
                       else
                       conv_result <= to_unsigned(to_integer(cells_sum), 8);
                       end if;
                    end if;
 

                when SEND_DATA =>                                                                                                       -- READY TO SEND THE RESULT TO THE AXI STREAM
                    if m_axis_tready = '1' then
                      
                       if done_product = '1' then
                           m_axis_tvalid_int <= '1';
                           m_axis_tdata <= std_logic_vector(conv_result);
                           done_product <= '0';
                           cells_sum <= (others => '0');
                          
                           if j = N_COLS -1 and i = N_ROWS -1 then                                                                      -- LAST PIXEL, SEND TLAST HIGH
                              m_axis_tlast_int <= '1';
                           end if;

                        end if;
                     
                    end if;
     
                     -- HANDSHAKE --
                    if m_axis_tvalid_int = '1' and m_axis_tready = '1' then
                        m_axis_tvalid_int <= '0';
                        index <= 0;
                        resize_result <= '0';
                        if m_axis_tlast_int = '1' then
                           done_conv_int <= '1';
                           state <= IDLE;
                        else
                           state <= READ_DATA;
                        end if;
                     
                        if j = N_COLS -1 then                                                                                            -- MOVE TO THE NEXT PIXEL INCREMENTING i AND j
                           if i = N_ROWS -1 then
                              i <= 0;
                           else
                              i <= i + 1;
                              j <= 0;
                           end if;
                        else
                           j <= j + 1;
                        end if;
                    end if;
                when others => 
                     state <= IDLE;
            
            end case;
        end if;
    end process;
end architecture;