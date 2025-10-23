--
-- Entity: cacheCell
-- Architecture: structural
-- Author: Lance Boac
-- Created On: 10/21/2025
--

library STD;
library IEEE;
use IEEE.std_logic_1164.all;

entity cacheCell is
  port (
    writeData  : in  std_logic;  -- Input data to write
    chipEnable : in  std_logic;  -- Chip enable
    rw         : in  std_logic;  -- RD/WR' 
    readData   : out std_logic   -- Output data when reading
  );
end cacheCell;

architecture structural of cacheCell is


  component selector
    port (
      ce          : in  std_logic;
      rw          : in  std_logic;
      readEnable  : out std_logic;
      writeEnable : out std_logic
    );
  end component;

  component Dlatch
    port (
      d    : in  std_logic;
      clk  : in  std_logic;
      q    : out std_logic;
      qbar : out std_logic
    );
  end component;

  component tx
    port (
      sel    : in  std_logic;
      selnot : in  std_logic;
      input  : in  std_logic;
      output : out std_logic
    );
  end component;

  signal readEnableSig  : std_logic;
  signal writeEnableSig : std_logic;
  signal q_internal     : std_logic;
  signal qbar_internal  : std_logic;
  signal readEnableBar  : std_logic;

begin

  -- Selector
  U1_selector : selector
    port map (
      ce          => chipEnable,
      rw          => rw,
      readEnable  => readEnableSig,
      writeEnable => writeEnableSig
    );

  -- Positive level-sensitive latch
  U2_latch : Dlatch
    port map (
      d    => writeData,
      clk  => writeEnableSig, 
      q    => q_internal,
      qbar => qbar_internal
    );

  -- Invert readEnable for complementary control
  readEnableBar <= not readEnableSig;

  -- Transmission gate for output
  U3_tx : tx
    port map (
      sel    => readEnableSig,  
      selnot => readEnableBar,
      input  => q_internal,
      output => readData
    );

end structural;
