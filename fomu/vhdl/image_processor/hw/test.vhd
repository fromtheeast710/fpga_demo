library ieee;
use ieee.std_logic_1164.all;

entity Test is
end;

architecture dff of Test is
  signal clk : std_logic := '0';
  signal d   : std_logic := '0';
  signal q   : std_logic;
begin
  clk <= not clk after 5 ns;

  process is
  begin
    wait for 20 ns;

    d <= '1';

    wait for 80 ns;

    d <= '0';

    wait for 60 ns;

    d <= '1';

    wait for 60 ns;

    d <= '0';

    wait;

  end process;
end;
