library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity chip is
  port(
    cpu_add    : in  std_logic_vector(5 downto 0);
    cpu_data   : inout std_logic_vector(7 downto 0);
    cpu_rd_wrn : in  std_logic; -- '1' = read, '0' = write
    start      : in  std_logic;
    clk        : in  std_logic;
    reset      : in  std_logic;
    mem_data   : in  std_logic_vector(7 downto 0);
    Vdd, Gnd   : in  std_logic;
    busy       : out std_logic;
    mem_en     : out std_logic;
    mem_add    : out std_logic_vector(5 downto 0)
  );
end chip;

architecture behavioral of chip is

  -- Cache structures
  type cache_block is array(0 to 3) of std_logic_vector(7 downto 0); -- 4 bytes
  type cache_mem   is array(0 to 3) of cache_block; -- 4 blocks

  signal cache_data : cache_mem := (others => (others => (others => '0')));
  signal cache_tag  : std_logic_vector(1 downto 0) := (others => '0');
  signal cache_tags : array(0 to 3) of std_logic_vector(1 downto 0) := (others => (others => '0'));
  signal valid_bits : std_logic_vector(3 downto 0) := (others => '0');

  -- Internal signals
  signal tag, blk, byte_sel : std_logic_vector(1 downto 0);
  signal state : integer := 0;
  signal mem_counter : integer := 0;
  signal data_reg : std_logic_vector(7 downto 0);
  signal busy_reg : std_logic := '0';
  signal mem_en_reg : std_logic := '0';
  signal output_en : std_logic := '0';

begin

  busy <= busy_reg;
  mem_en <= mem_en_reg;
  cpu_data <= data_reg when output_en = '1' else (others => 'Z');

  -- Decode address fields
  tag <= cpu_add(5 downto 4);
  blk <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  process(clk, reset)
  begin
    if reset = '1' then
      valid_bits <= (others => '0');
      busy_reg <= '0';
      mem_en_reg <= '0';
      output_en <= '0';
      state <= 0;

    elsif falling_edge(clk) then

      case state is

        ----------------------------------------------------------------
        -- IDLE: waiting for CPU to start an operation
        ----------------------------------------------------------------
        when 0 =>
          if start = '1' then
            busy_reg <= '1';
            state <= 1;
          end if;

        ----------------------------------------------------------------
        -- Latch address/data and determine hit/miss
        ----------------------------------------------------------------
        when 1 =>
          if cpu_rd_wrn = '1' then
            -- READ operation
            if valid_bits(to_integer(unsigned(blk))) = '1' and 
               cache_tags(to_integer(unsigned(blk))) = tag then
              -- READ HIT
              data_reg <= cache_data(to_integer(unsigned(blk)))(to_integer(unsigned(byte_sel)));
              output_en <= '1';
              state <= 2;  -- finish read
            else
              -- READ MISS
              mem_en_reg <= '1';
              mem_add <= cpu_add; -- last byte address
              mem_counter <= 0;
              state <= 10;
            end if;
          else
            -- WRITE operation
            if valid_bits(to_integer(unsigned(blk))) = '1' and
               cache_tags(to_integer(unsigned(blk))) = tag then
              -- WRITE HIT
              cache_data(to_integer(unsigned(blk)))(to_integer(unsigned(byte_sel))) <= cpu_data;
              state <= 3;
            else
              -- WRITE MISS (no write allocate)
              state <= 3;
            end if;
          end if;

        ----------------------------------------------------------------
        -- READ HIT: send data to CPU and finish
        ----------------------------------------------------------------
        when 2 =>
          output_en <= '1';
          busy_reg <= '0';
          state <= 0;

        ----------------------------------------------------------------
        -- WRITE HIT / MISS: complete after 2 neg edges
        ----------------------------------------------------------------
        when 3 =>
          busy_reg <= '0';
          state <= 0;

        ----------------------------------------------------------------
        -- READ MISS: wait for memory (8 cycles)
        ----------------------------------------------------------------
        when 10 =>
          mem_counter <= mem_counter + 1;
          if mem_counter = 1 then
            mem_en_reg <= '0'; -- turn off enable after 1 cycle
          elsif mem_counter = 8 then
            -- Memory returns data
            cache_data(to_integer(unsigned(blk)))(to_integer(unsigned(byte_sel))) <= mem_data;
            cache_tags(to_integer(unsigned(blk))) <= tag;
            valid_bits(to_integer(unsigned(blk))) <= '1';
            data_reg <= mem_data;
            output_en <= '1';
            busy_reg <= '0';
            state <= 0;
          end if;

        when others =>
          state <= 0;
      end case;

    end if;
  end process;

end behavioral;
