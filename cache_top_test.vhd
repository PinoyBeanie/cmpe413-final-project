library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity cache_top_test is
end entity;

architecture tb of cache_top_test is

  component cache_top
    port (
      clk, reset  : in  std_logic;
      start       : in  std_logic;
      rd_wr       : in  std_logic;
      CA          : in  std_logic_vector(5 downto 0);
      CD_in       : in  std_logic_vector(7 downto 0);
      CD_out      : out std_logic_vector(7 downto 0);
      busy        : out std_logic;
      MA          : out std_logic_vector(5 downto 0);
      MD          : in  std_logic_vector(7 downto 0);
      mem_enable  : out std_logic
    );
  end component;

  -- Signals
  signal clk, reset, start, rd_wr : std_logic := '0';
  signal CA, MA : std_logic_vector(5 downto 0) := (others => '0');
  signal CD_in, CD_out, MD : std_logic_vector(7 downto 0) := (others => '0');
  signal busy, mem_enable : std_logic;

  -- File output
  file results : text open write_mode is "sim_output.txt";

  procedure PHEX(constant label_str : in string; signal v : in std_logic_vector) is
    variable L : line;
  begin
    write(L, label_str);
    hwrite(L, v);
    writeline(output, L);
    writeline(results, L);
  end procedure;

begin
  --------------------------------------------------------------------
  -- 20 ns Clock
  --------------------------------------------------------------------
  clk <= not clk after 10 ns;

  --------------------------------------------------------------------
  -- DUT Instance
  --------------------------------------------------------------------
  uut: cache_top
    port map (
      clk => clk,
      reset => reset,
      start => start,
      rd_wr => rd_wr,
      CA => CA,
      CD_in => CD_in,
      CD_out => CD_out,
      busy => busy,
      MA => MA,
      MD => MD,
      mem_enable => mem_enable
    );

  --------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------
  stim_proc : process
    variable L : line;
  begin
    ----------------------------------------------------------------
    -- RESET
    ----------------------------------------------------------------
    write(L, string'("=== RESET PHASE ===")); writeline(output, L);
    reset <= '1';
    wait for 40 ns;
    reset <= '0';
    wait for 60 ns;

    ----------------------------------------------------------------
    -- 1. READ MISS
    ----------------------------------------------------------------
    write(L, string'("=== READ MISS TEST ===")); writeline(output, L);
    rd_wr <= '1'; CA <= "000000";
    start <= '1'; wait for 20 ns; start <= '0';
    wait until mem_enable = '1';
    write(L, string'("Memory access for READ MISS triggered")); writeline(output, L);

    wait for 100 ns; MD <= x"10";
    wait for 40 ns;  MD <= x"11";
    wait for 40 ns;  MD <= x"12";
    wait for 40 ns;  MD <= x"13";

     wait for 10 ns; -- allow busy to settle
    wait until busy = '0';
    PHEX("READ MISS result CD_out=0x", CD_out);

    ----------------------------------------------------------------
    -- 2. READ HIT
    ----------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== READ HIT TEST ===")); writeline(output, L);
    rd_wr <= '1'; CA <= "000000";
    start <= '1'; wait for 20 ns; start <= '0';

     wait for 10 ns; -- allow busy to settle
    wait until busy = '0';
    PHEX("READ HIT result CD_out=0x", CD_out);

    ----------------------------------------------------------------
    -- 3. WRITE MISS
    ----------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== WRITE MISS TEST ===")); writeline(output, L);
    rd_wr <= '0'; CA <= "111100"; CD_in <= x"AA";
    start <= '1'; wait for 20 ns; start <= '0';
    wait until mem_enable = '1';
    write(L, string'("WRITE MISS memory enable asserted")); writeline(output, L);

     wait for 10 ns; -- allow busy to settle
    wait until busy = '0';
    PHEX("WRITE MISS complete CD_out=0x", CD_out);

    ----------------------------------------------------------------
    -- 4. WRITE HIT
    ----------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== WRITE HIT TEST ===")); writeline(output, L);
    rd_wr <= '0'; CA <= "111100"; CD_in <= x"BB";
    start <= '1'; wait for 20 ns; start <= '0';

    wait for 10 ns; -- allow busy to settle
    wait until busy = '0';
    PHEX("WRITE HIT complete CD_out=0x", CD_out);

    ----------------------------------------------------------------
    -- DONE
    ----------------------------------------------------------------
    wait for 200 ns;
    assert false report "Simulation completed successfully." severity failure;
  end process;

end architecture;
