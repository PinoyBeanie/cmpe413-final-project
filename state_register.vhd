library IEEE;
use IEEE.std_logic_1164.all;

entity state_register is
  port (
    clk, reset : in  std_logic;
    D          : in  std_logic_vector(3 downto 0);
    Q          : out std_logic_vector(3 downto 0)
  );
end state_register;

architecture structural of state_register is
  component dff
    port ( clk, reset, D : in std_logic; Q : out std_logic );
  end component;

  signal q_int : std_logic_vector(3 downto 0);
begin
  gen_dff : for i in 0 to 3 generate
    bitff : dff port map (clk=>clk, reset=>reset, D=>D(i), Q=>q_int(i));
  end generate;

  Q <= q_int;
end structural;
