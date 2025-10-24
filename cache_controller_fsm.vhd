library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_controller_fsm is
  port (
    clk, reset   : in  std_logic;
    start        : in  std_logic;
    rd_wr        : in  std_logic;
    hit_i        : in  std_logic;
    CA           : in  std_logic_vector(5 downto 0);
    CD_in        : in  std_logic_vector(7 downto 0);
    MD           : in  std_logic_vector(7 downto 0);
    busy         : out std_logic;
    oe_cpu       : out std_logic;
    mem_en       : out std_logic;
    MA           : out std_logic_vector(5 downto 0);
    cache_we     : out std_logic;
    cache_waddr  : out std_logic_vector(3 downto 0);
    cache_wdata  : out std_logic_vector(7 downto 0);
    tag_we       : out std_logic;
    tag_wdata    : out std_logic_vector(1 downto 0);
    valid_we     : out std_logic
  );
end cache_controller_fsm;

architecture rtl of cache_controller_fsm is
  type state_t is (
    S_RESET, S_IDLE, S_LATCH, S_CHECK,
    S_RD_HIT_OUT, S_RD_HIT_DONE,
    S_WR_W1, S_WR_W2, S_WR_DONE,
    S_RM_REQ, S_RM_WAIT, S_RM_BYTE_SETUP,
    S_RM_BYTE_WE, S_RM_NEXT, S_RM_FINISH1, S_RM_FINISH2
  );
  signal st, st_n : state_t := S_RESET;

  signal tag_in   : std_logic_vector(1 downto 0);
  signal block_in : std_logic_vector(1 downto 0);
  signal byte_in  : std_logic_vector(1 downto 0);

  signal ca_r     : std_logic_vector(5 downto 0);
  signal rd_wr_r  : std_logic;
  signal cd_r     : std_logic_vector(7 downto 0);

  signal busy_r, oe_r, cache_we_r, tag_we_r, valid_we_r : std_logic := '0';
  signal MA_r     : std_logic_vector(5 downto 0) := (others => '0');
  signal mem_en_r : std_logic := '0';
  signal mem_wait : integer range 0 to 20 := 0;
  signal byte_idx : integer range 0 to 3 := 0;
  signal two_cyc  : integer range 0 to 1 := 0;
begin
  tag_in   <= CA(5 downto 4);
  block_in <= CA(3 downto 2);
  byte_in  <= CA(1 downto 0);

  busy     <= busy_r;
  oe_cpu   <= oe_r;
  cache_we <= cache_we_r;
  tag_we   <= tag_we_r;
  valid_we <= valid_we_r;
  MA       <= MA_r;
  mem_en   <= mem_en_r;

  cache_wdata <= MD;
  cache_waddr <= block_in & std_logic_vector(to_unsigned(byte_idx, 2));
  tag_wdata   <= tag_in;

  process(clk)
  begin
    if falling_edge(clk) then
      if reset='1' then
        st <= S_RESET;
        busy_r <= '0'; oe_r <= '0';
        cache_we_r <= '0'; tag_we_r <= '0';
        valid_we_r <= '0'; mem_en_r <= '0';
        mem_wait <= 0; byte_idx <= 0; two_cyc <= 0;
      else
        mem_en_r <= '0'; oe_r <= '0';
        cache_we_r <= '0'; tag_we_r <= '0'; valid_we_r <= '0';
        st <= st_n;
      end if;
    end if;
  end process;

  process(st, start, rd_wr, CA, CD_in, hit_i, mem_wait, byte_idx, two_cyc)
    variable ca_last_byte : std_logic_vector(5 downto 0);
  begin
    st_n <= st;
    busy_r <= busy_r;
    case st is
      when S_RESET =>
        busy_r <= '0'; st_n <= S_IDLE;
      when S_IDLE =>
        busy_r <= '0';
        if start='1' then st_n <= S_LATCH; end if;
      when S_LATCH =>
        ca_r <= CA; rd_wr_r <= rd_wr; cd_r <= CD_in;
        busy_r <= '1'; st_n <= S_CHECK;
      when S_CHECK =>
        busy_r <= '1';
        if rd_wr_r='1' then
          if hit_i='1' then st_n <= S_RD_HIT_OUT; else st_n <= S_RM_REQ; end if;
        else
          st_n <= S_WR_W1;
        end if;
      when S_RD_HIT_OUT =>
        busy_r <= '1'; oe_r <= '1'; st_n <= S_RD_HIT_DONE;
      when S_RD_HIT_DONE =>
        busy_r <= '0'; st_n <= S_IDLE;
      when S_WR_W1 =>
        busy_r <= '1'; if hit_i='1' then cache_we_r <= '1'; end if;
        st_n <= S_WR_W2;
      when S_WR_W2 =>
        busy_r <= '1'; st_n <= S_WR_DONE;
      when S_WR_DONE =>
        busy_r <= '0'; st_n <= S_IDLE;
      when S_RM_REQ =>
        busy_r <= '1'; mem_en_r <= '1';
        ca_last_byte := CA(5 downto 2) & "00";
        MA_r <= ca_last_byte;
        mem_wait <= 0; byte_idx <= 0; two_cyc <= 0;
        st_n <= S_RM_WAIT;
      when S_RM_WAIT =>
        busy_r <= '1';
        if mem_wait=7 then st_n <= S_RM_BYTE_SETUP;
        else mem_wait <= mem_wait+1; end if;
      when S_RM_BYTE_SETUP =>
        busy_r <= '1';
        if byte_idx=0 then tag_we_r <= '1'; valid_we_r <= '1'; end if;
        two_cyc <= 0; st_n <= S_RM_BYTE_WE;
      when S_RM_BYTE_WE =>
        busy_r <= '1'; cache_we_r <= '1';
        if two_cyc=1 then st_n <= S_RM_NEXT;
        else two_cyc <= two_cyc+1; end if;
      when S_RM_NEXT =>
        busy_r <= '1';
        if byte_idx=3 then st_n <= S_RM_FINISH1;
        else byte_idx <= byte_idx+1; mem_wait <= 1; st_n <= S_RM_WAIT; end if;
      when S_RM_FINISH1 =>
        busy_r <= '1'; oe_r <= '1'; st_n <= S_RM_FINISH2;
      when S_RM_FINISH2 =>
        busy_r <= '0'; st_n <= S_IDLE;
      when others =>
        st_n <= S_IDLE;
    end case;
  end process;
end rtl;
