--
-- Entity: cacheCell
-- Architecture: structural
-- Author: Emily Bearden
-- Created On: 10/21/2025
--

library STD;
library IEEE;
use IEEE.std_logic_1164.all;

entity cache is 
    port (
            clk : in std_logic;
            reset : in std_logic;
            start : in std_logic;
            rw : in std_logic; -- '1' = read, '0' = write
            ce : in std_logic; --chip enable
            ca : in std_logic_vector(5 downto 0);   --CPU address
            cd_in : in std_logic_vector(7 downto 0);    --CPU write data    
            cd_out : in std_logic_vector(7 downto 0);   --CPU read data
            busy : out std_logic;

            --Memory interface

            ma : out std_logic_vector(5 downto 0); --memory address
            md_in : in std_logic_vector(7 downto 0); --memory read data
            enable : out std_logic;
    );
end cache; 
architecture Behavioral of cache is
    ----Cache parameters----
    constant BLOCKS : integer := 4; --num of cache blocks 
    constant BYTES : integer :=4; --num of bytes per block 

    ----internal cache data structures----
    type block_array is array (0 to BLOCKS-1, 0 to BYTES-1) of std_logic_vector(7 downto 0);
    signal cache_data : block_array;

    type tag_array is array (0 to BLOCKS-1) of std_logic_vector(1 downto 0);
    signal cache_tag : tag_array;

    signal cache_valid : std_logic_vector(BLOCKS-1 downto 0);

    ----FSM state defintions----
    type state_type is (
        IDLE,
        CHECK_HIT, 
        READ_HIT, 
        WRITE_HIT, 
        READ_MISS, 
        WRITE_MISS, 
        OUTPUT_DATA 
    );
    signal state, next_state : state_type;

    ----Internal signals----
    signal tag_bits : std_logic_vector(7 downto 0);
    signal index_bits : std_logic_vector(7 downto 0);
    signal byte_bits : std_logic_vector(7 downto 0);
    signal hit : std_logic;
    signal cpu_data : std_logic_vector(7 downto 0);
    signal mem_counter : integer range 0 to 15 := 0;

begin 
    ----address decoding----
    tag_bits <= ca(5 downto 4);
    index_bits <= ca(3 downto 2);
    byte_bits <= ca(1 downto 0);

    
    --FSM type shi--
    process(clk, reset)
    begin
        if reset = '1' then 
        state <= IDLE
        busy <= '0';
        enable <= '0'; 
        cd_out <= (others => '0');
        elseif rising_edge(clk) then 
             case(state) is 
                when IDLE =>
                    busy <= '0';
                    if start = '1' then
                        busy <= '1'; --if start goes high, busy goes high on the neg edge 
                        state = CHECK_HIT; --next state 
                    end if; 
                when CHECK_HIT => 
                    if (cache_valid(to_integer(unsigned(index_bits))) = '1') and (cache_tag(tointeger(unsigned(index_bits))) = tag_bits) 
                    then hit <= '1';
                    else 
                    hit <= '0'; 
                    end if;
                
                    if read_write = '1' then
                        if hit = '1' then
                            state <= READ_HIT;
                        else state <= READ_MISS; 
                        end if;
                    else 
                        if hit = '1';
                            state <= WRITE_HIT;
                        else 
                            state <= WRITE_MISS;
                        end if ;
                    end if; 
                when READ_HIT =>
                    cd_out <= cache_data(to_integer(unsigned(index_bits)), to_integer(unsigned(byte_bits)));
                    busy <= '0'; 
                    state <= IDLE;
                when WRITE_HIT =>
                    cache_data(to_integer(unsigned(index_bits)), to_integer(unsigned(byte_bits))) <= cd_in;
                    busy <= '0';
                    state <= IDLE;
                when WRITE_MISS =>
                    busy <= '0';
                    state <= IDLE;
                when READ_MISS =>
                    enable <= '1';
                    ma <= ca(5 downto 2) & '00'; --address of start of block
                    mem_counter <= '0';
                    state <= READ_MISS_FILL;
                when READ_MISS_FILL =>
                    enable <= '0';
                    --simulate recieving 4 bytes from memory (delayed)
                    if mem_counter < 4 then
                        cache_data(to_integer(unsigned(index_bits)), mem_counter) <= md_in;
                        mem_counter <= mem_counter + 1;
                    else 
                        cache_tag(to_integer(unsigned(index_bits))) <= tag_bits
                        cache_valid(to_integer(unsigned(index_bits))) <= '1';
                        state <= OUTPUT_DATA;
                    end if;
                when OUTPUT_DATA
                    cd_out <= cache_data(to_integer(unsigned(index_bits)), to_integer(unsigned(byte_bits)));
                    busy <= '0';
                    state <= IDLE;
                when others =>
                    state <= IDLE;
                end 
            end case;
        end if;
    end process;
                
                
                
end Behavioral;
