--
-- Entity: cache_controller
-- Architecture: behavioral_fsm
-- Author: (you)
-- Notes:
--   - Internal operations occur on the NEGATIVE edge of clk (per spec).
--   - Generates busy/enable/oe and cache write strobes with required timing.
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_controller is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;

    -- CPU interface
    start      : in  std_logic;                          -- asserted on a rising edge
    rd_wr      : in  std_logic;                          -- '1'=READ, '0'=WRITE
    CA         : in  std_logic_vector(5 downto 0);       -- CPU address
    CD_in      : in  std_logic_vector(7 downto 0);       -- CPU write data
    CD_out     : out std_logic_vector(7 downto 0);       -- CPU read data (latched)
    oe_cpu     : out std_logic;                          -- output enable for CD_out (one cycle)
    busy       : out std_logic;

    -- Tag/Valid interface (combinational hit input from your tag/valid array)
    hit_i      : in  std_logic;                          -- '1' when tag matches AND valid=1 (for CA)
                                                         -- (evaluate during S_CHECK)

    -- Cache array write port (byte write into the selected block/byte)
    cache_we   : out std_logic;                          -- asserted EXACTLY one full cycle per written byte
    cache_waddr: out std_logic_vector(3 downto 0);       -- {block(1:0), byte(1:0)}
    cache_wdata: out std_logic_vector(7 downto 0);       -- data to write
    tag_we     : out std_logic;                          -- write tag/valid on first fill only
    tag_wdata  : out std_logic_vector(1 downto 0);       -- 2-bit tag
    valid_we   : out std_logic;                          -- set valid bit on first fill

    -- Memory interface (read miss only)
    MA         : out std_logic_vector(5 downto 0);       -- address to memory (last byte address, byte_off="00")
    mem_en     : out std_logic;                          -- one-cycle enable request
    MD         : in  std_logic_vector(7 downto 0)        -- memory data bus (stable for 2 cycles per byte)
  );
end cache_controller;

architecture behavioral_fsm of cache_controller is
  ---------------------------------------------------------------------------
  -- Helpers to extract fields from CA (Tag[5:4], Block[3:2], Byte[1:0])
  ---------------------------------------------------------------------------
  signal tag_in    : std_logic_vector(1 downto 0);
  signal block_in  : std_logic_vector(1 downto 0);
  signal byte_in   : std_logic_vector(1 downto 0);

  ---------------------------------------------------------------------------
  -- Latched request (captured on first falling edge after start)
  ---------------------------------------------------------------------------
  signal ca_r      : std_logic_vector(5 downto 0);
  signal rd_wr_r   : std_logic;
  signal cd_r      : std_logic_vector(7 downto 0);

  ---------------------------------------------------------------------------
  -- Controller outputs (registered on falling edge)
  ---------------------------------------------------------------------------
  signal busy_r    : std_logic := '0';
  signal oe_r      : std_logic := '0';
  signal cache_we_r: std_logic := '0';
  signal tag_we_r  : std_logic := '0';
  signal valid_we_r: std_logic := '0';
  signal MA_r      : std_logic_vector(5 downto 0) := (others => '0');
  signal mem_en_r  : std_logic := '0';
  signal cdout_r   : std_logic_vector(7 downto 0) := (others => '0');

  ---------------------------------------------------------------------------
  -- Miss timing counters
  --   mem_wait: counts negative edges after asserting mem_en until 1st byte (target=8)
  --   byte_idx: 0..3 for the 4 returned bytes (at 8/10/12/14 negedges)
  --   two_cyc : sub-counter to keep each MD byte stable for 2 cycles and pulse cache_we
  ---------------------------------------------------------------------------
  signal mem_wait  : integer range 0 to 20 := 0;
  signal byte_idx  : integer range 0 to 3  := 0;
  signal two_cyc   : integer range 0 to 1  := 0;

  ---------------------------------------------------------------------------
  -- States
  ---------------------------------------------------------------------------
  type state_t is (
    S_RESET,

    -- Request latch & hit check
    S_IDLE,          -- wait for CPU request (observed at next falling edge)
    S_LATCH,         -- latch CA, rd_wr, CD; raise busy
    S_CHECK,         -- evaluate hit_i

    -- Read Hit (2 clocks total)
    S_RD_HIT_OUT,    -- assert oe_cpu, put data on CD_out
    S_RD_HIT_DONE,   -- deassert busy, drop oe_cpu

    -- Write (hit or miss share 3-clock envelope; no write-allocate)
    S_WR_W1,         -- do cache write if hit_i='1' (otherwise skip)
    S_WR_W2,         -- hold busy high one more cycle (3-clock total)
    S_WR_DONE,       -- deassert busy

    -- Read Miss (19 clocks)
    S_RM_REQ,        -- assert mem_en for 1 cycle, drive MA (last-byte addr)
    S_RM_WAIT,       -- wait 8 negedges for first data
    S_RM_BYTE_SETUP, -- prepare write addr/data for current MD byte
    S_RM_BYTE_WE,    -- assert cache_we exactly 1 full cycle (between posedges)
    S_RM_NEXT,       -- advance to next byte or finish fill
    S_RM_FINISH1,    -- present requested byte to CPU, assert oe_cpu
    S_RM_FINISH2     -- deassert busy, drop oe_cpu
  );
  signal st, st_n : state_t := S_RESET;

  -- Convenience
  function to_uint(v: std_logic_vector) return integer is
  begin
    return to_integer(unsigned(v));
  end function;

begin
  tag_in   <= CA(5 downto 4);
  block_in <= CA(3 downto 2);
  byte_in  <= CA(1 downto 0);

  ---------------------------------------------------------------------------
  -- Outputs
  ---------------------------------------------------------------------------
  busy    <= busy_r;
  oe_cpu  <= oe_r;
  cache_we<= cache_we_r;
  tag_we  <= tag_we_r;
  valid_we<= valid_we_r;
  MA      <= MA_r;
  mem_en  <= mem_en_r;
  CD_out  <= cdout_r;

  cache_wdata <= MD;                                -- On fills we write MD
  cache_waddr <= block_in & std_logic_vector(to_unsigned(byte_idx, 2));

  tag_wdata   <= tag_in;                            -- set during first fill

  ----------------------------------------------------------------------------
  -- Sequential: NEGATIVE edge operation (per spec)
  ----------------------------------------------------------------------------
  negedge_proc : process(clk)
  begin
    if falling_edge(clk) then
      if reset = '1' then
        st         <= S_RESET;
        busy_r     <= '0';
        oe_r       <= '0';
        cache_we_r <= '0';
        tag_we_r   <= '0';
        valid_we_r <= '0';
        mem_en_r   <= '0';
        mem_wait   <= 0;
        byte_idx   <= 0;
        two_cyc    <= 0;
      else
        -- default single-cycle drops
        mem_en_r   <= '0';
        oe_r       <= '0';
        cache_we_r <= '0';
        tag_we_r   <= '0';
        valid_we_r <= '0';

        st <= st_n;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- Combinational Next-State / Output Generation
  ----------------------------------------------------------------------------
  comb : process(st, start, rd_wr, CA, CD_in, hit_i, mem_wait, byte_idx, two_cyc,
                 ca_r, rd_wr_r, cd_r)
    variable ca_last_byte : std_logic_vector(5 downto 0);
  begin
    st_n      <= st;

    case st is
      when S_RESET =>
        busy_r <= '0';
        st_n   <= S_IDLE;

      when S_IDLE =>
        busy_r <= '0';
        if start = '1' then
          st_n <= S_LATCH;
        end if;

      when S_LATCH =>
        -- Latch CPU request (occurred on last rising edge)
        ca_r    <= CA;
        rd_wr_r <= rd_wr;
        cd_r    <= CD_in;
        busy_r  <= '1';
        st_n    <= S_CHECK;

      when S_CHECK =>
        busy_r <= '1';
        if rd_wr_r = '1' then
          -- READ
          if hit_i = '1' then
            st_n <= S_RD_HIT_OUT;                   -- 2 clocks total
          else
            st_n <= S_RM_REQ;                       -- read miss service
          end if;
        else
          -- WRITE (no write-allocate; 3-clock envelope)
          st_n <= S_WR_W1;
        end if;

      ------------------------------------------------------------------------
      -- READ HIT (2 clocks)
      ------------------------------------------------------------------------
      when S_RD_HIT_OUT =>
        busy_r   <= '1';
        oe_r     <= '1';                            -- present data this cycle
        cdout_r  <= cdout_r;                        -- (drive via datapath mux)
        st_n     <= S_RD_HIT_DONE;

      when S_RD_HIT_DONE =>
        busy_r   <= '0';                            -- done in 2 clocks
        st_n     <= S_IDLE;

      ------------------------------------------------------------------------
      -- WRITE (HIT or MISS) — 3 clocks total; cache write only if hit
      ------------------------------------------------------------------------
      when S_WR_W1 =>
        busy_r <= '1';
        if hit_i = '1' then
          cache_we_r <= '1';                        -- EXACTLY one full cycle
        end if;
        st_n <= S_WR_W2;

      when S_WR_W2 =>
        busy_r <= '1';
        st_n   <= S_WR_DONE;

      when S_WR_DONE =>
        busy_r <= '0';
        st_n   <= S_IDLE;

      ------------------------------------------------------------------------
      -- READ MISS service (19 clocks)
      --  - Assert mem_en for ONE cycle, MA points to last-byte address (byte_off="00")
      --  - Wait 8 negedges -> first byte; then bytes at 10/12/14 negedges
      --  - Each byte written for one full cycle; tag/valid set only on first
      ------------------------------------------------------------------------
      when S_RM_REQ =>
        busy_r   <= '1';
        mem_en_r <= '1';                            -- one cycle pulse
        -- Drive MA to last byte in the block: byte_off="00" per spec
        ca_last_byte := ca_r(5 downto 2) & "00";
        MA_r     <= ca_last_byte;
        mem_wait <= 0;
        byte_idx <= 0;
        two_cyc  <= 0;
        st_n     <= S_RM_WAIT;

      when S_RM_WAIT =>
        busy_r <= '1';
        if mem_wait = 7 then                        -- 0..7 => 8 negedges
          st_n <= S_RM_BYTE_SETUP;
        else
          mem_wait <= mem_wait + 1;
        end if;

      when S_RM_BYTE_SETUP =>
        busy_r <= '1';
        -- First filled byte: program tag/valid
        if byte_idx = 0 then
          tag_we_r   <= '1';
          valid_we_r <= '1';
        end if;
        two_cyc <= 0;
        st_n    <= S_RM_BYTE_WE;

      when S_RM_BYTE_WE =>
        busy_r     <= '1';
        cache_we_r <= '1';                          -- hold for one full cycle
        if two_cyc = 1 then                         -- after 2 negedges with MD stable
          st_n <= S_RM_NEXT;
        else
          two_cyc <= two_cyc + 1;
        end if;

      when S_RM_NEXT =>
        busy_r <= '1';
        if byte_idx = 3 then
          st_n <= S_RM_FINISH1;
        else
          byte_idx <= byte_idx + 1;

          -- Next byte arrives 2 negedges later (10/12/14), reuse WAIT with 1 cycle preset
          mem_wait <= 1;                            -- we’ve already consumed current negedge
          st_n     <= S_RM_WAIT;
        end if;

      when S_RM_FINISH1 =>
        busy_r  <= '1';
        oe_r    <= '1';                             -- present requested byte
        st_n    <= S_RM_FINISH2;

      when S_RM_FINISH2 =>
        busy_r  <= '0';
        st_n    <= S_IDLE;

      when others =>
        st_n <= S_IDLE;
    end case;
  end process;

end behavioral_fsm;
