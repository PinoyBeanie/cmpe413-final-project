
-- ============================================================================
-- Entity: cache_fsm
-- Architecture: structural
-- Purpose   : Structural FSM controller for the UMBC cache project
-- Author    : Lance Boac
-- Date      : 2025-10-24
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_fsm is
  port (
    -- Global
    clk        : in  std_logic;  -- system clock (CPU/memory share this)
    reset      : in  std_logic;  -- synchronous high reset for FSM state/ctr

    -- CPU interface
    start      : in  std_logic;  -- goes high on CPU posedge; we sample on negedge
    rd_wr      : in  std_logic;  -- '1' = READ, '0' = WRITE
    tag_hit    : in  std_logic;  -- '1' when (valid && tag match) for indexed block

    -- Control outputs to CPU/datapath
    busy       : out std_logic;  -- asserted while an op is in-flight
    out_en     : out std_logic;  -- pulse to present read data to CPU for 1 cycle

    -- Control outputs to cache array / tag-valid store
    cache_we   : out std_logic;             -- write enable for data byte
    cache_sel  : out std_logic_vector(1 downto 0); -- which byte lane (0..3)
    set_valid  : out std_logic;             -- set valid bit (on first fill write)
    update_tag : out std_logic;             -- write new tag (on first fill write)

    -- Memory interface control
    mem_enable : out std_logic;  -- single-cycle read request on read miss
    -- Optional: expose a simple strobe for each returned byte during fill
    mem_byte_strobe : out std_logic_vector(3 downto 0)  -- pulses sequentially for bytes 0..3
  );
end entity;

architecture structural of cache_fsm is
  -----------------------------------------------------------------------------
  -- State encoding (one-hot, 10 states)
  -----------------------------------------------------------------------------
  constant N_STATES : integer := 10;
  constant S_IDLE           : integer := 0;
  constant S_LATCH_REQ      : integer := 1;
  constant S_CHECK_HIT      : integer := 2;
  constant S_READ_HIT_RESP  : integer := 3;
  constant S_WRITE_HIT      : integer := 4;
  constant S_WRITE_DONE     : integer := 5;
  constant S_READ_MISS_REQ  : integer := 6;
  constant S_READ_MISS_WAIT : integer := 7;
  constant S_READ_MISS_FILL : integer := 8;
  constant S_READ_RESPOND   : integer := 9;

  signal state    : std_logic_vector(N_STATES-1 downto 0) := (others => '0');
  signal n_state  : std_logic_vector(N_STATES-1 downto 0);

  component dff is
    port ( d   : in  std_logic;
           clk : in  std_logic;
           q   : out std_logic;
           qbar: out std_logic );
  end component;

  -- 5-bit counter signals
  signal ctr_d, ctr_q : unsigned(4 downto 0) := (others => '0');
  signal ctr_en       : std_logic;
  signal ctr_clr      : std_logic;
  signal ctr_q_bits   : std_logic_vector(4 downto 0);
  signal ctr_d_bits   : std_logic_vector(4 downto 0);

  -- Derived strobes for memory byte arrival
  signal byte0_stb, byte1_stb, byte2_stb, byte3_stb : std_logic;

  -- Aliases
  alias A_IDLE           is state(S_IDLE);
  alias A_LATCH_REQ      is state(S_LATCH_REQ);
  alias A_CHECK_HIT      is state(S_CHECK_HIT);
  alias A_READ_HIT_RESP  is state(S_READ_HIT_RESP);
  alias A_WRITE_HIT      is state(S_WRITE_HIT);
  alias A_WRITE_DONE     is state(S_WRITE_DONE);
  alias A_READ_MISS_REQ  is state(S_READ_MISS_REQ);
  alias A_READ_MISS_WAIT is state(S_READ_MISS_WAIT);
  alias A_READ_MISS_FILL is state(S_READ_MISS_FILL);
  alias A_READ_RESPOND   is state(S_READ_RESPOND);

begin
  ----------------------------------------------------------------------------
  -- STATE REGISTER (negative-edge dffs)
  ----------------------------------------------------------------------------
  gen_state: for i in 0 to N_STATES-1 generate
    signal qbar_i : std_logic;
  begin
    sreg: dff
      port map (
        d   => n_state(i),
        clk => clk,
        q   => state(i),
        qbar=> qbar_i
      );
  end generate;

  -- NEXT-STATE default/RESET handling
  next_default: process(all)
  begin
    -- Hold by default
    n_state <= state;

    if reset = '1' then
      n_state <= (others => '0');
      n_state(S_IDLE) <= '1';
    end if;
  end process;

  -- NEXT-STATE logic
  next_logic: process(all)
    variable ns : std_logic_vector(N_STATES-1 downto 0);
  begin
    ns := n_state;  -- start from default/held value

    -- IDLE
    if A_IDLE = '1' then
      ns := (others => '0');
      if start = '1' then
        ns(S_LATCH_REQ) := '1';
      else
        ns(S_IDLE) := '1';
      end if;
    end if;

    -- LATCH_REQ
    if A_LATCH_REQ = '1' then
      ns := (others => '0');
      ns(S_CHECK_HIT) := '1';
    end if;

    -- CHECK_HIT
    if A_CHECK_HIT = '1' then
      ns := (others => '0');
      if rd_wr = '1' then
        if tag_hit = '1' then
          ns(S_READ_HIT_RESP) := '1';
        else
          ns(S_READ_MISS_REQ) := '1';
        end if;
      else
        -- WRITE op: both hit and miss use same 2-cycle internal pacing then done
        ns(S_WRITE_HIT) := '1';
      end if;
    end if;

    -- READ_HIT_RESP
    if A_READ_HIT_RESP = '1' then
      ns := (others => '0');
      ns(S_IDLE) := '1';
    end if;

    -- WRITE_HIT
    if A_WRITE_HIT = '1' then
      ns := (others => '0');
      ns(S_WRITE_DONE) := '1';
    end if;

    -- WRITE_DONE
    if A_WRITE_DONE = '1' then
      ns := (others => '0');
      ns(S_IDLE) := '1';
    end if;

    -- READ_MISS_REQ
    if A_READ_MISS_REQ = '1' then
      ns := (others => '0');
      ns(S_READ_MISS_WAIT) := '1';
    end if;

    -- READ_MISS_WAIT
    if A_READ_MISS_WAIT = '1' then
      ns := (others => '0');
      if byte0_stb = '1' then
        ns(S_READ_MISS_FILL) := '1';
      else
        ns(S_READ_MISS_WAIT) := '1';
      end if;
    end if;

    -- READ_MISS_FILL
    if A_READ_MISS_FILL = '1' then
      ns := (others => '0');
      if byte3_stb = '1' then
        ns(S_READ_RESPOND) := '1';
      else
        ns(S_READ_MISS_FILL) := '1';
      end if;
    end if;

    -- READ_RESPOND
    if A_READ_RESPOND = '1' then
      ns := (others => '0');
      ns(S_IDLE) := '1';
    end if;

    n_state <= ns;
  end process;

  ----------------------------------------------------------------------------
  -- COUNTER (negative-edge dffs)
  ----------------------------------------------------------------------------
  ctr_en  <= A_READ_MISS_WAIT or A_READ_MISS_FILL;
  ctr_clr <= A_READ_MISS_REQ or reset;

  ctr_d <= (others => '0') when ctr_clr = '1' else
           (ctr_q + 1)     when ctr_en  = '1' else
           ctr_q;

  ctr_d_bits <= std_logic_vector(ctr_d);

  gen_ctr: for i in 0 to 4 generate
    signal qbar_i : std_logic;
  begin
    dff_ctr: dff
      port map (
        d    => ctr_d_bits(i),
        clk  => clk,
        q    => ctr_q_bits(i),
        qbar => qbar_i
      );
  end generate;

  ctr_q <= unsigned(ctr_q_bits);

  ----------------------------------------------------------------------------
  -- OUTPUT/CONTROL LOGIC
  ----------------------------------------------------------------------------
  busy   <= '0' when A_IDLE = '1' else '1';
  out_en <= '1' when (A_READ_HIT_RESP = '1' or A_READ_RESPOND = '1') else '0';

  cache_we <= '1' when (A_WRITE_HIT = '1' or A_READ_MISS_FILL = '1') else '0';

  -- Byte select during fill (00,01,10,11). For write hit path, you may override
  -- this in your datapath with external muxing; here we default to "00".
  cache_sel <=
      "00" when (A_READ_MISS_FILL = '1' and byte0_stb = '1') else
      "01" when (A_READ_MISS_FILL = '1' and byte1_stb = '1') else
      "10" when (A_READ_MISS_FILL = '1' and byte2_stb = '1') else
      "11" when (A_READ_MISS_FILL = '1' and byte3_stb = '1') else
      "00";

  set_valid  <= '1' when (A_READ_MISS_FILL = '1' and byte0_stb = '1') else '0';
  update_tag <= '1' when (A_READ_MISS_FILL = '1' and byte0_stb = '1') else '0';

  mem_enable <= '1' when A_READ_MISS_REQ = '1' else '0';

  -- Byte arrival strobes: spec says 8,10,12,14 negedges after Enable.
  byte0_stb <= '1' when (A_READ_MISS_WAIT = '1' and ctr_q = to_unsigned(8, 5))  else '0';
  byte1_stb <= '1' when (A_READ_MISS_FILL = '1' and ctr_q = to_unsigned(10, 5)) else '0';
  byte2_stb <= '1' when (A_READ_MISS_FILL = '1' and ctr_q = to_unsigned(12, 5)) else '0';
  byte3_stb <= '1' when (A_READ_MISS_FILL = '1' and ctr_q = to_unsigned(14, 5)) else '0';

  mem_byte_strobe <= byte3_stb & byte2_stb & byte1_stb & byte0_stb;

end architecture structural;
