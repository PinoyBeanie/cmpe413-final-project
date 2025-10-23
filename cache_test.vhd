--
-- Entity: cache_test
-- Architecture: structural_test
-- Description: Testbench for 32-bit cache block (4x8-bit) with valid and index bits
-- Author: ChatGPT
-- Created On: 10/23/2025
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity cache_test is
end cache_test;

architecture structural_test of cache_test is

  -- DUT component declaration
  component cache
    port (
      writeData  : in  std_logic_vector(31 downto 0);
      chipEnable : in  std_logic;
      rw         : in  std_logic;                      -- '1' = READ, '0' = WRITE
      indexBits  : in  std_logic_vector(1 downto 0);
      validBit   : inout std_logic;
      readData   : out std_logic_vector(31 downto 0)
    );
  end component;

  -- Signals to drive the DUT
  signal writeDataSig  : std_logic_vector(31 downto 0) := (others => '0');
  signal chipEnableSig : std_logic := '0';
  signal rwSig         : std_logic := '0';
  signal indexBitsSig  : std_logic_vector(1 downto 0) := (others => '0');
  signal validBitSig   : std_logic := '0';
  signal readDataSig   : std_logic_vector(31 downto 0);

  -- Text output helper procedure
  procedure print_signals(test_name : string) is
    variable out_line : line;
  begin
    write(out_line, string'("Test: "));
    write(out_line, test_name);
    write(out_line, string'(" | CE=")); write(out_line, chipEnableSig);
    write(out_line, string'(" RW=")); write(out_line, rwSig);
    write(out_line, string'(" IDX=")); write(out_line, indexBitsSig);
    write(out_line, string'(" VALID=")); write(out_line, validBitSig);
    write(out_line, string'(" WD=")); write(out_line, writeDataSig);
    write(out_line, string'(" RD=")); write(out_line, readDataSig);
    writeline(output, out_line);
  end procedure;

begin

  -- DUT instantiation
  DUT : cache
    port map (
      writeData  => writeDataSig,
      chipEnable => chipEnableSig,
      rw         => rwSig,
      indexBits  => indexBitsSig,
      validBit   => validBitSig,
      readData   => readDataSig
    );

  -- Stimulus process
  stim_proc : process
  begin

    -- CASE 1: Cache disabled (CE=0)
    chipEnableSig <= '0';
    rwSig <= '0';
    writeDataSig <= x"AAAAAAAA";
    indexBitsSig <= "00";
    validBitSig <= '0';
    wait for 5 ns;
    print_signals("CE=0 (Disabled): Expect no operation");

    -- CASE 2: Write data to cache (CE=1, RW=0)
    chipEnableSig <= '1';
    rwSig <= '0';
    writeDataSig <= x"DEADBEEF";
    indexBitsSig <= "01";
    validBitSig <= '1';
    wait for 10 ns;
    print_signals("Write 0xDEADBEEF to cache (CE=1, RW=0)");

    -- CASE 3: Read back data (CE=1, RW=1)
    rwSig <= '1';
    wait for 10 ns;
    print_signals("Read mode (CE=1, RW=1): Expect 0xDEADBEEF");

    -- CASE 4: Write new data to another index
    rwSig <= '0';
    indexBitsSig <= "10";
    writeDataSig <= x"CAFEBABE";
    wait for 10 ns;
    print_signals("Write 0xCAFEBABE to index 10");

    -- CASE 5: Read from same index
    rwSig <= '1';
    wait for 10 ns;
    print_signals("Read index 10: Expect 0xCAFEBABE");

    -- CASE 6: Disable chip
    chipEnableSig <= '0';
    wait for 5 ns;
    print_signals("Chip disabled again: no read/write");

    wait;
  end process;

end structural_test;
