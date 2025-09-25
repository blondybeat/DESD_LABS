library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity led_blinker is
    generic (
        CLK_PERIOD_NS: POSITIVE :=10;
        BLINK_PERIOD_MS : POSITIVE := 1000;
        N_BLINKS : POSITIVE := 4
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;
        start_blink : in std_logic;
        led: out std_logic
    );
end entity led_blinker;

architecture rtl of led_blinker is
    
    constant LED_ON_DURATION : integer := BLINK_PERIOD_MS * 10**6 / (CLK_PERIOD_NS * 2);            -- NUMBER OF CLOCK CYCLES OF HALF BLINK PERIOD, IN WHICH THE LED IS ON
    
    signal cycle_count : integer range 0 to LED_ON_DURATION := 0;                                   -- COUNTER FOR THE CLOCK CYCLES
    signal blink_count : integer range 0 to 2 * N_BLINKS := 0;                                      -- COUNTER FOR ON/OFF TRANSISTIONS
    signal led_state : std_logic := '0';
    signal blinking : std_logic := '0';                                                             -- FLAG THAT INDICATES WHEN THE LED IS BLINKING


begin

    process(clk, aresetn)
    begin 
        if aresetn = '0' then 
            cycle_count <= 0;
            blink_count <= 0;
            led_state <= '0';
            blinking <= '0';

        elsif rising_edge(clk) then 

            if start_blink = '1' and blinking = '0' then
                cycle_count <= 0;
                blink_count <= 0;
                led_state <= '1';
                blinking <= '1';

            end if;

            if blinking = '1' then
                if blink_count = N_BLINKS * 2 - 1  then     -- DONE BLINKING, WE COMPLETE THE NUMBER OF BLINKS
                    blinking <= '0';
                    led_state <= '0';
                end if;

                if cycle_count = LED_ON_DURATION - 1 then   -- IF NOT WE COUNT UNTIL WE REACH THE HALF PERIOD AND INCREMENT BLINK COUNT 
                    cycle_count <= 0;
                    led_state <= not led_state;
                    blink_count <= blink_count + 1; 
                else 
                    cycle_count <= cycle_count + 1;
                end if;

            end if;

        end if;

        
    end process;
    
     led <= led_state;
    
    

end architecture;
