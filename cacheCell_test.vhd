--
-- Entity: cacheCell_test
-- Architecture : vhdl
-- Author: Lance Boac
-- Created On: 10/23/2025
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity cacheCell_test is
end cacheCell_test;

architecture test of cacheCell_test is

  component cacheCell
    port (
      writeData  : in  std_logic;
      chipEnable : in  std_logic;
      rw         : in  std_logic;
      readData   : out std_logic
    );
  end component;

  signal writeDataSig  : std_logic := '0';
  signal chipEnableSig : std_logic := '0';
  signal rwSig         : std_logic := '0';
  signal readDataSig   : std_logic;

  procedure print_signals(test_name : string) is
    variable out_line : line;
  begin
    write(out_line, string'("Test: "));
    write(out_line, test_name);
    write(out_line, string'(" | CE=")); write(out_line, chipEnableSig);
    write(out_line, string'(" RW=")); write(out_line, rwSig);
    write(out_line, string'(" WD=")); write(out_line, writeDataSig);
    write(out_line, string'(" RD=")); write(out_line, readDataSig);
    writeline(output, out_line);
  end procedure;

begin

  -- Instantiate the cacheCell DUT
  DUT : cacheCell
    port map (
      writeData  => writeDataSig,
      chipEnable => chipEnableSig,
      rw         => rwSig,
      readData   => readDataSig
    );

  stim_proc : process
  begin

    -- CASE 1: Chip disabled (CE=0)
    chipEnableSig <= '0';
    rwSig <= '0';
    writeDataSig <= '1';
    wait for 5 ns;
    print_signals("CE=0 (Disabled): Expect no read/write");

    -- CASE 2: CE=1, RW=1 (READ mode)
    chipEnableSig <= '1';
    rwSig <= '1';     -- read mode
    writeDataSig <= '1';  -- data written earlier may appear on read
    wait for 5 ns;
    print_signals("CE=1, RW=1 (Read mode): Expect read enable active");

    -- CASE 3: CE=1, RW=0 (WRITE mode)
    chipEnableSig <= '1';
    rwSig <= '0';     -- write mode
    writeDataSig <= '0';
    wait for 5 ns;
    print_signals("CE=1, RW=0 (Write mode): Expect write enable active");

    -- CASE 4: CE=0 again (Disabled)
    chipEnableSig <= '0';
    rwSig <= '1';
    wait for 5 ns;
    print_signals("CE=0 again: Expect read/write disabled");

    -- CASE 5: CE=0 again (Disabled)
    chipEnableSig <= '1';
    rwSig <= '1';
    wait for 5 ns;
    print_signals("CE=0 again: Expect read/write disabled");

    -- CASE 6: CE=0 again (Disabled)
    chipEnableSig <= '1';
    rwSig <= '1';
    writeDataSig <= '1';
    wait for 5 ns;
    print_signals("CE=0 again: Expect read/write disabled");

    wait;
  end process;

end test;
