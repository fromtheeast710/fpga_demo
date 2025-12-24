library ieee;
use ieee.std_logic_1164.all, ieee.numeric_std.all;
use work.Pkg.all;

entity Proc is
  port
  ( clk_i
  , rstn_i : in std_logic

  ; in_valid_o : out std_logic
  ; in_data_o : out std_logic_vector(0 to 7)

  ; in_ready_i : in std_logic

  ; out_valid_i : in std_logic
  ; out_data_i : in std_logic_vector(0 to 7)

  ; out_ready_o : out std_logic
  );
end;

architecture main of Proc is
  component RAM is
  generic
  ( VECTOR_LENGTH : natural := 512
  ; WORD_WIDTH    : natural := 16
  ; ADDR_WIDTH    : natural := ceil_log2(VECTOR_LENGTH)
  );
  port
  ( rdata_o : out std_logic_vector(WORD_WIDTH - 1 downto 0)
  ; clk_i   : in  std_logic
  ; clke_i  : in  std_logic
  ; we_i    : in  std_logic
  ; addr_i  : in  unsigned(ADDR_WIDTH - 1 downto 0)
  ; mask_i  : in  std_logic_vector(WORD_WIDTH - 1 downto 0)
  ; wdata_i : in  std_logic_vector(WORD_WIDTH - 1 downto 0)
  );
  end component;

  component ROM is
  generic
  ( VECTOR_LENGTH : natural := 512
  ; WORD_WIDTH    : natural := 16
  ; ADDR_WIDTH    : natural := ceil_log2(VECTOR_LENGTH)
  );
  port
  ( data_o : out std_logic_vector(WORD_WIDTH-1 downto 0)
  ; clk_i  : in  std_logic
  ; clke_i : in  std_logic
  ; addr_i : in  unsigned(ADDR_WIDTH-1 downto 0)
  );
  end component;

  type USB is
  ( Reset, Loopback
  , Cmd0, Cmd1, Cmd2, Cmd3
  , Input, Output
  , Read0, Read1, Read2, Read3
  , ReadRom, ReadRam
  );
  type Cmd is
  ( None
  , InCmd, OutCmd
  , Addr, WaitCmd
  , LfsrRead, LfsrWrite
  , RomRead, RamRead
  );
  -- TODO: code clean up
  -- type Reg is record
  -- end record;

  constant ROM_SIZE : integer := 1024;
  constant RAM_SIZE : integer := 1024;

  signal state_q, state_d : USB;
  signal cmd_q,   cmd_d   : Cmd;

  signal rstn_sq : std_logic_vector(1 downto 0) := (others => '0');
  signal rstn    : std_logic;

  signal out_valid_q, out_ready   : std_logic;
  signal mem_valid_q, mem_valid_d : std_logic;

  signal out_data_q             : std_logic_vector(7 downto 0);
  signal wait_q, wait_d         : std_logic_vector(7 downto 0);
  signal crc32_q, crc32_d       : std_logic_vector(31 downto 0);
  signal lfsr_q,  lfsr_d        : std_logic_vector(23 downto 0);
  signal byte_cnt_q, byte_cnt_d : std_logic_vector(23 downto 0);
  signal mem_addr_q, mem_addr_d : std_logic_vector(23 downto 0);
  signal wait_cnt_q, wait_cnt_d : std_logic_vector(7 downto 0);

  signal wait_end  : std_logic;
  signal out_valid : std_logic;

  signal in_data   : std_logic_vector(7 downto 0);
  signal in_valid  : std_logic := '0';
  signal rom_clke  : std_logic := '0';
  signal ram_clke  : std_logic := '0';
  signal ram_we    : std_logic := '0';

  signal in_ready  : std_logic;
  signal rom_data  : std_logic_vector(7 downto 0);
  signal ram_rdata : std_logic_vector(7 downto 0);
begin
  rstn <= rstn_sq(0);

  -- NOTE: rstn_sq is not necessary?
  process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      rstn_sq <= (others => '0');
    elsif rising_edge(clk_i) then
      rstn_sq <= '1' & rstn_sq(1);
    end if;
  end process;

  wait_end <= '1' when wait_cnt_q = x"00" else '0';
  out_valid <= out_valid_i and wait_end;
  out_ready_o <= ((not out_valid_q) or out_ready) and wait_end;

  process ( clk_i, rstn ) is
  begin

    if (not rstn) then
      out_data_q   <= (others => '0');
      out_valid_q  <= '0';
      state_q      <= Reset;
      cmd_q        <= None;
      crc32_q      <= (others => '0');
      lfsr_q       <= (others => '0');
      byte_cnt_q   <= (others => '0');
      wait_q       <= (others => '0');
      wait_cnt_q   <= (others => '0');
      mem_valid_q  <= '0';
      mem_addr_q   <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q     <= state_d;
      cmd_q       <= cmd_d;
      crc32_q     <= crc32_d;
      lfsr_q      <= lfsr_d;
      byte_cnt_q  <= byte_cnt_d;
      wait_q      <= wait_d;

      if (out_valid and (not out_valid_q or out_ready)) then
        out_data_q  <= bit8_not(out_data_i);
        out_valid_q <= '1';
      elsif (out_ready) then
        out_valid_q <= '0';
      end if;

      if (not wait_end) then
        wait_cnt_q <= std_logic_vector(unsigned(wait_cnt_q) - 1);
      else
        wait_cnt_q <= wait_cnt_d;
        mem_valid_q <= mem_valid_d;
        mem_addr_q <= mem_addr_d;
      end if;

      mem_valid_q <= mem_valid_d;
      mem_addr_q  <= mem_addr_d;
    end if;
  end process;

  in_data_o  <= in_data;
  in_valid_o <= in_valid and wait_end;
  in_ready   <= in_ready_i and wait_end;

  process
  ( byte_cnt_q
  , cmd_q
  , crc32_q
  , in_ready
  , lfsr_q
  , mem_addr_q
  , mem_valid_q
  , out_data_q
  , out_valid_q
  , ram_rdata
  , rom_data
  , state_q
  , wait_q
  ) is
  begin
    state_d     <= state_q;
    cmd_d       <= cmd_q;
    crc32_d     <= crc32_q;
    lfsr_d      <= lfsr_q;
    byte_cnt_d  <= byte_cnt_q;
    wait_d      <= wait_q;
    wait_cnt_d  <= (others => '0');
    mem_valid_d <= mem_valid_q;
    mem_addr_d  <= mem_addr_q;
    in_data     <= out_data_q;
    in_valid    <= '0';
    out_ready   <= '0';
    rom_clke    <= '0';
    ram_clke    <= '0';
    ram_we      <= '0';

    -- TODO: different rgb colors for each modes
    case state_q is
      when Reset =>
        if ?? out_valid_q then
          state_d <= Loopback;
        end if;

      when Loopback =>
        if ?? out_valid_q then
          if out_data_q = x"00000000" then
            state_d <= Cmd0;
            out_ready <= '1';
          else
            in_valid <= '1';
            out_ready <= in_ready;

            if in_ready = '1' then
              ram_clke <= '1';
              ram_we <= '1';
              mem_addr_d <= std_logic_vector(unsigned(mem_addr_q) + 1);
            end if;
          end if;
        end if;

      when Cmd0 =>
        out_ready <= '1';

        if ?? out_valid_q then
          state_d <= Cmd1;
          -- BUG: unable to type cast
          -- cmd_d <= out_data_q;
        end if;

        mem_valid_d <= '0';

      when Cmd1 =>
        case cmd_q is
          when InCmd | OutCmd | RomRead | RamRead =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd2;
              byte_cnt_d(7 downto 0) <= out_data_q;
            end if;

          when Addr =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd2;
              mem_addr_d(7 downto 0) <= out_data_q;
            end if;

          when WaitCmd =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Loopback;
              wait_d <= out_data_q;
            end if;

          when LfsrWrite =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd2;
              lfsr_d(7 downto 0) <= out_data_q;
            end if;

          when LfsrRead => state_d <= Read0;

          when others => state_d <= Loopback;

        end case;

      when Cmd2 =>
        case cmd_q is
          when InCmd | OutCmd | RomRead | RamRead =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd3;
              byte_cnt_d(15 downto 8) <= out_data_q;
            end if;

          when Addr =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd3;
              mem_addr_d(15 downto 8) <= out_data_q;
            end if;

          when LfsrWrite =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Cmd3;
              lfsr_d(15 downto 8) <= out_data_q;
            end if;

          when others => state_d <= Loopback;

        end case;

      when Cmd3 =>
        crc32_d <= x"ffffffff";

        case cmd_q is
          when InCmd =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Input;
              byte_cnt_d(23 downto 16) <= out_data_q;
            end if;

          when OutCmd =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Output;
              byte_cnt_d(23 downto 16) <= out_data_q;
            end if;

          when Addr =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Loopback;
              mem_addr_d(23 downto 16) <= out_data_q;
            end if;

          when LfsrWrite =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= Loopback;
              lfsr_d(23 downto 16) <= out_data_q;
            end if;

          when RomRead =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= ReadRom;
              byte_cnt_d(23 downto 16) <= out_data_q;
            end if;

          when RamRead =>
            out_ready <= '1';

            if ?? out_valid_q then
              state_d <= ReadRam;
              byte_cnt_d(23 downto 16) <= out_data_q;
            end if;

          when others => state_d <= Loopback;

        end case;

      when Input =>
        in_data <= lfsr_q(7 downto 0);
        in_valid <= '1';

        if (in_ready = '1') then
          crc32_d <= crc32(crc32_q, lfsr_q(7 downto 0));
          lfsr_d <= lfsr_q(22 downto 0) & (xnor (not lfsr_q and LFSR_POLY24));

          if byte_cnt_q = std_logic_vector(to_unsigned(0, 24)) then
            state_d <= Read0;
          else
            byte_cnt_d <= std_logic_vector(unsigned(byte_cnt_q) - 1);
            wait_cnt_d <= wait_q;
          end if;
        end if;

      when Output =>
        out_ready <= '1';

        if ?? out_valid_q then
          crc32_d <= crc32(crc32_q, out_data_q);

          if byte_cnt_q = std_logic_vector(to_unsigned(0, 24)) then
            state_d <= Read0;
          else
            byte_cnt_d <= std_logic_vector(unsigned(byte_cnt_q) - 1);
            wait_cnt_d <= wait_q;
          end if;
        end if;

      when Read0 =>
        in_valid <= '1';

        if ?? in_ready then
          state_d <= Read1;
        end if;

        if cmd_q = LfsrRead then
          in_data <= lfsr_q(15 downto 8);
        else
          in_data <= rev8(not crc32_q(31 downto 24));
        end if;

      when Read1 =>
        in_valid <= '1';

        if ?? in_ready then
          state_d <= Read2;
        end if;

        if cmd_q = LfsrRead then
          in_data <= lfsr_q(15 downto 8);
        else
          in_data <= rev8(not crc32_q(23 downto 16));
        end if;

      when Read2 =>
        in_valid <= '1';

        if ?? in_ready then
          state_d <= Read3;
        end if;

        if cmd_q = LfsrRead then
          in_data <= lfsr_q(23 downto 16);
        else
          in_data <= rev8(not crc32_q(15 downto 8));
        end if;

      when Read3 =>
        in_valid <= '1';

        if ?? in_ready then
          state_d <= Loopback;
        end if;

        if cmd_q = LfsrRead then
          in_data <= std_logic_vector(to_unsigned(0, 8));
        else
          in_data <= rev8(not crc32_q(7 downto 0));
        end if;

      when ReadRom =>
        if not (?? mem_valid_q) then
          rom_clke <= '1';
          mem_valid_d <= '1';
          mem_addr_d <= std_logic_vector(unsigned(mem_addr_q) + 1);
        end if;

        in_data <= rom_data;
        in_valid <= mem_valid_q;

        if (?? in_ready) and (?? mem_valid_q) then
          mem_valid_d <= '0';

          if byte_cnt_q = std_logic_vector(to_unsigned(0, 24)) then
            state_d <= Loopback;
            mem_addr_d <= (others => '0');
          else
            byte_cnt_d <= std_logic_vector(unsigned(byte_cnt_q) - 1);
            rom_clke <= '1';
            mem_valid_d <= '1';
            mem_addr_d <= std_logic_vector(unsigned(mem_addr_q) + 1);
          end if;

          wait_cnt_d <= wait_q;
        end if;

      when ReadRam =>
        if not (?? mem_valid_q) then
          ram_clke <= '1';
          mem_valid_d <= '1';
          mem_addr_d <= std_logic_vector(unsigned(mem_addr_q) + 1);
        end if;

        in_data <= ram_rdata;
        in_valid <= mem_valid_q;

        if (?? in_ready) and (?? mem_valid_q) then
          mem_valid_d <= '0';

          if byte_cnt_q = std_logic_vector(to_unsigned(0, 24)) then
            state_d <= Loopback;
            mem_addr_d <= (others => '0');
          else
            byte_cnt_d <= std_logic_vector(unsigned(byte_cnt_q) - 1);
            ram_clke <= '1';
            mem_valid_d <= '1';
            mem_addr_d <= std_logic_vector(unsigned(mem_addr_q) + 1);
          end if;

          wait_cnt_d <= wait_q;
        end if;

      when others => state_d <= Loopback;

    end case;
  end process;

  u_rom : component ROM
  generic map (
    VECTOR_LENGTH => ROM_SIZE
    , WORD_WIDTH  => 8
    , ADDR_WIDTH  => ceil_log2(ROM_SIZE)
  )
  port map
  ( data_o => rom_data
  , clk_i  => clk_i
  , clke_i => rom_clke
  , addr_i => unsigned(mem_addr_q(ceil_log2(ROM_SIZE) - 1 downto 0))
  );

  u_ram : component RAM
  generic map
  ( VECTOR_LENGTH => RAM_SIZE
  , WORD_WIDTH    => 8
  , ADDR_WIDTH    => ceil_log2(RAM_SIZE)
  )
  port map
  ( rdata_o => ram_rdata
  , clk_i   => clk_i
  , clke_i  => ram_clke
  , we_i    => ram_we
  , addr_i  => unsigned(mem_addr_q(ceil_log2(RAM_SIZE)-1 downto 0))
  , mask_i  => (others => '0')
  , wdata_i => out_data_q
  );
end;
