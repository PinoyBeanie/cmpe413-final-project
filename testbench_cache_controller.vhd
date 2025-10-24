library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity testbench_cache_controller is
end testbench_cache_controller;

architecture tb of testbench_cache_controller is
  signal clk, reset, start, rd_wr : std_logic := '0';
  signal CA : std_logic_vector(5 downto 0) := (others=>'0');
  signal CD_in, CD_out, MD : std_logic_vector(7 downto 0) := (others=>'0');
  signal oe_cpu, busy, hit_i, mem_en : std_logic;
  signal MA : std_logic_vector(5 downto 0);
  signal cache_we, tag_we, valid_we : std_logic;
  signal cache_waddr : std_logic_vector(3 downto 0);
  signal cache_wdata : std_logic_vector(7 downto 0);
  signal tag_wdata : std_logic_vector(1 downto 0);

begin
  DUT: entity work.cache_controller
    port map (
      clk=>clk, reset=>reset,
      start=>start, rd_wr=>rd_wr,
      CA=>CA, CD_in=>CD_in, CD_out=>CD_out,
      oe_cpu=>oe_cpu, busy=>busy, hit_i=>hit_i,
      cache_we=>cache_we, cache_waddr=>cache_waddr, cache_wdata=>cache_wdata,
      tag_we=>tag_we, tag_wdata=>tag_wdata, valid_we=>valid_we,
      MA=>MA, mem_en=>mem_en, MD=>MD
    );

  -- Clock
  process
  begin
    clk <= '0'; wait for 5 ns;
    clk <= '1'; wait for 5 ns;
  end process;

  -- Stimulus
  process
  begin
    reset <= '1'; wait for 20 ns; reset <= '0';
    wait for 10 ns;
    start <= '1'; rd_wr <= '1'; CA <= "000011"; wait for 10 ns;
    start <= '0';
    wait for 200 ns;
    assert false report "Simulation complete" severity failure;
  end process;
end tb;
