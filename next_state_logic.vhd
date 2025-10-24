library IEEE;
use IEEE.std_logic_1164.all;

entity next_state_logic is
  port (
    current_state : in  std_logic_vector(3 downto 0);
    start, rd_wr, hit_i : in std_logic;
    next_state : out std_logic_vector(3 downto 0)
  );
end next_state_logic;

architecture structural of next_state_logic is
  -- logic gates
  component and2 port (a,b: in std_logic; y: out std_logic); end component;
  component or2  port (a,b: in std_logic; y: out std_logic); end component;
  component inv  port (a: in std_logic; y: out std_logic);   end component;

  signal s0,s1,s2,s3 : std_logic;
  signal nstart,nrw,nhit : std_logic;
begin
  inv1: inv port map (start, nstart);
  inv2: inv port map (rd_wr, nrw);
  inv3: inv port map (hit_i, nhit);

  -- Example structural logic equations:
  -- next_state(0) = (current_state(0) AND nhit) OR (start AND nrw)
  and1: and2 port map (current_state(0), nhit, s0);
  and2_: and2 port map (start, nrw, s1);
  or1:  or2 port map (s0, s1, next_state(0));

  -- Similarly build next_state(1..3)
  next_state(1) <= current_state(1);
  next_state(2) <= '0';
  next_state(3) <= '0';
end structural;
