library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package Pkg is
  constant RESI32 : std_logic_vector(31 downto 0) := x"c704dd7b";
  constant LFSR_POLY24 : std_logic_vector(23 downto 0) := b"111000010000000000000000";

  function rev8(data : std_logic_vector(7 downto 0)) return std_logic_vector;

  function ceil_log2(ar : integer) return integer;

  function crc32
  ( crc : std_logic_vector(31 downto 0)
  ; data : std_logic_vector(7 downto 0)
  ) return std_logic_vector;

  function add1(data : std_logic_vector(7 downto 0)) return std_logic_vector;

  function bit8_not(data : std_logic_vector(7 downto 0)) return std_logic_vector;
end;

package body Pkg is
  function crc32
  ( crc : std_logic_vector(31 downto 0)
  ; data : std_logic_vector(7 downto 0)
  ) return std_logic_vector is
    constant POLY32 : std_logic_vector(31 downto 0) := x"04c11db7";
    variable new_crc : std_logic_vector(31 downto 0) := crc;
  begin
    new_crc := crc;

    for i in 0 to 7 loop
      if ?? crc(31) then
        new_crc := crc(30 downto 0) & b"0";
        new_crc := new_crc xor POLY32;
      else
        new_crc := crc(30 downto 0) & b"0";
      end if;
    end loop;

    return new_crc;
  end function;

  function rev8(data : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable res : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 7 loop
      res(i) := data(7 - i);
    end loop;

    return res;
  end function;

  function ceil_log2(ar : integer) return integer is
    variable res : integer := 0;
    variable v   : integer := 1;
  begin
    while v < ar loop
      v   := v * 2;
      res := res + 1;
    end loop;

    return res;
  end function;

  function add1(data : std_logic_vector(7 downto 0))
    return std_logic_vector is
  begin
    return std_logic_vector(unsigned(data) + 1);
  end function;

  function bit8_not(data : std_logic_vector(7 downto 0))
    return std_logic_vector is
  begin
    return not data;
  end function;
end;
