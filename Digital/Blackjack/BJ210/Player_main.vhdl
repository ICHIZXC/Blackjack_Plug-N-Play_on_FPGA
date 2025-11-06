library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Player_Main is
    port (
        i_clk_20mhz : in  std_logic;
        i_pb1_hit   : in  std_logic;
        i_pb2_stand : in  std_logic;
        i_pb3_double: in  std_logic;
        i_uart_rx   : in  std_logic;
        o_uart_tx   : out std_logic;
        o_anodes    : out std_logic_vector(3 downto 0);
        o_segments  : out std_logic_vector(7 downto 0);
        o_leds      : out std_logic_vector(7 downto 0);
        o_buzzer    : out std_logic
    );
end entity Player_Main;

architecture rtl of Player_Main is

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
        port ( i_clk : in  std_logic; i_seg_1 : in  std_logic_vector(6 downto 0); i_seg_2 : in  std_logic_vector(6 downto 0); i_seg_3 : in  std_logic_vector(6 downto 0); i_seg_4 : in  std_logic_vector(6 downto 0); i_dp_1 : in  std_logic; i_dp_2 : in  std_logic; i_dp_3 : in  std_logic; i_dp_4 : in  std_logic; o_an : out std_logic_vector(3 downto 0); o_seg : out std_logic_vector(7 downto 0); );
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
    constant C_SEG_C : std_logic_vector(6 downto 0) := "0111001";
    constant C_SEG_d : std_logic_vector(6 downto 0) := "1011110";
    constant C_SEG_E : std_logic_vector(6 downto 0) := "1111001";
    constant C_SEG_H : std_logic_vector(6 downto 0) := "1110110";
    constant C_SEG_I : std_logic_vector(6 downto 0) := "0000110";
    constant C_SEG_J : std_logic_vector(6 downto 0) := "0001110";
    constant C_SEG_L : std_logic_vector(6 downto 0) := "0111000";
    constant C_SEG_n : std_logic_vector(6 downto 0) := "1010100";
    constant C_SEG_O : std_logic_vector(6 downto 0) := "0111111";
    constant C_SEG_P : std_logic_vector(6 downto 0) := "1110011";
    constant C_SEG_S : std_logic_vector(6 downto 0) := "1101101";
    constant C_SEG_t : std_logic_vector(6 downto 0) := "1111000";
    constant C_SEG_U : std_logic_vector(6 downto 0) := "0111110";
    constant C_SEG_W : std_logic_vector(6 downto 0) := "1101010";
    constant C_SEG_DASH: std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_BLANK:std_logic_vector(6 downto 0) := "0000000";
    constant C_TIMER_5_SEC : integer := 100_000_000;
    constant C_TIMER_1_SEC : integer := 20_000_000;
    constant C_TIMER_50_MS : integer := 1_000_000;

    type t_fsm_state is (
        S_IDLE_DISCONNECTED,
        S_CHECK_MONEY,
        S_SEND_ACK_BET,
        S_SEND_NO_MONEY,
        S_INIT_DEAL,
        S_WAIT_TURN,
        S_BLACKJACK_SHOW,
        S_BLACKJACK_SEND,
        S_PLAYER_TURN,
        S_PLAYER_HIT,
        S_SHOW_BUST_SCORE,
        S_PLAYER_BUST,
        S_PLAYER_STAND,
        S_WAIT_STAND_ACK,
        S_WAIT_SCORE_SENT,
        S_WAIT_RESULT,
        S_SHOW_RESULT,
        S_IDLE_CONNECTED
    );
    signal s_fsm_state : t_fsm_state := S_IDLE_DISCONNECTED;

    signal s_player_score : integer range 0 to 99 := 0;
    signal s_player_busted : std_logic := '0';
    signal s_money : integer range 0 to 8 := 4;
    signal s_is_doubled : std_logic := '0';
    signal s_has_hit    : std_logic := '0';
    type t_result is (R_WIN, R_LOSE, R_PUSH, R_BLACKJACK);
    signal s_result_type : t_result := R_LOSE;
    signal s_result_timer_cnt : integer range 0 to C_TIMER_5_SEC := 0;
    signal s_delay_timer_cnt : integer range 0 to C_TIMER_1_SEC := 0;
    signal s_beep_timer_cnt : integer range 0 to C_TIMER_1_SEC := 0;
    signal s_beep_on        : std_logic := '0';
    signal s_rand_val : std_logic_vector(15 downto 0);
    signal s_uart_rx_dv   : std_logic;
    signal s_uart_rx_byte : std_logic_vector(7 downto 0);
    signal s_uart_tx_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal s_uart_tx_dv   : std_logic := '0';
    signal s_uart_tx_busy : std_logic;
    
    signal s_pb1_prev         : std_logic := '0';
    signal s_pb2_prev         : std_logic := '0';
    signal s_pb3_prev         : std_logic := '0';
    signal s_pb1_hit_rising   : std_logic;
    signal s_pb2_stand_rising : std_logic;
    signal s_pb3_double_rising: std_logic;

    signal s_seg_1 : std_logic_vector(6 downto 0);
    signal s_seg_2 : std_logic_vector(6 downto 0);
    signal s_seg_3 : std_logic_vector(6 downto 0);
    signal s_seg_4 : std_logic_vector(6 downto 0);
    signal s_dp_1  : std_logic := '0';
    signal s_dp_2  : std_logic := '0';
    signal s_dp_3  : std_logic := '0';
    signal s_dp_4  : std_logic := '0';

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

    U_UART_RX : uart_rx port map ( clk => i_clk_20mhz, reset => '1', i_rx_serial => i_uart_rx, o_rx_dv => s_uart_rx_dv, o_data => s_uart_rx_byte );
    U_UART_TX : uart_tx port map ( clk => i_clk_20mhz, reset => '1', i_tx_start => s_uart_tx_dv, i_data => s_uart_tx_byte, o_tx_serial => o_uart_tx, o_tx_busy => s_uart_tx_busy );
    U_RNG : RNG_Module port map ( i_clk => i_clk_20mhz, i_enable => '1', o_rand_val => s_rand_val );
    U_7SEG : Seven_Segment_Driver port map ( i_clk => i_clk_20mhz, i_seg_1 => s_seg_1, i_seg_2 => s_seg_2, i_seg_3 => s_seg_3, i_seg_4 => s_seg_4, i_dp_1 => s_dp_1, i_dp_2 => s_dp_2, i_dp_3 => s_dp_3, i_dp_4 => s_dp_4, o_an => o_anodes, o_seg => o_segments );

    process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            s_pb1_prev       <= i_pb1_hit;
            s_pb1_hit_rising <= (not s_pb1_prev) and i_pb1_hit;
            
            s_pb2_prev         <= i_pb2_stand;
            s_pb2_stand_rising <= (not s_pb2_prev) and i_pb2_stand;

            s_pb3_prev         <= i_pb3_double;
            s_pb3_double_rising <= (not s_pb3_prev) and i_pb3_double;
        end if;
    end process;

    process(i_clk_20mhz)
        variable v_rand_draw : integer range 0 to 10;
        variable v_new_score : integer range 0 to 99;
        variable v_new_money : integer range 0 to 8;
    begin
        if rising_edge(i_clk_20mhz) then
            s_uart_tx_dv <= '0';
            case s_fsm_state is
            
                when S_IDLE_DISCONNECTED =>
                    s_player_busted <= '0';
                    s_is_doubled    <= '0';
                    s_has_hit       <= '0';
                    s_money         <= 4;
                    if s_uart_rx_dv = '1' and s_uart_rx_byte = C_CMD_START_GAME then
                        s_fsm_state <= S_CHECK_MONEY;
                    end if;
                    
                when S_CHECK_MONEY =>
                    if s_money = 0 then
                        s_uart_tx_byte <= C_NO_MONEY;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_SEND_NO_MONEY;
                    else
                        s_money        <= s_money - 1;
                        s_uart_tx_byte <= C_ACK_BET;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_SEND_ACK_BET;
                    end if;

                when S_SEND_ACK_BET =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_INIT_DEAL;
                    end if;

                when S_SEND_NO_MONEY =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_IDLE_CONNECTED;
                    end if;

                when S_INIT_DEAL =>
                    s_player_busted <= '0';
                    s_is_doubled    <= '0';
                    s_has_hit       <= '0';
                    s_player_score <= (to_integer(unsigned(s_rand_val(7 downto 0))) mod 20) + 2;
                    s_fsm_state    <= S_WAIT_TURN;
                
                when S_WAIT_TURN =>
                    if s_uart_rx_dv = '1' and s_uart_rx_byte = C_CMD_YOUR_TURN then
                        if s_player_score = 21 then
                            s_delay_timer_cnt <= 0;
                            s_fsm_state       <= S_BLACKJACK_SHOW;
                        else
                            s_fsm_state <= S_PLAYER_TURN;
                        end if;
                    end if;

                when S_BLACKJACK_SHOW =>
                    if s_delay_timer_cnt = C_TIMER_1_SEC - 1 then
                        s_uart_tx_byte <= C_CMD_BLACKJACK;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_BLACKJACK_SEND;
                    else
                        s_delay_timer_cnt <= s_delay_timer_cnt + 1;
                    end if;
                when S_BLACKJACK_SEND =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_WAIT_RESULT;
                    end if;

                when S_PLAYER_TURN =>
                    if s_pb1_hit_rising = '1' then
                        s_fsm_state <= S_PLAYER_HIT;
                    elsif s_pb2_stand_rising = '1' and s_uart_tx_busy = '0' then
                        s_uart_tx_byte <= C_CMD_STAND;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_PLAYER_STAND;
                    elsif s_pb3_double_rising = '1' and s_money > 0 and s_has_hit = '0' then
                        s_money      <= s_money - 1;
                        s_is_doubled <= '1';
                        s_fsm_state  <= S_PLAYER_HIT;
                    end if;

                when S_PLAYER_HIT =>
                    v_rand_draw := draw_weighted_card(s_rand_val);
                    v_new_score := s_player_score + v_rand_draw;
                    s_player_score <= v_new_score;
                    s_has_hit      <= '1';
                    
                    if v_new_score > 21 then
                        s_player_busted   <= '1';
                        s_delay_timer_cnt <= 0;
                        s_fsm_state       <= S_SHOW_BUST_SCORE;
                    elsif s_is_doubled = '1' then
                        s_uart_tx_byte <= C_CMD_STAND;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_PLAYER_STAND;
                    else
                        s_fsm_state <= S_PLAYER_TURN;
                    end if;

                when S_SHOW_BUST_SCORE =>
                    if s_delay_timer_cnt = C_TIMER_1_SEC - 1 then
                        s_uart_tx_byte <= C_CMD_BUST;
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_PLAYER_BUST;
                    else
                        s_delay_timer_cnt <= s_delay_timer_cnt + 1;
                    end if;
                when S_PLAYER_BUST =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_WAIT_RESULT;
                    end if;
                when S_PLAYER_STAND =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_WAIT_STAND_ACK;
                    end if;
                when S_WAIT_STAND_ACK =>
                    if s_uart_rx_dv = '1' and s_uart_rx_byte = C_CMD_ACK_SCORE then
                        s_uart_tx_byte <= std_logic_vector(to_unsigned(s_player_score, 8));
                        s_uart_tx_dv   <= '1';
                        s_fsm_state    <= S_WAIT_SCORE_SENT;
                    end if;
                when S_WAIT_SCORE_SENT =>
                    if s_uart_tx_busy = '0' then
                        s_fsm_state <= S_WAIT_RESULT;
                    end if;
                
                when S_WAIT_RESULT =>
                    if s_uart_rx_dv = '1' then
                        if s_uart_rx_byte = C_CMD_RESULT_WIN then
                            s_result_type <= R_WIN;
                            s_fsm_state   <= S_SHOW_RESULT;
                        elsif s_uart_rx_byte = C_CMD_RESULT_LOSE then
                            s_result_type <= R_LOSE;
                            s_fsm_state   <= S_SHOW_RESULT;
                        elsif s_uart_rx_byte = C_CMD_RESULT_PUSH then
                            s_result_type <= R_PUSH;
                            s_fsm_state   <= S_SHOW_RESULT;
                        elsif s_uart_rx_byte = C_CMD_RESULT_BJ_WIN then
                            s_result_type <= R_BLACKJACK;
                            s_fsm_state   <= S_SHOW_RESULT;
                        end if;
                    end if;

                when S_SHOW_RESULT =>
                    if s_result_timer_cnt = C_TIMER_5_SEC - 1 then
                        s_result_timer_cnt <= 0;
                        
                        v_new_money := s_money;
                        if s_result_type = R_WIN then
                            if s_is_doubled = '1' then
                                v_new_money := s_money + 4;
                            else
                                v_new_money := s_money + 2;
                            end if;
                        elsif s_result_type = R_BLACKJACK then
                            v_new_money := s_money + 3;
                        elsif s_result_type = R_PUSH then
                            if s_is_doubled = '1' then
                                v_new_money := s_money + 2;
                            else
                                v_new_money := s_money + 1;
                            end if;
                        end if;
                        
                        if v_new_money > 8 then
                            s_money <= 8;
                        else
                            s_money <= v_new_money;
                        end if;
                        
                        s_fsm_state <= S_IDLE_CONNECTED;
                    else
                        s_result_timer_cnt <= s_result_timer_cnt + 1;
                    end if;
                    
                when S_IDLE_CONNECTED =>
                    s_player_busted <= '0';
                    s_is_doubled    <= '0';
                    s_has_hit       <= '0';
                    if s_uart_rx_dv = '1' and s_uart_rx_byte = C_CMD_START_GAME then
                        s_fsm_state <= S_CHECK_MONEY;
                    end if;
            end case;
        end if;
    end process;

    process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            s_beep_on <= '0';
            if s_fsm_state = S_PLAYER_TURN then
                if s_beep_timer_cnt = C_TIMER_1_SEC - 1 then
                    s_beep_timer_cnt <= 0;
                else
                    s_beep_timer_cnt <= s_beep_timer_cnt + 1;
                end if;
                if s_beep_timer_cnt < C_TIMER_50_MS then
                    s_beep_on <= '1';
                end if;
                if s_beep_timer_cnt > (C_TIMER_50_MS * 2) and s_beep_timer_cnt < (C_TIMER_50_MS * 3) then
                    s_beep_on <= '1';
                end if;
            else
                s_beep_timer_cnt <= 0;
            end if;
        end if;
    end process;
    o_buzzer <= s_beep_on;

    process(s_fsm_state, s_player_score, s_result_type, s_player_busted, s_money)
        variable v_digit_1 : integer;
        variable v_digit_2 : integer;
    begin
        s_seg_1 <= C_SEG_BLANK;
        s_seg_2 <= C_SEG_BLANK;
        s_seg_3 <= C_SEG_BLANK;
        s_seg_4 <= C_SEG_BLANK;
        s_dp_1  <= '0';
        s_dp_2  <= '0';
        s_dp_3  <= '0';
        s_dp_4  <= '0';

        case s_fsm_state is
            when S_IDLE_DISCONNECTED =>
                s_seg_4 <= C_SEG_d;
                s_seg_3 <= C_SEG_DASH;
                s_seg_2 <= C_SEG_DASH;
                s_seg_1 <= C_SEG_DASH;
            
            when S_IDLE_CONNECTED | S_CHECK_MONEY | S_SEND_ACK_BET | S_SEND_NO_MONEY =>
                if s_money = 0 then
                    s_seg_4 <= C_SEG_BLANK;
                    s_seg_3 <= C_SEG_BLANK;
                    s_seg_2 <= C_SEG_BLANK;
                    s_seg_1 <= C_SEG_0;
                else
                    s_seg_4 <= C_SEG_C;
                    s_seg_3 <= C_SEG_DASH;
                    s_seg_2 <= C_SEG_DASH;
                    s_seg_1 <= C_SEG_DASH;
                end if;

            when S_BLACKJACK_SHOW | S_BLACKJACK_SEND =>
                s_seg_4 <= C_SEG_BLANK;
                s_seg_3 <= C_SEG_BLANK;
                s_seg_2 <= C_SEG_b;
                s_seg_1 <= C_SEG_J;

            when S_PLAYER_BUST | S_WAIT_RESULT =>
                if s_player_busted = '1' then
                    s_seg_4 <= C_SEG_b;
                    s_seg_3 <= C_SEG_U;
                    s_seg_2 <= C_SEG_S;
                    s_seg_1 <= C_SEG_t;
                else
                    v_digit_1 := s_player_score mod 10;
                    v_digit_2 := (s_player_score / 10) mod 10;
                    s_seg_1 <= to_7seg(v_digit_1);
                    s_seg_2 <= to_7seg(v_digit_2);
                    s_dp_1 <= '1';
                end if;

            when S_SHOW_RESULT =>
                case s_result_type is
                    when R_WIN =>
                        s_seg_4 <= C_SEG_BLANK;
                        s_seg_3 <= C_SEG_W;
                        s_seg_2 <= C_SEG_I;
                        s_seg_1 <= C_SEG_n;
                    when R_LOSE =>
                        s_seg_4 <= C_SEG_L;
                        s_seg_3 <= C_SEG_O;
                        s_seg_2 <= C_SEG_S;
                        s_seg_1 <= C_SEG_E;
                    when R_PUSH =>
                        s_seg_4 <= C_SEG_P;
                        s_seg_3 <= C_SEG_U;
                        s_seg_2 <= C_SEG_S;
                        s_seg_1 <= C_SEG_H;
                    when R_BLACKJACK =>
                        s_seg_4 <= C_SEG_BLANK;
                        s_seg_3 <= C_SEG_BLANK;
                        s_seg_2 <= C_SEG_b;
                        s_seg_1 <= C_SEG_J;
                end case;

            when S_INIT_DEAL | S_WAIT_TURN | S_PLAYER_TURN | S_PLAYER_HIT | 
                 S_SHOW_BUST_SCORE |
                 S_PLAYER_STAND | S_WAIT_STAND_ACK | S_WAIT_SCORE_SENT =>
                
                v_digit_1 := s_player_score mod 10;
                v_digit_2 := (s_player_score / 10) mod 10;
                s_seg_1 <= to_7seg(v_digit_1);
                s_seg_2 <= to_7seg(v_digit_2);
                
                if (s_fsm_state = S_PLAYER_STAND or s_fsm_state = S_WAIT_STAND_ACK or s_fsm_state = S_WAIT_SCORE_SENT) then
                   s_dp_1 <= '1';
                end if;

            when others =>
                s_seg_4 <= C_SEG_E;
                s_seg_3 <= C_SEG_t;
                s_seg_2 <= C_SEG_t;
                s_seg_1 <= C_SEG_BLANK;
        
        end case;
    end process;

    process(s_money)
    begin
        o_leds(0) <= '0';
        o_leds(1) <= '0';
        o_leds(2) <= '0';
        o_leds(3) <= '0';
        o_leds(4) <= '0';
        o_leds(5) <= '0';
        o_leds(6) <= '0';
        o_leds(7) <= '0';
        
        if s_money >= 1 then o_leds(0) <= '1'; end if;
        if s_money >= 2 then o_leds(1) <= '1'; end if;
        if s_money >= 3 then o_leds(2) <= '1'; end if;
        if s_money >= 4 then o_leds(3) <= '1'; end if;
        if s_money >= 5 then o_leds(4) <= '1'; end if;
        if s_money >= 6 then o_leds(5) <= '1'; end if;
        if s_money >= 7 then o_leds(6) <= '1'; end if;
        if s_money = 8  then o_leds(7) <= '1'; end if;
    end process;

end architecture rtl;