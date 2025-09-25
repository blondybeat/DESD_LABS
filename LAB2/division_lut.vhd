---------- DEFAULT LIBRARIES -------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;	-- For LOG **FOR A CONSTANT!!**
------------------------------------
entity division_lut is
    generic(
        SUM_WIDTH: POSITIVE := 9 --9 bit for 3*127 = 381
    );
    Port (
        clk				: in std_logic;
        resetn			: in std_logic;
        
        data_in : integer range 0 to 2**SUM_WIDTH -1;       -- SUM OF THE 3 COLORS R G B
        result : out std_logic_vector(6 downto 0);
        done : out std_logic;                               -- DONE SIGNAL TO KNOWN WHEN THE RESULT IS READY
        start : in std_logic                                -- START SIGNAL TO KNOW WHEN WE CAN START THE DIVISION
    );
end division_lut;

architecture behavioral of division_lut is
-- FOR THE DIVISION BY 3 WE USE THE CONCEPT OF GEOMETRIC SERIES SO WE CAN USE THE FORMULA:
-- 1/3 = 1/2 - 1/4 + 1/8 - 1/16 + 1/32 - 1/64 + 1/128 - 1/256 + 1/512 ...
-- 7 ITERATIONS ARE ENOUGH TO GET A GOOD APPROXIMATION SINCE R G B ARE IN RANGE 0 TO 127
-- THE DIVISION BY POWER OF 2 IS DONE BY BIT SHIFTING TO THE RIGHT SO IS FAST AND DOESN'T NEED TOO COMPLEX LOGIC 
begin
    process(clk, resetn)
    begin
        if resetn = '0' then
            result <= (others => '0');
            done <= '0';
    
        elsif rising_edge(clk) then
            if start = '1' then
                result <= std_logic_vector(to_unsigned(data_in/2 - data_in/4 + data_in/8 - data_in/16 + data_in/32 - data_in/64 + data_in/128, result'length));
                done <= '1';
            else 
                done <= '0';
            end if;

        end if;
    end process;

end Behavioral;