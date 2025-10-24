library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_cache_top is
end entity;

architecture sim of tb_cache_top is
  -- DUT
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

  -- DUT signals
  signal clk, reset  : std_logic := '0';
  signal start, rd_wr: std_logic := '0';
  signal CA          : std_logic_vector(5 downto 0) := (others => '0');
  signal CD_in       : std_logic_vector(7 downto 0) := (others => '0');
  signal CD_out      : std_logic_vector(7 downto 0);
  signal busy        : std_logic;
  signal MA          : std_logic_vector(5 downto 0);
  signal MD          : std_logic_vector(7 downto 0);
  signal mem_enable  : std_logic;

  -- Memory model signals
  signal mem_data    : std_logic_vector(7 downto 0);
  signal mem_ctr     : integer := 0;
begin
  -- Clock generation: 10 ns period
  clk <= not clk after 5 ns;

  -- Instantiate DUT
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

  -- Simple memory model: return bytes 0x10, 0x11, 0x12, 0x13 spaced 2 cycles apart
  process(clk)
  begin
    if falling_edge(clk) then
      if mem_enable = '1' then
        mem_ctr <= 0;
      elsif mem_ctr < 20 then
        mem_ctr <= mem_ctr + 1;
      end if;
    end if;
  end process;

  MD <= x"10" when mem_ctr = 8 else
         x"11" when mem_ctr = 10 else
         x"12" when mem_ctr = 12 else
         x"13" when mem_ctr = 14 else
         (others => '0');

  --------------------------------------------------------------------------
  -- Test sequence
  --------------------------------------------------------------------------
  stim: process
  begin
    -- RESET
    reset <= '1';
    wait for 20 ns;
    reset <= '0';
    wait for 20 ns;

    -- 1. READ MISS (0x00)
    CA <= "000000"; rd_wr <= '1'; start <= '1';
    wait for 10 ns; start <= '0';
    wait until busy = '0';
    wait for 40 ns;

    -- 2. WRITE HIT (0x03)
    CA <= "000011"; rd_wr <= '0'; CD_in <= x"FF"; start <= '1';
    wait for 10 ns; start <= '0';
    wait until busy = '0';
    wait for 40 ns;

    -- 3. READ HIT (0x03)
    CA <= "000011"; rd_wr <= '1'; start <= '1';
    wait for 10 ns; start <= '0';
    wait until busy = '0';
    wait for 40 ns;

    -- 4. WRITE MISS (0x3F)
    CA <= "111111"; rd_wr <= '0'; CD_in <= x"AA"; start <= '1';
    wait for 10 ns; start <= '0';
    wait until busy = '0';

    wait for 100 ns;
    assert false report "Simulation finished successfully" severity failure;
  end process;
end architecture;
