library ieee;
context ieee.ieee_std_context;
use work.Prim.all;

entity RGB is
  port
  ( clk : in std_logic

  ; rgb0
  , rgb1
  , rgb2 : out std_logic
  );
end;

architecture main of RGB is
  signal counter : unsigned(27 downto 0) := (others => '0');
begin

  process(clk) is
  begin
    if rising_edge(clk) then
      counter <= counter + 1;
    end if;
  end process;

  rgba_driver: SB_RGBA_DRV
    generic map
    ( CURRENT_MODE => "0b0"
    , RGB0_CURRENT => "0b000011"
    , RGB1_CURRENT => "0b000011"
    , RGB2_CURRENT => "0b000011"
    )
    port map
    ( CURREN   => '1'
    , RGBLEDEN => '1'
    , RGB0PWM  => counter(counter'left)
    , RGB1PWM  => counter(counter'left - 1)
    , RGB2PWM  => counter(counter'left - 2)
    , RGB0     => rgb0
    , RGB1     => rgb1
    , RGB2     => rgb2
    );
end;
