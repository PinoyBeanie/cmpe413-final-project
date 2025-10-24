library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tag_valid_array is
  port (
    clk, reset  : in  std_logic;
    index       : in  std_logic_vector(1 downto 0);
    tag_in      : in  std_logic_vector(1 downto 0);
    tag_we      : in  std_logic;
    valid_we    : in  std_logic;
    tag_wdata   : in  std_logic_vector(1 downto 0);
    valid_out   : out std_logic;
    hit         : out std_logic
  );
end tag_valid_array;

architecture structural of tag_valid_array is
  component reg2 port (clk, reset, we : in std_logic; D : in std_logic_vector(1 downto 0); Q : out std_logic_vector(1 downto 0)); end component;
  component dff port (clk, reset, D : in std_logic; Q : out std_logic); end component;
  component comp2 port (a,b: in std_logic_vector(1 downto 0); eq: out std_logic); end component;

  signal tag_q : std_logic_vector(1 downto 0);
  signal eq_sig : std_logic;
  signal valid_q : std_logic;
begin
  tag_reg: reg2 port map (clk=>clk, reset=>reset, we=>tag_we, D=>tag_wdata, Q=>tag_q);
  valid_ff: dff port map (clk=>clk, reset=>reset, D=>valid_we, Q=>valid_q);
  comp: comp2 port map (a=>tag_in, b=>tag_q, eq=>eq_sig);

  valid_out <= valid_q;
  hit <= eq_sig and valid_q;
end structural;
