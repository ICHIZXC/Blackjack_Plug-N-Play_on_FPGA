library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Dealer_Main is
    port (
        i_clk_20mhz : in  std_logic;
        i_pb1_start : in  std_logic;
        i_kdet_p1   : in  std_logic;
        i_kdet_p2   : in  std_logic;
        i_kdet_p3   : in  std_logic;
        i_kdet_p4   : in  std_logic;
        i_uart_rx_p1 : in  std_logic;
        o_uart_tx_p1 : out std_logic;
        i_uart_rx_p2 : in  std_logic;
        o_uart_tx_p2 : out std_logic;
        i_uart_rx_p3 : in  std_logic;
        o_uart_tx_p3 : out std_logic;
        i_uart_rx_p4 : in  std_logic;
        o_uart_tx_p4 : out std_logic;
        o_anodes    : out std_logic_vector(3 downto 0);
        o_segments  : out std_logic_vector(7 downto 0);
        o_buzzer    : out std_logic
    );
end entity Dealer_Main;

architecture rtl of Dealer_Main is

    component uart_rx is
        generic ( CLK_FREQ  : integer := 20000000; BAUD_RATE : integer := 9600 );
        port ( clk : in  std_logic; reset : in  std_logic; i_rx_serial : in  std_logic; o_rx_dv : out std_logic; o_data : out std_logic_vector(7 downto 0) );
    end component uart_rx;
    component uart_tx is
        generic ( CLK_FREQ  : integer := 20000000; BAUD_RATE : integer := 9600 );
        port ( clk : in  std_logic; reset : in  std_logic; i_tx_start : in  std_logic; i_data : in  std_logic_vector(7 downto 0); o_tx_serial : out std_logic; o_tx_busy : out std_logic );
    end component uart_tx;
    component RNG_Module is
        port ( i_clk : in  std_logic; i_enable : in  std_logic; o_rand_val : out std_logic_vector(15 downto 0) );
    end component RNG_Module;
    component Seven_Segment_Driver is
        port (
            i_clk     : in  std_logic;
            i_seg_1   : in  std_logic_vector(6 downto 0);
            i_seg_2   : in  std_logic_vector(6 downto 0);
            i_seg_3   : in  std_logic_vector(6 downto 0);
            i_seg_4   : in  std_logic_vector(6 downto 0);
            i_dp_1    : in  std_logic;
            i_dp_2    : in  std_logic;
            i_dp_3    : in  std_logic;
            i_dp_4    : in  std_logic;
            o_an      : out std_logic_vector(3 downto 0);
            o_seg     : out std_logic_vector(7 downto 0)
        );
    end component Seven_Segment_Driver;

    constant C_CMD_START_GAME  : std_logic_vector(7 downto 0) := x"01";
    constant C_CMD_YOUR_TURN   : std_logic_vector(7 downto 0) := x"02";
    constant C_CMD_RESULT_WIN  : std_logic_vector(7 downto 0) := x"10";
    constant C_CMD_RESULT_LOSE : std_logic_vector(7 downto 0) := x"11";
    constant C_CMD_RESULT_PUSH : std_logic_vector(7 downto 0) := x"12";
    constant C_CMD_RESULT_BJ_WIN : std_logic_vector(7 downto 0) := x"13";
    constant C_CMD_BUST        : std_logic_vector(7 downto 0) := x"80";
    constant C_CMD_STAND       : std_logic_vector(7 downto 0) := x"90";
    constant C_CMD_ACK_SCORE   : std_logic_vector(7 downto 0) := x"A0";
    constant C_CMD_BLACKJACK   : std_logic_vector(7 downto 0) := x"B0";
    constant C_ACK_BET         : std_logic_vector(7 downto 0) := x"A1";
    constant C_NO_MONEY        : std_logic_vector(7 downto 0) := x"A2";
    
    constant C_SEG_0 : std_logic_vector(6 downto 0) := "0111111";
    constant C_SEG_1 : std_logic_vector(6 downto 0) := "0000110";
    constant C_SEG_2 : std_logic_vector(6 downto 0) := "1011011";
    constant C_SEG_3 : std_logic_vector(6 downto 0) := "1001111";
    constant C_SEG_4 : std_logic_vector(6 downto 0) := "1100110";
    constant C_SEG_5 : std_logic_vector(6 downto 0) := "1101101";
    constant C_SEG_6 : std_logic_vector(6 downto 0) := "1111101";
    constant C_SEG_7 : std_logic_vector(6 downto 0) := "0000111";
    constant C_SEG_8 : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_9 : std_logic_vector(6 downto 0) := "1101111";
    constant C_SEG_b : std_logic_vector(6 downto 0) := "1111100";
    constant C_SEG_P : std_logic_vector(6 downto 0) := "1110011";
    constant C_SEG_S : std_logic_vector(6 downto 0) := "1101101";
    constant C_SEG_t : std_logic_vector(6 downto 0) := "1111000";
    constant C_SEG_U : std_logic_vector(6 downto 0) := "0111110";
    constant C_SEG_DASH: std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_BLANK:std_logic_vector(6 downto 0) := "0000000";
    constant C_TIMER_5_SEC : integer := 100_000_000;
    constant C_TIMER_2_SEC : integer := 40_000_000;
    constant C_TIMER_1_SEC : integer := 20_000_000;
    constant C_TIMER_50_MS : integer := 1_000_000;

    type t_fsm_state is (
        S_IDLE,
        S_DEALER_DRAW,
        S_START_GAME_P1_SEND_CMD,
        S_WAIT_P1_BET_ACK,
        S_START_GAME_P2_SEND_CMD,
        S_WAIT_P2_BET_ACK,
        S_START_GAME_P3_SEND_CMD,
        S_WAIT_P3_BET_ACK,
        S_START_GAME_P4_SEND_CMD,
        S_WAIT_P4_BET_ACK,
        S_P1_TURN_CHECK, S_P1_TURN_SEND_CMD, S_WAIT_P1_MOVE, S_P1_ACK_SCORE, S_WAIT_P1_SCORE,
        S_P2_TURN_CHECK, S_P2_TURN_SEND_CMD, S_WAIT_P2_MOVE, S_P2_ACK_SCORE, S_WAIT_P2_SCORE,
        S_P3_TURN_CHECK, S_P3_TURN_SEND_CMD, S_WAIT_P3_MOVE, S_P3_ACK_SCORE, S_WAIT_P3_SCORE,
        S_P4_TURN_CHECK, S_P4_TURN_SEND_CMD, S_WAIT_P4_MOVE, S_P4_ACK_SCORE, S_WAIT_P4_SCORE,
        S_CHECK_ALL_BUST,
        S_DEALER_PAUSE_START,
        S_DEALER_TURN_CHECK,
        S_DEALER_TURN_DRAW,
        S_DEALER_DRAW_PAUSE,
        S_CALC_RESULTS,
        S_SEND_RESULT_P1_SEND, S_SEND_RESULT_P2_SEND,
        S_SEND_RESULT_P3_SEND, S_SEND_RESULT_P4_SEND,
        S_SHOW_RESULT
    );
    signal s_fsm_state : t_fsm_state := S_IDLE;

    signal s_dealer_score : integer range 0 to 99 := 0;
    signal s_p1_score     : integer range 0 to 99 := 0;
    signal s_p2_score     : integer range 0 to 99 := 0;
    signal s_p3_score     : integer range 0 to 99 := 0;
    signal s_p4_score     : integer range 0 to 99 := 0;
    signal s_dealer_busted : std_logic := '0';
    signal s_p1_busted     : std_logic := '0';
    signal s_p2_busted     : std_logic := '0';
    signal s_p3_busted     : std_logic := '0';
    signal s_p4_busted     : std_logic := '0';
    signal s_p1_blackjack  : std_logic := '0';
    signal s_p2_blackjack  : std_logic := '0';
    signal s_p3_blackjack  : std_logic := '0';
    signal s_p4_blackjack  : std_logic := '0';
    signal s_p1_is_playing : std_logic := '0';
    signal s_p2_is_playing : std_logic := '0';
    signal s_p3_is_playing : std_logic := '0';
    signal s_p4_is_playing : std_logic := '0';
    type t_result is (R_WIN, R_LOSE, R_PUSH, R_BLACKJACK);
    signal s_p1_result : t_result := R_LOSE;
    signal s_p2_result : t_result := R_LOSE;
    signal s_p3_result : t_result := R_LOSE;
    signal s_p4_result : t_result := R_LOSE;
    signal s_rand_val : std_logic_vector(15 downto 0);
    signal s_uart_rx_dv_p1   : std_logic;
    signal s_uart_rx_byte_p1 : std_logic_vector(7 downto 0);
    signal s_uart_tx_byte_p1 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_uart_tx_dv_p1   : std_logic := '0';
    signal s_uart_tx_busy_p1 : std_logic;
    signal s_uart_rx_dv_p2   : std_logic;
    signal s_uart_rx_byte_p2 : std_logic_vector(7 downto 0);
    signal s_uart_tx_byte_p2 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_uart_tx_dv_p2   : std_logic := '0';
    signal s_uart_tx_busy_p2 : std_logic;
    signal s_uart_rx_dv_p3   : std_logic;
    signal s_uart_rx_byte_p3 : std_logic_vector(7 downto 0);
    signal s_uart_tx_byte_p3 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_uart_tx_dv_p3   : std_logic := '0';
    signal s_uart_tx_busy_p3 : std_logic;
    signal s_uart_rx_dv_p4   : std_logic;
    signal s_uart_rx_byte_p4 : std_logic_vector(7 downto 0);
    signal s_uart_tx_byte_p4 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_uart_tx_dv_p4   : std_logic := '0';
    signal s_uart_tx_busy_p4 : std_logic;
    signal s_pb1_prev         : std_logic := '0';
    signal s_pb1_start_rising : std_logic;
    signal s_seg_1 : std_logic_vector(6 downto 0);
    signal s_seg_2 : std_logic_vector(6 downto 0);
    signal s_seg_3 : std_logic_vector(6 downto 0);
    signal s_seg_4 : std_logic_vector(6 downto 0);
    signal s_delay_timer_cnt : integer range 0 to C_TIMER_5_SEC := 0;
    signal s_dealer_hit_trigger : std_logic := '0';
    signal s_beep_timer_cnt     : integer range 0 to C_TIMER_50_MS := 0;
    signal s_beep_on            : std_logic := '0';

    function to_7seg(digit : integer) return std_logic_vector is
    begin
        case digit is
            when 0 => return C_SEG_0;
            when 1 => return C_SEG_1;
            when 2 => return C_SEG_2;
            when 3 => return C_SEG_3;
            when 4 => return C_SEG_4;
            when 5 => return C_SEG_5;
            when 6 => return C_SEG_6;
            when 7 => return C_SEG_7;
            when 8 => return C_SEG_8;
            when 9 => return C_SEG_9;
            when others => return C_SEG_BLANK;
        end case;
    end function to_7seg;
    function draw_weighted_card(rand_val : std_logic_vector(15 downto 0)) return integer is
        variable v_index : integer range 0 to 12;
        variable v_card_val : integer range 1 to 10;
    begin
        v_index := to_integer(unsigned(rand_val)) mod 13; 
        case v_index is
            when 0  => v_card_val := 1;
            when 1  => v_card_val := 2;
            when 2  => v_card_val := 3;
            when 3  => v_card_val := 4;
            when 4  => v_card_val := 5;
            when 5  => v_card_val := 6;
            when 6  => v_card_val := 7;
            when 7  => v_card_val := 8;
            when 8  => v_card_val := 9;
            when 9  => v_card_val := 10;
            when 10 => v_card_val := 10;
            when 11 => v_card_val := 10;
            when 12 => v_card_val := 10;
            when others => v_card_val := 10;
        end case;
        return v_card_val;
    end function draw_weighted_card;

begin

    U_UART_RX_P1 : uart_rx port map ( clk => i_clk_20mhz, reset => '1', i_rx_serial => i_uart_rx_p1, o_rx_dv => s_uart_rx_dv_p1, o_data => s_uart_rx_byte_p1 );
    U_UART_TX_P1 : uart_tx port map ( clk => i_clk_20mhz, reset => '1', i_tx_start => s_uart_tx_dv_p1, i_data => s_uart_tx_byte_p1, o_tx_serial => o_uart_tx_p1, o_tx_busy => s_uart_tx_busy_p1 );
    U_UART_RX_P2 : uart_rx port map ( clk => i_clk_20mhz, reset => '1', i_rx_serial => i_uart_rx_p2, o_rx_dv => s_uart_rx_dv_p2, o_data => s_uart_rx_byte_p2 );
    U_UART_TX_P2 : uart_tx port map ( clk => i_clk_20mhz, reset => '1', i_tx_start => s_uart_tx_dv_p2, i_data => s_uart_tx_byte_p2, o_tx_serial => o_uart_tx_p2, o_tx_busy => s_uart_tx_busy_p2 );
    U_UART_RX_P3 : uart_rx port map ( clk => i_clk_20mhz, reset => '1', i_rx_serial => i_uart_rx_p3, o_rx_dv => s_uart_rx_dv_p3, o_data => s_uart_rx_byte_p3 );
    U_UART_TX_P3 : uart_tx port map ( clk => i_clk_20mhz, reset => '1', i_tx_start => s_uart_tx_dv_p3, i_data => s_uart_tx_byte_p3, o_tx_serial => o_uart_tx_p3, o_tx_busy => s_uart_tx_busy_p3 );
    U_UART_RX_P4 : uart_rx port map ( clk => i_clk_20mhz, reset => '1', i_rx_serial => i_uart_rx_p4, o_rx_dv => s_uart_rx_dv_p4, o_data => s_uart_rx_byte_p4 );
    U_UART_TX_P4 : uart_tx port map ( clk => i_clk_20mhz, reset => '1', i_tx_start => s_uart_tx_dv_p4, i_data => s_uart_tx_byte_p4, o_tx_serial => o_uart_tx_p4, o_tx_busy => s_uart_tx_busy_p4 );
    U_RNG : RNG_Module port map ( i_clk => i_clk_20mhz, i_enable => '1', o_rand_val => s_rand_val );
    U_7SEG : Seven_Segment_Driver port map ( i_clk => i_clk_20mhz, i_seg_1 => s_seg_1, i_seg_2 => s_seg_2, i_seg_3 => s_seg_3, i_seg_4 => s_seg_4, i_dp_1 => '0', i_dp_2 => '0', i_dp_3 => '0', i_dp_4 => '0', o_an => o_anodes, o_seg => o_segments );

    process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            s_pb1_prev         <= i_pb1_start;
            s_pb1_start_rising <= (not s_pb1_prev) and i_pb1_start;
        end if;
    end process;

    process(i_clk_20mhz)
        variable v_rand_draw : integer range 0 to 11;
        variable v_new_score : integer range 0 to 99;
        variable v_p1_still_in : boolean;
        variable v_p2_still_in : boolean;
        variable v_p3_still_in : boolean;
        variable v_p4_still_in : boolean;
    begin
        if rising_edge(i_clk_20mhz) then
            s_uart_tx_dv_p1 <= '0';
            s_uart_tx_dv_p2 <= '0';
            s_uart_tx_dv_p3 <= '0';
            s_uart_tx_dv_p4 <= '0';
            s_dealer_hit_trigger <= '0';
            
            case s_fsm_state is
            
                when S_IDLE =>
                    s_dealer_score  <= 0;
                    s_p1_score <= 0; s_p2_score <= 0; s_p3_score <= 0; s_p4_score <= 0;
                    s_dealer_busted <= '0'; s_p1_busted <= '0'; s_p2_busted <= '0'; s_p3_busted <= '0'; s_p4_busted <= '0';
                    s_p1_blackjack <= '0'; s_p2_blackjack <= '0'; s_p3_blackjack <= '0'; s_p4_blackjack <= '0';
                    s_p1_is_playing <= '0'; s_p2_is_playing <= '0'; s_p3_is_playing <= '0'; s_p4_is_playing <= '0';
                    if s_pb1_start_rising = '1' and (i_kdet_p1 = '1' or i_kdet_p2 = '1' or i_kdet_p3 = '1' or i_kdet_p4 = '1') then
                        s_fsm_state <= S_DEALER_DRAW;
                    end if;
            
                when S_DEALER_DRAW =>
                    v_rand_draw := draw_weighted_card(s_rand_val);
                    if v_rand_draw = 1 then
                        s_dealer_score <= 11;
                    else
                        s_dealer_score <= v_rand_draw;
                    end if;
                    s_fsm_state    <= S_START_GAME_P1_SEND_CMD;

                when S_START_GAME_P1_SEND_CMD =>
                    if i_kdet_p1 = '0' or s_uart_tx_busy_p1 = '1' then
                        s_fsm_state <= S_START_GAME_P2_SEND_CMD;
                    else
                        s_uart_tx_byte_p1 <= C_CMD_START_GAME;
                        s_uart_tx_dv_p1   <= '1';
                        s_fsm_state       <= S_WAIT_P1_BET_ACK;
                    end if;
                when S_WAIT_P1_BET_ACK =>
                    if s_uart_rx_dv_p1 = '1' then
                        if s_uart_rx_byte_p1 = C_ACK_BET then
                            s_p1_is_playing <= '1';
                        end if;
                        s_fsm_state <= S_START_GAME_P2_SEND_CMD;
                    end if;
                when S_START_GAME_P2_SEND_CMD =>
                    if i_kdet_p2 = '0' or s_uart_tx_busy_p2 = '1' then
                        s_fsm_state <= S_START_GAME_P3_SEND_CMD;
                    else
                        s_uart_tx_byte_p2 <= C_CMD_START_GAME;
                        s_uart_tx_dv_p2   <= '1';
                        s_fsm_state       <= S_WAIT_P2_BET_ACK;
                    end if;
                when S_WAIT_P2_BET_ACK =>
                    if s_uart_rx_dv_p2 = '1' then
                        if s_uart_rx_byte_p2 = C_ACK_BET then
                            s_p2_is_playing <= '1';
                        end if;
                        s_fsm_state <= S_START_GAME_P3_SEND_CMD;
                    end if;
                when S_START_GAME_P3_SEND_CMD =>
                    if i_kdet_p3 = '0' or s_uart_tx_busy_p3 = '1' then
                        s_fsm_state <= S_START_GAME_P4_SEND_CMD;
                    else
                        s_uart_tx_byte_p3 <= C_CMD_START_GAME;
                        s_uart_tx_dv_p3   <= '1';
                        s_fsm_state       <= S_WAIT_P3_BET_ACK;
                    end if;
                when S_WAIT_P3_BET_ACK =>
                    if s_uart_rx_dv_p3 = '1' then
                        if s_uart_rx_byte_p3 = C_ACK_BET then
                            s_p3_is_playing <= '1';
                        end if;
                        s_fsm_state <= S_START_GAME_P4_SEND_CMD;
                    end if;
                when S_START_GAME_P4_SEND_CMD =>
                    if i_kdet_p4 = '0' or s_uart_tx_busy_p4 = '1' then
                        s_fsm_state <= S_P1_TURN_CHECK;
                    else
                        s_uart_tx_byte_p4 <= C_CMD_START_GAME;
                        s_uart_tx_dv_p4   <= '1';
                        s_fsm_state       <= S_WAIT_P4_BET_ACK;
                    end if;
                when S_WAIT_P4_BET_ACK =>
                    if s_uart_rx_dv_p4 = '1' then
                        if s_uart_rx_byte_p4 = C_ACK_BET then
                            s_p4_is_playing <= '1';
                        end if;
                        s_fsm_state <= S_P1_TURN_CHECK;
                    end if;
                
                when S_P1_TURN_CHECK =>
                    if s_p1_is_playing = '1' and i_kdet_p1 = '1' and s_p1_busted = '0' and s_p1_blackjack = '0' then
                        s_fsm_state <= S_P1_TURN_SEND_CMD;
                    else
                        s_fsm_state <= S_P2_TURN_CHECK;
                    end if;
                when S_P1_TURN_SEND_CMD =>
                    if s_uart_tx_busy_p1 = '0' then
                        s_uart_tx_byte_p1 <= C_CMD_YOUR_TURN;
                        s_uart_tx_dv_p1   <= '1';
                        s_fsm_state       <= S_WAIT_P1_MOVE;
                    end if;
                when S_WAIT_P1_MOVE =>
                    if s_uart_rx_dv_p1 = '1' then
                        if s_uart_rx_byte_p1 = C_CMD_BUST then
                            s_p1_busted <= '1';
                            s_fsm_state <= S_P2_TURN_CHECK;
                        elsif s_uart_rx_byte_p1 = C_CMD_STAND then
                            s_fsm_state <= S_P1_ACK_SCORE;
                        elsif s_uart_rx_byte_p1 = C_CMD_BLACKJACK then
                            s_p1_blackjack <= '1';
                            s_p1_score     <= 21;
                            s_fsm_state    <= S_P2_TURN_CHECK;
                        end if;
                    end if;
                when S_P1_ACK_SCORE =>
                    if s_uart_tx_busy_p1 = '0' then
                        s_uart_tx_byte_p1 <= C_CMD_ACK_SCORE;
                        s_uart_tx_dv_p1   <= '1';
                        s_fsm_state       <= S_WAIT_P1_SCORE;
                    end if;
                when S_WAIT_P1_SCORE =>
                    if s_uart_rx_dv_p1 = '1' then
                        s_p1_score  <= to_integer(unsigned(s_uart_rx_byte_p1));
                        s_fsm_state <= S_P2_TURN_CHECK;
                    end if;
                when S_P2_TURN_CHECK =>
                    if s_p2_is_playing = '1' and i_kdet_p2 = '1' and s_p2_busted = '0' and s_p2_blackjack = '0' then
                        s_fsm_state <= S_P2_TURN_SEND_CMD;
                    else
                        s_fsm_state <= S_P3_TURN_CHECK;
                    end if;
                when S_P2_TURN_SEND_CMD =>
                    if s_uart_tx_busy_p2 = '0' then
                        s_uart_tx_byte_p2 <= C_CMD_YOUR_TURN;
                        s_uart_tx_dv_p2   <= '1';
                        s_fsm_state       <= S_WAIT_P2_MOVE;
                    end if;
                when S_WAIT_P2_MOVE =>
                    if s_uart_rx_dv_p2 = '1' then
                        if s_uart_rx_byte_p2 = C_CMD_BUST then
                            s_p2_busted <= '1';
                            s_fsm_state <= S_P3_TURN_CHECK;
                        elsif s_uart_rx_byte_p2 = C_CMD_STAND then
                            s_fsm_state <= S_P2_ACK_SCORE;
                        elsif s_uart_rx_byte_p2 = C_CMD_BLACKJACK then
                            s_p2_blackjack <= '1';
                            s_p2_score     <= 21;
                            s_fsm_state    <= S_P3_TURN_CHECK;
                        end if;
                    end if;
                when S_P2_ACK_SCORE =>
                    if s_uart_tx_busy_p2 = '0' then
                        s_uart_tx_byte_p2 <= C_CMD_ACK_SCORE;
                        s_uart_tx_dv_p2   <= '1';
                        s_fsm_state       <= S_WAIT_P2_SCORE;
                    end if;
                when S_WAIT_P2_SCORE =>
                    if s_uart_rx_dv_p2 = '1' then
                        s_p2_score  <= to_integer(unsigned(s_uart_rx_byte_p2));
                        s_fsm_state <= S_P3_TURN_CHECK;
                    end if;
                when S_P3_TURN_CHECK =>
                    if s_p3_is_playing = '1' and i_kdet_p3 = '1' and s_p3_busted = '0' and s_p3_blackjack = '0' then
                        s_fsm_state <= S_P3_TURN_SEND_CMD;
                    else
                        s_fsm_state <= S_P4_TURN_CHECK;
                    end if;
                when S_P3_TURN_SEND_CMD =>
                    if s_uart_tx_busy_p3 = '0' then
                        s_uart_tx_byte_p3 <= C_CMD_YOUR_TURN;
                        s_uart_tx_dv_p3   <= '1';
                        s_fsm_state       <= S_WAIT_P3_MOVE;
                    end if;
                when S_WAIT_P3_MOVE =>
                    if s_uart_rx_dv_p3 = '1' then
                        if s_uart_rx_byte_p3 = C_CMD_BUST then
                            s_p3_busted <= '1';
                            s_fsm_state <= S_P4_TURN_CHECK;
                        elsif s_uart_rx_byte_p3 = C_CMD_STAND then
                            s_fsm_state <= S_P3_ACK_SCORE;
                        elsif s_uart_rx_byte_p3 = C_CMD_BLACKJACK then
                            s_p3_blackjack <= '1';
                            s_p3_score     <= 21;
                            s_fsm_state    <= S_P4_TURN_CHECK;
                        end if;
                    end if;
                when S_P3_ACK_SCORE =>
                    if s_uart_tx_busy_p3 = '0' then
                        s_uart_tx_byte_p3 <= C_CMD_ACK_SCORE;
                        s_uart_tx_dv_p3   <= '1';
                        s_fsm_state       <= S_WAIT_P3_SCORE;
                    end if;
                when S_WAIT_P3_SCORE =>
                    if s_uart_rx_dv_p3 = '1' then
                        s_p3_score  <= to_integer(unsigned(s_uart_rx_byte_p3));
                        s_fsm_state <= S_P4_TURN_CHECK;
                    end if;
                when S_P4_TURN_CHECK =>
                    if s_p4_is_playing = '1' and i_kdet_p4 = '1' and s_p4_busted = '0' and s_p4_blackjack = '0' then
                        s_fsm_state <= S_P4_TURN_SEND_CMD;
                    else
                        s_fsm_state <= S_CHECK_ALL_BUST;
                    end if;
                when S_P4_TURN_SEND_CMD =>
                    if s_uart_tx_busy_p4 = '0' then
                        s_uart_tx_byte_p4 <= C_CMD_YOUR_TURN;
                        s_uart_tx_dv_p4   <= '1';
                        s_fsm_state       <= S_WAIT_P4_MOVE;
                    end if;
                when S_WAIT_P4_MOVE =>
                    if s_uart_rx_dv_p4 = '1' then
                        if s_uart_rx_byte_p4 = C_CMD_BUST then
                            s_p4_busted <= '1';
                            s_fsm_state <= S_CHECK_ALL_BUST;
                        elsif s_uart_rx_byte_p4 = C_CMD_STAND then
                            s_fsm_state <= S_P4_ACK_SCORE;
                        elsif s_uart_rx_byte_p4 = C_CMD_BLACKJACK then
                            s_p4_blackjack <= '1';
                            s_p4_score     <= 21;
                            s_fsm_state    <= S_CHECK_ALL_BUST;
                        end if;
                    end if;
                when S_P4_ACK_SCORE =>
                    if s_uart_tx_busy_p4 = '0' then
                        s_uart_tx_byte_p4 <= C_CMD_ACK_SCORE;
                        s_uart_tx_dv_p4   <= '1';
                        s_fsm_state       <= S_WAIT_P4_SCORE;
                    end if;
                when S_WAIT_P4_SCORE =>
                    if s_uart_rx_dv_p4 = '1' then
                        s_p4_score  <= to_integer(unsigned(s_uart_rx_byte_p4));
                        s_fsm_state <= S_CHECK_ALL_BUST;
                    end if;
                
                when S_CHECK_ALL_BUST =>
                    v_p1_still_in := (s_p1_is_playing = '1' and i_kdet_p1 = '1' and s_p1_busted = '0' and s_p1_blackjack = '0');
                    v_p2_still_in := (s_p2_is_playing = '1' and i_kdet_p2 = '1' and s_p2_busted = '0' and s_p2_blackjack = '0');
                    v_p3_still_in := (s_p3_is_playing = '1' and i_kdet_p3 = '1' and s_p3_busted = '0' and s_p3_blackjack = '0');
                    v_p4_still_in := (s_p4_is_playing = '1' and i_kdet_p4 = '1' and s_p4_busted = '0' and s_p4_blackjack = '0');
                    if (v_p1_still_in or v_p2_still_in or v_p3_still_in or v_p4_still_in) then
                        s_delay_timer_cnt <= 0;
                        s_fsm_state       <= S_DEALER_PAUSE_START;
                    else
                        s_fsm_state <= S_CALC_RESULTS;
                    end if;
                when S_DEALER_PAUSE_START =>
                    if s_delay_timer_cnt = C_TIMER_2_SEC - 1 then
                        s_delay_timer_cnt <= 0;
                        s_fsm_state       <= S_DEALER_TURN_CHECK;
                    else
                        s_delay_timer_cnt <= s_delay_timer_cnt + 1;
                    end if;
                when S_DEALER_TURN_CHECK =>
                    if s_dealer_score >= 17 then
                        s_fsm_state <= S_CALC_RESULTS;
                    else
                        s_fsm_state <= S_DEALER_TURN_DRAW;
                    end if;

                when S_DEALER_TURN_DRAW =>
                    v_rand_draw := draw_weighted_card(s_rand_val);
                    if v_rand_draw = 1 and (s_dealer_score + 11 <= 21) then
                        v_new_score := s_dealer_score + 11;
                    else
                        v_new_score := s_dealer_score + v_rand_draw;
                    end if;
                    s_dealer_score <= v_new_score;
                    if v_new_score > 21 then
                        s_dealer_busted <= '1';
                    end if;
                    s_dealer_hit_trigger <= '1';
                    s_delay_timer_cnt    <= 0;
                    s_fsm_state          <= S_DEALER_DRAW_PAUSE;

                when S_DEALER_DRAW_PAUSE =>
                    if s_delay_timer_cnt = C_TIMER_1_SEC - 1 then
                        s_delay_timer_cnt <= 0;
                        s_fsm_state       <= S_DEALER_TURN_CHECK;
                    else
                        s_delay_timer_cnt <= s_delay_timer_cnt + 1;
                    end if;
                when S_CALC_RESULTS =>
                    if s_p1_blackjack = '1' then
                        if s_dealer_score = 21 and s_dealer_busted = '0' then s_p1_result <= R_PUSH;
                        else s_p1_result <= R_BLACKJACK; end if;
                    elsif s_p1_busted = '1' then s_p1_result <= R_LOSE;
                    elsif s_dealer_busted = '1' then s_p1_result <= R_WIN;
                    elsif s_p1_score > s_dealer_score then s_p1_result <= R_WIN;
                    elsif s_p1_score = s_dealer_score then s_p1_result <= R_PUSH;
                    else s_p1_result <= R_LOSE;
                    end if;
                    if s_p2_blackjack = '1' then
                        if s_dealer_score = 21 and s_dealer_busted = '0' then s_p2_result <= R_PUSH;
                        else s_p2_result <= R_BLACKJACK; end if;
                    elsif s_p2_busted = '1' then s_p2_result <= R_LOSE;
                    elsif s_dealer_busted = '1' then s_p2_result <= R_WIN;
                    elsif s_p2_score > s_dealer_score then s_p2_result <= R_WIN;
                    elsif s_p2_score = s_dealer_score then s_p2_result <= R_PUSH;
                    else s_p2_result <= R_LOSE;
                    end if;
                    if s_p3_blackjack = '1' then
                        if s_dealer_score = 21 and s_dealer_busted = '0' then s_p3_result <= R_PUSH;
                        else s_p3_result <= R_BLACKJACK; end if;
                    elsif s_p3_busted = '1' then s_p3_result <= R_LOSE;
                    elsif s_dealer_busted = '1' then s_p3_result <= R_WIN;
                    elsif s_p3_score > s_dealer_score then s_p3_result <= R_WIN;
                    elsif s_p3_score = s_dealer_score then s_p3_result <= R_PUSH;
                    else s_p3_result <= R_LOSE;
                    end if;
                    if s_p4_blackjack = '1' then
                        if s_dealer_score = 21 and s_dealer_busted = '0' then s_p4_result <= R_PUSH;
                        else s_p4_result <= R_BLACKJACK; end if;
                    elsif s_p4_busted = '1' then s_p4_result <= R_LOSE;
                    elsif s_dealer_busted = '1' then s_p4_result <= R_WIN;
                    elsif s_p4_score > s_dealer_score then s_p4_result <= R_WIN;
                    elsif s_p4_score = s_dealer_score then s_p4_result <= R_PUSH;
                    else s_p4_result <= R_LOSE;
                    end if;
                    s_fsm_state <= S_SEND_RESULT_P1_SEND;
                when S_SEND_RESULT_P1_SEND =>
                    if i_kdet_p1 = '0' or s_p1_is_playing = '0' or s_uart_tx_busy_p1 = '1' then
                        s_fsm_state <= S_SEND_RESULT_P2_SEND;
                    else
                        case s_p1_result is
                            when R_WIN  => s_uart_tx_byte_p1 <= C_CMD_RESULT_WIN;
                            when R_LOSE => s_uart_tx_byte_p1 <= C_CMD_RESULT_LOSE;
                            when R_PUSH => s_uart_tx_byte_p1 <= C_CMD_RESULT_PUSH;
                            when R_BLACKJACK => s_uart_tx_byte_p1 <= C_CMD_RESULT_BJ_WIN;
                        end case;
                        s_uart_tx_dv_p1 <= '1';
                        s_fsm_state     <= S_SEND_RESULT_P2_SEND;
                    end if;
                when S_SEND_RESULT_P2_SEND =>
                    if i_kdet_p2 = '0' or s_p2_is_playing = '0' or s_uart_tx_busy_p2 = '1' then
                        s_fsm_state <= S_SEND_RESULT_P3_SEND;
                    else
                        case s_p2_result is
                            when R_WIN  => s_uart_tx_byte_p2 <= C_CMD_RESULT_WIN;
                            when R_LOSE => s_uart_tx_byte_p2 <= C_CMD_RESULT_LOSE;
                            when R_PUSH => s_uart_tx_byte_p2 <= C_CMD_RESULT_PUSH;
                            when R_BLACKJACK => s_uart_tx_byte_p2 <= C_CMD_RESULT_BJ_WIN;
                        end case;
                        s_uart_tx_dv_p2 <= '1';
                        s_fsm_state     <= S_SEND_RESULT_P3_SEND;
                    end if;
                when S_SEND_RESULT_P3_SEND =>
                    if i_kdet_p3 = '0' or s_p3_is_playing = '0' or s_uart_tx_busy_p3 = '1' then
                        s_fsm_state <= S_SEND_RESULT_P4_SEND;
                    else
                        case s_p3_result is
                            when R_WIN  => s_uart_tx_byte_p3 <= C_CMD_RESULT_WIN;
                            when R_LOSE => s_uart_tx_byte_p3 <= C_CMD_RESULT_LOSE;
                            when R_PUSH => s_uart_tx_byte_p3 <= C_CMD_RESULT_PUSH;
                            when R_BLACKJACK => s_uart_tx_byte_p3 <= C_CMD_RESULT_BJ_WIN;
                        end case;
                        s_uart_tx_dv_p3 <= '1';
                        s_fsm_state     <= S_SEND_RESULT_P4_SEND;
                    end if;
                when S_SEND_RESULT_P4_SEND =>
                    s_delay_timer_cnt <= 0;
                    if i_kdet_p4 = '0' or s_p4_is_playing = '0' or s_uart_tx_busy_p4 = '1' then
                        s_fsm_state <= S_SHOW_RESULT;
                    else
                        case s_p4_result is
                            when R_WIN  => s_uart_tx_byte_p4 <= C_CMD_RESULT_WIN;
                            when R_LOSE => s_uart_tx_byte_p4 <= C_CMD_RESULT_LOSE;
                            when R_PUSH => s_uart_tx_byte_p4 <= C_CMD_RESULT_PUSH;
                            when R_BLACKJACK => s_uart_tx_byte_p4 <= C_CMD_RESULT_BJ_WIN;
                        end case;
                        s_uart_tx_dv_p4 <= '1';
                        s_fsm_state     <= S_SHOW_RESULT;
                    end if;
                when S_SHOW_RESULT =>
                    if s_delay_timer_cnt = C_TIMER_5_SEC - 1 then
                        s_delay_timer_cnt <= 0;
                        s_fsm_state        <= S_IDLE;
                    else
                        s_delay_timer_cnt <= s_delay_timer_cnt + 1;
                    end if;
            end case;
        end if;
    end process;

    process(s_fsm_state, i_kdet_p1, i_kdet_p2, i_kdet_p3, i_kdet_p4, s_dealer_score, s_dealer_busted)
        variable v_digit_1 : integer;
        variable v_digit_2 : integer;
    begin
        s_seg_1 <= C_SEG_BLANK;
        s_seg_2 <= C_SEG_BLANK;
        s_seg_3 <= C_SEG_BLANK;
        s_seg_4 <= C_SEG_BLANK;
        
        case s_fsm_state is
            
            when S_IDLE =>
                if i_kdet_p1 = '1' then s_seg_4 <= C_SEG_1;
                else s_seg_4 <= C_SEG_DASH; end if;
                if i_kdet_p2 = '1' then s_seg_3 <= C_SEG_2;
                else s_seg_3 <= C_SEG_DASH; end if;
                if i_kdet_p3 = '1' then s_seg_2 <= C_SEG_3;
                else s_seg_2 <= C_SEG_DASH; end if;
                if i_kdet_p4 = '1' then s_seg_1 <= C_SEG_4;
                else s_seg_1 <= C_SEG_DASH; end if;
            
            when S_P1_TURN_CHECK | S_P1_TURN_SEND_CMD | S_WAIT_P1_MOVE | S_P1_ACK_SCORE | S_WAIT_P1_SCORE =>
                s_seg_4 <= C_SEG_P;
                s_seg_3 <= C_SEG_1;
                v_digit_1 := s_dealer_score mod 10;
                v_digit_2 := (s_dealer_score / 10) mod 10;
                s_seg_1 <= to_7seg(v_digit_1);
                s_seg_2 <= to_7seg(v_digit_2);
                
            when S_P2_TURN_CHECK | S_P2_TURN_SEND_CMD | S_WAIT_P2_MOVE | S_P2_ACK_SCORE | S_WAIT_P2_SCORE =>
                s_seg_4 <= C_SEG_P;
                s_seg_3 <= C_SEG_2;
                v_digit_1 := s_dealer_score mod 10;
                v_digit_2 := (s_dealer_score / 10) mod 10;
                s_seg_1 <= to_7seg(v_digit_1);
                s_seg_2 <= to_7seg(v_digit_2);

            when S_P3_TURN_CHECK | S_P3_TURN_SEND_CMD | S_WAIT_P3_MOVE | S_P3_ACK_SCORE | S_WAIT_P3_SCORE =>
                s_seg_4 <= C_SEG_P;
                s_seg_3 <= C_SEG_3;
                v_digit_1 := s_dealer_score mod 10;
                v_digit_2 := (s_dealer_score / 10) mod 10;
                s_seg_1 <= to_7seg(v_digit_1);
                s_seg_2 <= to_7seg(v_digit_2);

            when S_P4_TURN_CHECK | S_P4_TURN_SEND_CMD | S_WAIT_P4_MOVE | S_P4_ACK_SCORE | S_WAIT_P4_SCORE =>
                s_seg_4 <= C_SEG_P;
                s_seg_3 <= C_SEG_4;
                v_digit_1 := s_dealer_score mod 10;
                v_digit_2 := (s_dealer_score / 10) mod 10;
                s_seg_1 <= to_7seg(v_digit_1);
                s_seg_2 <= to_7seg(v_digit_2);

            when others =>
                if s_dealer_busted = '1' then
                    s_seg_4 <= C_SEG_b;
                    s_seg_3 <= C_SEG_U; 
                    s_seg_2 <= C_SEG_S; 
                    s_seg_1 <= C_SEG_t;
                else
                    v_digit_1 := s_dealer_score mod 10;
                    v_digit_2 := (s_dealer_score / 10) mod 10;
                    s_seg_1 <= to_7seg(v_digit_1);
                    s_seg_2 <= to_7seg(v_digit_2);
                    s_seg_3 <= C_SEG_BLANK;
                    s_seg_4 <= C_SEG_BLANK;
                end if;
        end case;
    end process;

    process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            if s_dealer_hit_trigger = '1' then
                s_beep_on <= '1';
                s_beep_timer_cnt <= 0;
            elsif s_beep_timer_cnt = C_TIMER_50_MS - 1 then
                s_beep_on <= '0';
            elsif s_beep_on = '1' then
                s_beep_timer_cnt <= s_beep_timer_cnt + 1;
            else
                s_beep_timer_cnt <= 0;
            end if;
        end if;
    end process;
    
    o_buzzer <= s_beep_on;

end architecture rtl;