
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tag_valid is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    index      : in  std_logic_vector(1 downto 0);
    tag_in     : in  std_logic_vector(1 downto 0);
    write_tag  : in  std_logic;  -- from FSM update_tag
    set_valid  : in  std_logic;  -- from FSM set_valid
    tag_match  : out std_logic
  );
end entity;

architecture rtl of tag_valid is
  type tag_array is array (0 to 3) of std_logic_vector(1 downto 0);
  type val_array is array (0 to 3) of std_logic;
  signal tags  : tag_array := (others => (others => '0'));
  signal valids: val_array := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        tags   <= (others => (others => '0'));
        valids <= (others => '0');
      else
        if write_tag = '1' then
          tags(to_integer(unsigned(index))) <= tag_in;
        end if;
        if set_valid = '1' then
          valids(to_integer(unsigned(index))) <= '1';
        end if;
      end if;
    end if;
  end process;

  tag_match <= '1' when (tags(to_integer(unsigned(index))) = tag_in and
                         valids(to_integer(unsigned(index))) = '1')
               else '0';
end architecture;
