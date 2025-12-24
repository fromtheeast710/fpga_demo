library ieee;
use ieee.std_logic_1164.all, ieee.numeric_std.all;
use work.Prim.all;

entity Main is
  port
  ( clki      : in    std_logic

  ; rgb0
  , rgb1
  , rgb2      : out   std_logic

  ; usb_dp
  , usb_dn    : inout std_logic

  ; usb_dp_pu : out   std_logic
  );
end;

architecture main of Main is
  component prescaler is
    port
    ( clk_i
    , rstn_i      : in  std_logic
    ; clk_div16_o
    , clk_div8_o
    , clk_div4_o
    , clk_div2_o  : out std_logic
    );
  end component prescaler;

  component usb_cdc is
    generic
    ( VENDORID               : std_logic_vector(15 downto 0) := X"0000"
    ; PRODUCTID              : std_logic_vector(15 downto 0) := X"0000"
    ; IN_BULK_MAXPACKETSIZE  : integer                       := 8
    ; OUT_BULK_MAXPACKETSIZE : integer                       := 8
    ; BIT_SAMPLES            : integer                       := 4
    ; USE_APP_CLK            : integer                       := 0
    ; APP_CLK_FREQ           : integer                       := 12
    );
    port
    ( app_clk_i
    , clk_i
    , rstn_i
    , out_ready_i
    , in_valid_i
    , dp_rx_i
    , dn_rx_i : in  std_logic
    ; in_data_i : in  std_logic_vector(7 downto 0)
    ; configured_o
    , out_valid_o
    , in_ready_o
    , dp_pu_o
    , tx_en_o
    , dp_tx_o
    , dn_tx_o : out std_logic
    ; out_data_o : out std_logic_vector(7 downto 0)
    ; frame_o : out std_logic_vector(10 downto 0)
    );
  end component usb_cdc;

  signal clk_3mhz      : std_logic;
  signal clk_6mhz      : std_logic;
  signal clk_12mhz     : std_logic;
  signal clk_24mhz     : std_logic;
  signal rstn_sync     : std_logic_vector(1 downto 0) := "00";
  signal rstn          : std_logic;
  signal clk           : std_logic;
  signal usb_dp_pu_int : std_logic;
  signal dp_pu         : std_logic;
  signal led           : unsigned(2 downto 0);
  signal dp_rx         : std_logic;
  signal dn_rx         : std_logic;
  signal dp_tx         : std_logic;
  signal dn_tx         : std_logic;
  signal tx_en         : std_logic;
  signal out_data      : std_logic_vector(7 downto 0);
  signal out_valid     : std_logic;
  signal in_ready      : std_logic;
  signal in_data       : std_logic_vector(7 downto 0);
  signal in_valid      : std_logic;
  signal out_ready     : std_logic;
  -- signal counter       : unsigned(27 downto 0) := (others => '0');
begin
  u_gb : SB_GB
    port map
    ( USER_SIGNAL_TO_GLOBAL_BUFFER => clki
    , GLOBAL_BUFFER_OUTPUT         => clk
    );

  p_rstn : process (clk) is
  begin
    if rising_edge(clk) then
      rstn_sync <= '1' & rstn_sync(1);
    end if;
  end process p_rstn;

  rstn <= rstn_sync(0);

  rgb : entity work.RGB
    port map
    ( clk => clki
    , rgb0 => rgb0
    , rgb1 => rgb1
    , rgb2 => rgb2
    );

  u_prescaler : component prescaler
    port map
    ( clk_i       => clk
    , rstn_i      => rstn
    , clk_div16_o => clk_3mhz
    , clk_div8_o  => clk_6mhz
    , clk_div4_o  => clk_12mhz
    , clk_div2_o  => clk_24mhz
    );

  u_app : entity work.Proc
    port map
    ( clk_i       => clk_12mhz
    , rstn_i      => rstn
    , out_data_i  => out_data
    , out_valid_i => out_valid
    , in_ready_i  => in_ready
    , out_ready_o => out_ready
    , in_data_o   => in_data
    , in_valid_o  => in_valid
    );

  u_usb_cdc : component usb_cdc
    generic map
    ( VENDORID               => X"1209"
    , PRODUCTID              => X"5BF0"
    , IN_BULK_MAXPACKETSIZE  => 8
    , OUT_BULK_MAXPACKETSIZE => 8
    , BIT_SAMPLES            => 4
    , USE_APP_CLK            => 1
    , APP_CLK_FREQ           => 12
    )
    port map
    ( app_clk_i    => clk_12mhz
    , clk_i        => clk
    , rstn_i       => rstn
    , out_ready_i  => out_ready
    , in_data_i    => in_data
    , in_valid_i   => in_valid
    , dp_rx_i      => dp_rx
    , dn_rx_i      => dn_rx
    , frame_o      => open
    , configured_o => open
    , out_data_o   => out_data
    , out_valid_o  => out_valid
    , in_ready_o   => in_ready
    , dp_pu_o      => dp_pu
    , tx_en_o      => tx_en
    , dp_tx_o      => dp_tx
    , dn_tx_o      => dn_tx
    );

  u_usb_dp : SB_IO
    generic map
    ( PIN_TYPE => "101001"
    , PULLUP   => '0'
    )
    port map
    ( PACKAGE_PIN       => usb_dp
    , OUTPUT_ENABLE     => tx_en
    , D_IN_0            => dp_rx
    , D_OUT_0           => dp_tx
    , D_IN_1            => open
    , D_OUT_1           => '0'
    , CLOCK_ENABLE      => '0'
    , LATCH_INPUT_VALUE => '0'
    , INPUT_CLK         => '0'
    , OUTPUT_CLK        => '0'
    );

  u_usb_dn : SB_IO
    generic map
    ( PIN_TYPE => "101001"
    , PULLUP   => '0'
    )
    port map
    ( PACKAGE_PIN       => usb_dn
    , OUTPUT_ENABLE     => tx_en
    , D_IN_0            => dn_rx
    , D_OUT_0           => dn_tx
    , D_IN_1            => open
    , D_OUT_1           => '0'
    , CLOCK_ENABLE      => '0'
    , LATCH_INPUT_VALUE => '0'
    , INPUT_CLK         => '0'
    , OUTPUT_CLK        => '0'
    );

  -- drive usb_pu to 3.3V or to high impedance
  usb_dp_pu <= usb_dp_pu_int;

  u_usb_pu : SB_IO
    generic map
    ( PIN_TYPE => "101001"
    , PULLUP   => '0'
    )
    port map
    ( PACKAGE_PIN       => usb_dp_pu_int
    , OUTPUT_ENABLE     => dp_pu
    , D_IN_0            => open
    , D_OUT_0           => '1'
    , D_IN_1            => open
    , D_OUT_1           => '0'
    , CLOCK_ENABLE      => '0'
    , LATCH_INPUT_VALUE => '0'
    , INPUT_CLK         => '0'
    , OUTPUT_CLK        => '0'
    );
end;
