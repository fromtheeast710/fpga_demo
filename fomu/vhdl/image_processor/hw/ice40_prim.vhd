library ieee ;
use ieee.std_logic_1164.all;

package Prim is
  component SB_GB
    port
    ( GLOBAL_BUFFER_OUTPUT         : out std_logic
    ; USER_SIGNAL_TO_GLOBAL_BUFFER : in  std_logic
    );
  end component;

  component SB_RGBA_DRV
    generic
    ( CURRENT_MODE : string := "0b0"
    ; RGB0_CURRENT : string := "0b000000"
    ; RGB1_CURRENT : string := "0b000000"
    ; RGB2_CURRENT : string := "0b000000"
    );
    port
    ( RGB0PWM  : in  std_logic
    ; RGB1PWM  : in  std_logic
    ; RGB2PWM  : in  std_logic
    ; CURREN   : in  std_logic
    ; RGBLEDEN : in  std_logic
    ; RGB0     : out std_logic
    ; RGB1     : out std_logic
    ; RGB2     : out std_logic
    );
  end component;

  component SB_PLL40_PAD
    generic
    ( FEEDBACK_PATH : string := "SIMPLE"
    ; DIVR          : integer := 0
    ; DIVF          : integer := 4
    ; DIVQ          : integer := 2
    ; FILTER_RANGE  : integer := 1
    );
    port
    ( PACKAGEPIN   : in  std_logic
    ; PLLOUTGLOBAL : out std_logic
    ; LOCK         : out std_logic
    ; RESETB       : in  std_logic
    ; BYPASS       : in  std_logic
    );
  end component;

  component SB_IO
    generic
    ( NEG_TRIGGER : bit                     := '0'
    ; PIN_TYPE    : bit_vector (5 downto 0) := "000000"
    ; PULLUP      : bit                     := '0'
    ; IO_STANDARD : string                  := "SB_LVCMOS"
    );
    port
    ( D_OUT_1           : in    std_logic
    ; D_OUT_0           : in    std_logic
    ; CLOCK_ENABLE      : in    std_logic
    ; LATCH_INPUT_VALUE : in    std_logic
    ; INPUT_CLK         : in    std_logic
    ; D_IN_1            : out   std_logic
    ; D_IN_0            : out   std_logic
    ; OUTPUT_ENABLE     : in    std_logic := 'H'
    ; OUTPUT_CLK        : in    std_logic
    ; PACKAGE_PIN       : inout std_ulogic
    );
  end component;
end Prim;
