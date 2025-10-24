
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_array is
  port (
    clk       : in  std_logic;
    we        : in  std_logic;
    index     : in  std_logic_vector(1 downto 0);
    byte_sel  : in  std_logic_vector(1 downto 0);
    data_in   : in  std_logic_vector(7 downto 0);
    data_out  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of cache_array is
  type cache_mem is array (0 to 3) of std_logic_vector(31 downto 0);
  signal mem : cache_mem := (others => (others => '0'));
begin
  process(clk)
    variable wline : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk) then
      wline := mem(to_integer(unsigned(index)));
      if we = '1' then
        case byte_sel is
          when "00" => wline(7 downto 0)   := data_in;
          when "01" => wline(15 downto 8)  := data_in;
          when "10" => wline(23 downto 16) := data_in;
          when "11" => wline(31 downto 24) := data_in;
          when others => null;
        end case;
        mem(to_integer(unsigned(index))) <= wline;
      end if;
    end if;
  end process;

  with byte_sel select
    data_out <= mem(to_integer(unsigned(index)))(7 downto 0)   when "00",
                 mem(to_integer(unsigned(index)))(15 downto 8)  when "01",
                 mem(to_integer(unsigned(index)))(23 downto 16) when "10",
                 mem(to_integer(unsigned(index)))(31 downto 24) when others;
end architecture;
