library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity chip_tb is
end chip_tb;

architecture behavior of chip_tb is

  -- DUT component
  component chip
    port(
      cpu_add    : in  std_logic_vector(5 downto 0);
      cpu_data   : inout std_logic_vector(7 downto 0);
      cpu_rd_wrn : in  std_logic;
      start      : in  std_logic;
      clk        : in  std_logic;
      reset      : in  std_logic;
      mem_data   : in  std_logic_vector(7 downto 0);
      Vdd, Gnd   : in  std_logic;
      busy       : out std_logic;
      mem_en     : out std_logic;
      mem_add    : out std_logic_vector(5 downto 0)
    );
  end component;

  -- Signals
  signal clk, reset, start, cpu_rd_wrn, busy, mem_en : std_logic := '0';
  signal Vdd, Gnd : std_logic := '1';
  signal cpu_add, mem_add : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_data, mem_data : std_logic_vector(7 downto 0) := (others => 'Z');

  signal cpu_data_drv : std_logic_vector(7 downto 0) := (others => '0');

  -- Simulation control
  signal stop_sim : boolean := false;

begin

  --------------------------------------------------------------------
  -- Connect DUT
  --------------------------------------------------------------------
  DUT: chip
    port map (
      cpu_add    => cpu_add,
      cpu_data   => cpu_data,
      cpu_rd_wrn => cpu_rd_wrn,
      start      => start,
      clk        => clk,
      reset      => reset,
      mem_data   => mem_data,
      Vdd        => Vdd,
      Gnd        => Gnd,
      busy       => busy,
      mem_en     => mem_en,
      mem_add    => mem_add
    );

  --------------------------------------------------------------------
  -- CPU drives data only during writes
  --------------------------------------------------------------------
  cpu_data <= cpu_data_drv when cpu_rd_wrn = '0' else (others => 'Z');

  --------------------------------------------------------------------
  -- Clock process (10 ns period)
  --------------------------------------------------------------------
  clk_process : process
  begin
    while not stop_sim loop
      clk <= '1';
      wait for 5 ns;
      clk <= '0';
      wait for 5 ns;
    end loop;
    wait;
  end process;

  --------------------------------------------------------------------
  -- Memory model (very simple)
  -- Responds 8 cycles after mem_en is asserted
  --------------------------------------------------------------------
  mem_process : process(clk)
    variable counter : integer := 0;
  begin
    if rising_edge(clk) then
      if mem_en = '1' then
        counter := 0;
      elsif counter < 8 then
        counter := counter + 1;
        if counter = 8 then
          -- Provide some pseudo-random data
          mem_data <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_add)) * 3, 8));
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Testbench procedure to print signal states
  --------------------------------------------------------------------
  procedure print_status(signal op_name : in string) is
    variable L : line;
  begin
    write(L, string'("Time "));
    write(L, now);
    write(L, string'(" | Op: "));
    write(L, op_name);
    write(L, string'(" | Addr="));
    write(L, integer'image(to_integer(unsigned(cpu_add))));
    write(L, string'(" | CPU_data="));
    write(L, to_hstring(cpu_data));
    write(L, string'(" | Busy="));
    write(L, busy);
    write(L, string'(" | Mem_en="));
    write(L, mem_en);
    write(L, string'(" | Mem_data="));
    write(L, to_hstring(mem_data));
    writeline(output, L);
  end procedure;

  --------------------------------------------------------------------
  -- Main Test Process
  --------------------------------------------------------------------
  stim_proc : process
  begin
    -- Initialize
    reset <= '1';
    wait for 20 ns;
    reset <= '0';
    wait for 10 ns;

    ------------------------------------------------------------------
    -- Test 1: READ MISS (first read, not in cache)
    ------------------------------------------------------------------
    cpu_add <= "000000";  -- tag=00, block=00, byte=00
    cpu_rd_wrn <= '1';    -- read
    start <= '1';
    wait for 10 ns;       -- one clock
    start <= '0';
    print_status("READ MISS REQUEST");

    wait until busy = '0';
    wait for 10 ns;
    print_status("READ MISS COMPLETE");

    ------------------------------------------------------------------
    -- Test 2: READ HIT (same address, now in cache)
    ------------------------------------------------------------------
    cpu_add <= "000000";
    cpu_rd_wrn <= '1';
    start <= '1';
    wait for 10 ns;
    start <= '0';
    print_status("READ HIT REQUEST");

    wait until busy = '0';
    wait for 10 ns;
    print_status("READ HIT COMPLETE");

    ------------------------------------------------------------------
    -- Test 3: WRITE HIT
    ------------------------------------------------------------------
    cpu_add <= "000000";
    cpu_rd_wrn <= '0';    -- write
    cpu_data_drv <= x"AA";
    start <= '1';
    wait for 10 ns;
    start <= '0';
    print_status("WRITE HIT REQUEST");

    wait until busy = '0';
    wait for 10 ns;
    print_status("WRITE HIT COMPLETE");

    ------------------------------------------------------------------
    -- Test 4: WRITE MISS
    ------------------------------------------------------------------
    cpu_add <= "110000";  -- different tag/block
    cpu_rd_wrn <= '0';
    cpu_data_drv <= x"55";
    start <= '1';
    wait for 10 ns;
    start <= '0';
    print_status("WRITE MISS REQUEST");

    wait until busy = '0';
    wait for 10 ns;
    print_status("WRITE MISS COMPLETE");

    ------------------------------------------------------------------
    -- Finish simulation
    ------------------------------------------------------------------
    wait for 50 ns;
    stop_sim <= true;
    wait;
  end process;

end behavior;
