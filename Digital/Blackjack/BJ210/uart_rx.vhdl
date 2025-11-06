library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 20000000;
        BAUD_RATE : integer := 9600
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        i_rx_serial   : in  std_logic;
        o_rx_dv       : out std_logic;
        o_data        : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of uart_rx is
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    constant HALF_BIT     : integer := CLKS_PER_BIT / 2;
    type state_t is (S_IDLE, S_START_BIT, S_DATA_BITS, S_STOP_BIT, S_CLEANUP);
    signal r_state : state_t := S_IDLE;
    signal r_clk_counter : integer range 0 to CLKS_PER_BIT := 0;
    signal r_bit_counter : integer range 0 to 7 := 0;
    signal r_rx_buffer   : std_logic_vector(7 downto 0) := (others => '0');
    signal r_rx_dv       : std_logic := '0';
    signal r_data_out    : std_logic_vector(7 downto 0) := (others => '0');

begin
    o_rx_dv <= r_rx_dv;
    o_data  <= r_data_out;
    process(clk, reset)
    begin
        if reset = '0' then
            r_state       <= S_IDLE;
            r_clk_counter <= 0;
            r_bit_counter <= 0;
            r_rx_dv       <= '0';
        elsif rising_edge(clk) then
            r_rx_dv <= '0';

            case r_state is
                when S_IDLE =>
                    r_clk_counter <= 0;
                    r_bit_counter <= 0;
                    if i_rx_serial = '0' then
                        r_state <= S_START_BIT;
                    end if;
                    
                when S_START_BIT =>
                    if r_clk_counter = HALF_BIT then
                        if i_rx_serial = '0' then
                            r_clk_counter <= 0;
                            r_state       <= S_DATA_BITS;
                        else
                            r_state <= S_IDLE;
                        end if;
                    else
                        r_clk_counter <= r_clk_counter + 1;
                    end if;
                    
                when S_DATA_BITS =>
                    if r_clk_counter < CLKS_PER_BIT - 1 then
                        r_clk_counter <= r_clk_counter + 1;
                    else
                        r_clk_counter <= 0;
                        r_rx_buffer(r_bit_counter) <= i_rx_serial;
                        
                        if r_bit_counter = 7 then
                            r_state       <= S_STOP_BIT;
                            r_bit_counter <= 0;
                        else
                            r_bit_counter <= r_bit_counter + 1;
                        end if;
                    end if;
                    
                when S_STOP_BIT =>
                    if r_clk_counter < CLKS_PER_BIT - 1 then
                        r_clk_counter <= r_clk_counter + 1;
                    else
                        r_clk_counter <= 0;
                        r_state       <= S_CLEANUP;
                        r_data_out <= r_rx_buffer;
                        r_rx_dv    <= '1';
                    end if;

                when S_CLEANUP =>
                    r_state <= S_IDLE;
            end case;
        end if;
    end process;

end architecture;