
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- THIS MODULE SELECTS THE EFFECT TO APPLY TO THE AUDIO SIGNAL
entity effect_selector is
    generic(
        JOYSTICK_LENGHT  : integer := 10
    );
    Port (
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        effect : in STD_LOGIC; --btnU
        jstck_x : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        jstck_y : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        volume : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        balance : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        lfo_period : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0)
    );
end effect_selector;

architecture Behavioral of effect_selector is
-- IF BTNU IS NOT PRESSED THE JOYSTICK X AXIS CONTROLS THE BALANCE AND THE Y AXIS CONTROLS THE VOLUME
-- IF BTNU IS PRESSED THE JOYSTICK X AXIS HAS NO EFFECT AND THE Y AXIS CONTROLS THE LFO PERIOD
-- SINCE THE JOYSTICK COORDINATES ARE UNSIGNED RANGE 0 TO 1023 THE CENTRAL POSITION IS 512
begin
    process(aclk, aresetn)
    begin
        
        if aresetn = '0' then
            volume <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT));
            balance <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT));
            lfo_period <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT));

        elsif rising_edge(aclk) then
            if effect = '1' then
                lfo_period <= jstck_y;
                volume <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT));    --512;
                balance <= std_logic_vector(to_unsigned(512, JOYSTICK_LENGHT));   --512;
            else
                volume <= jstck_y;
                balance <= jstck_x;
            end if;
        
        end if;
    end process;

end Behavioral;
