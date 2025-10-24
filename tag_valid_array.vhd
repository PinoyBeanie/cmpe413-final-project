library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tag_valid_array is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    index     : in  std_logic_vector(1 downto 0);
    tag_in    : in  std_logic_vector(1 downto 0);
    tag_we    : in  std_logic;
    valid_we  : in  std_logic;
    tag_wdata : in  std_logic_vector(1 downto 0);
    valid_out : out std_logic;
    hit       : out std_logic
  );
end tag_valid_array;

architecture rtl of tag_valid_array is
  type tag_mem_t is array(0 to 3) of std_logic_vector(1 downto 0);
  type valid_mem_t is array(0 to 3) of std_logic;
  signal tag_mem   : tag_mem_t := (others => (others => '0'));
  signal valid_mem : valid_mem_t := (others => '0');
  signal idx       : integer range 0 to 3;
begin
  idx <= to_integer(unsigned(index));

  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then
        tag_mem <= (others => (others => '0'));
        valid_mem <= (others => '0');
      else
        if tag_we='1' then tag_mem(idx) <= tag_wdata; end if;
        if valid_we='1' then valid_mem(idx) <= '1'; end if;
      end if;
    end if;
  end process;

  valid_out <= valid_mem(idx);
  hit <= '1' when (tag_mem(idx)=tag_in and valid_mem(idx)='1') else '0';
end rtl;
