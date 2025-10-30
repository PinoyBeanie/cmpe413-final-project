library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity cache_top_test is
end entity;

architecture tb of cache_top_test is

  --------------------------------------------------------------------------
  -- DUT Declaration
  --------------------------------------------------------------------------
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

  --------------------------------------------------------------------------
  -- Signals
  --------------------------------------------------------------------------
  signal clk, reset, start, rd_wr : std_logic := '0';
  signal CA, MA : std_logic_vector(5 downto 0) := (others => '0');
  signal CD_in, CD_out, MD : std_logic_vector(7 downto 0) := (others => '0');
  signal busy, mem_enable : std_logic;

  -- File output
  file results : text open write_mode is "sim_output.txt";

  -- Hex print helper
  procedure PHEX(constant label_str : in string; signal v : in std_logic_vector) is
    variable L : line;
  begin
    write(L, label_str);
    hwrite(L, v);
    writeline(output, L);
    writeline(results, L);
  end procedure;

begin
  --------------------------------------------------------------------------
  -- DUT Instance
  --------------------------------------------------------------------------
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

  --------------------------------------------------------------------------
  -- 20 ns Clock
  --------------------------------------------------------------------------
  clk <= not clk after 10 ns;

  --------------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------------
  stim_proc : process
    variable L : line;
  begin
    ------------------------------------------------------------------------
    -- 1. RESET
    ------------------------------------------------------------------------
    write(L, string'("=== RESET PHASE ===")); writeline(output, L);
    reset <= '1';
    wait for 40 ns;
    reset <= '0';
    wait for 40 ns;

    ------------------------------------------------------------------------
    -- 2. READ MISS (Address 0x00)
    ------------------------------------------------------------------------
    write(L, string'("=== READ MISS TEST ===")); writeline(output, L);
    rd_wr <= '1';                 -- READ
    CA <= "000000";               -- 0x00
    start <= '1'; wait for 20 ns; start <= '0';
    wait until mem_enable = '1';
    write(L, string'("Memory access detected for READ MISS at ")); 
    write(L, time'image(now)); writeline(output, L);

    -- Memory sends 4 bytes: 00, 01, 02, 03
    wait for 160 ns; MD <= x"00";
    wait for 40 ns;  MD <= x"01";
    wait for 40 ns;  MD <= x"02";
    wait for 40 ns;  MD <= x"03";

    wait until busy = '0';
    write(L, string'("READ MISS complete at ")); write(L, time'image(now)); writeline(output, L);
    PHEX("CD_out=0x", CD_out);

    ------------------------------------------------------------------------
    -- 3. WRITE HIT (Address 0x03, Data 0xFF)
    ------------------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== WRITE HIT TEST ===")); writeline(output, L);
    rd_wr <= '0';                 -- WRITE
    CA <= "000011";               -- 0x03
    CD_in <= x"FF";
    start <= '1'; wait for 20 ns; start <= '0';
    wait until busy = '0';
    write(L, string'("WRITE HIT complete at ")); write(L, time'image(now)); writeline(output, L);

    ------------------------------------------------------------------------
    -- 4. READ HIT (Address 0x03)
    ------------------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== READ HIT TEST ===")); writeline(output, L);
    rd_wr <= '1';                 -- READ
    CA <= "000011";               -- same address (hit)
    start <= '1'; wait for 20 ns; start <= '0';
    wait until busy = '0';
    write(L, string'("READ HIT complete at ")); write(L, time'image(now)); writeline(output, L);
    PHEX("CD_out=0x", CD_out);

    ------------------------------------------------------------------------
    -- 5. WRITE MISS (Address 0x3F, Data 0xAA)
    ------------------------------------------------------------------------
    wait for 100 ns;
    write(L, string'("=== WRITE MISS TEST ===")); writeline(output, L);
    rd_wr <= '0';                 -- WRITE
    CA <= "111111";               -- 0x3F (miss)
    CD_in <= x"AA";
    start <= '1'; wait for 20 ns; start <= '0';
    wait until busy = '0';
    write(L, string'("WRITE MISS complete at ")); write(L, time'image(now)); writeline(output, L);
    PHEX("CD_out=0x", CD_out);

    ------------------------------------------------------------------------
    -- DONE
    ------------------------------------------------------------------------
    wait for 200 ns;
    assert false report "Simulation completed successfully." severity failure;
  end process;

end architecture;
