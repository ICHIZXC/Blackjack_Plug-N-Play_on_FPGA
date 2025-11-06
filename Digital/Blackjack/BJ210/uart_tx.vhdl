library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_TX is
    generic (
        G_CLK_FREQUENCY : integer := 20_000_000;
        G_BAUD_RATE     : integer := 9600
    );
    port (
        i_clk     : in  std_logic;
        i_tx_byte : in  std_logic_vector(7 downto 0);
        i_tx_dv   : in  std_logic;
        o_tx_pin  : out std_logic := '1';
        o_tx_busy : out std_logic := '0'
    );
end entity UART_TX;

architecture rtl of UART_TX is
    constant C_CLK_DIV : integer := G_CLK_FREQUENCY / G_BAUD_RATE;
    type t_tx_state is (s_idle, s_start_bit, s_tx_data_bits, s_stop_bit);
    signal r_tx_state : t_tx_state := s_idle;
    signal r_clk_counter : integer range 0 to C_CLK_DIV - 1 := 0;
    signal r_bit_index   : integer range 0 to 7 := 0;
    signal r_tx_byte     : std_logic_vector(7 downto 0) := (others => '0');
    signal r_tx_busy     : std_logic := '0';

begin

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            case r_tx_state is
                
                when s_idle =>
                    r_tx_busy     <= '0';
                    o_tx_pin      <= '1';
                    r_clk_counter <= 0;
                    r_bit_index   <= 0;
                    
                    if i_tx_dv = '1' then
                        r_tx_byte  <= i_tx_byte;
                        r_tx_busy  <= '1';
                        o_tx_pin   <= '0';
                        r_tx_state <= s_start_bit;
                    end if;

                when s_start_bit =>
                    if r_clk_counter = C_CLK_DIV - 1 then
                        r_clk_counter <= 0;
                        r_tx_state    <= s_tx_data_bits;
                    else
                        r_clk_counter <= r_clk_counter + 1;
                    end if;

                when s_tx_data_bits =>
                    if r_clk_counter = C_CLK_DIV - 1 then
                        r_clk_counter <= 0;
                        o_tx_pin      <= r_tx_byte(r_bit_index);
                        
                        if r_bit_index = 7 then
                            r_bit_index <= 0;
                            r_tx_state  <= s_stop_bit;
                        else
                            r_bit_index <= r_bit_index + 1;
                        end if;
                    else
                        r_clk_counter <= r_clk_counter + 1;
                    end if;
                
                when s_stop_bit =>
                    if r_clk_counter = C_CLK_DIV - 1 then
                        r_clk_counter <= 0;
                        o_tx_pin      <= '1';
                        r_tx_state    <= s_idle;
                    else
                        o_tx_pin <= '1';
                        r_clk_counter <= r_clk_counter + 1;
                    end if;

            end case;
        end if;
    end process;
    
    o_tx_busy <= r_tx_busy;

end architecture rtl;