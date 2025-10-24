library IEEE;
use IEEE.std_logic_1164.all;

entity cache_controller is
  port (
    clk, reset, start, rd_wr : in  std_logic;
    CA                       : in  std_logic_vector(5 downto 0);
    CD_in                    : in  std_logic_vector(7 downto 0);
    CD_out                   : out std_logic_vector(7 downto 0);
    oe_cpu, busy             : out std_logic;
    MD                       : in  std_logic_vector(7 downto 0);
    MA                       : out std_logic_vector(5 downto 0);
    mem_en                   : out std_logic
  );
end cache_controller;

architecture structural of cache_controller is
  component cache_controller_fsm
    port (...); -- as built structurally from state_register, next_state_logic, output_logic
  end component;

  component cache
    port (...);
  end component;

  component tag_valid_array
    port (...);
  end component;

  signal hit_s, valid_s, tag_we_s, valid_we_s, cache_we_s : std_logic;
  signal tag_in, tag_wdata_s : std_logic_vector(1 downto 0);
  signal cache_wdata_s : std_logic_vector(7 downto 0);
  signal cache_waddr_s : std_logic_vector(3 downto 0);
begin
  -- Field extraction gates
  tag_in <= CA(5 downto 4);

  tags: tag_valid_array
    port map (
      clk=>clk, reset=>reset,
      index=>CA(3 downto 2),
      tag_in=>tag_in,
      tag_we=>tag_we_s,
      valid_we=>valid_we_s,
      tag_wdata=>tag_wdata_s,
      valid_out=>valid_s,
      hit=>hit_s
    );

  fsm: cache_controller_fsm
    port map (
      clk=>clk, reset=>reset,
      start=>start, rd_wr=>rd_wr,
      hit_i=>hit_s,
      CA=>CA, CD_in=>CD_in, MD=>MD,
      busy=>busy, oe_cpu=>oe_cpu,
      mem_en=>mem_en, MA=>MA,
      cache_we=>cache_we_s,
      cache_waddr=>cache_waddr_s,
      cache_wdata=>cache_wdata_s,
      tag_we=>tag_we_s,
      tag_wdata=>tag_wdata_s,
      valid_we=>valid_we_s
    );

  data_cache: cache
    port map (
      writeData=>(cache_wdata_s & cache_wdata_s & cache_wdata_s & cache_wdata_s), -- example replication
      chipEnable=>cache_we_s,
      rw=>rd_wr,
      indexBits=>CA(1 downto 0),
      validBit=>open,
      readData=>open
    );

  CD_out <= cache_wdata_s;
end structural;
