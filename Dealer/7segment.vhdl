library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Seven_Segment_Driver is
    port (
        i_clk     : in  std_logic;
        i_seg_1   : in  std_logic_vector(6 downto 0);
        i_seg_2   : in  std_logic_vector(6 downto 0);
        i_seg_3   : in  std_logic_vector(6 downto 0);
        i_seg_4   : in  std_logic_vector(6 downto 0);
        i_dp_1    : in  std_logic := '0';
        i_dp_2    : in  std_logic := '0';
        i_dp_3    : in  std_logic := '0';
        i_dp_4    : in  std_logic := '0';
        o_an      : out std_logic_vector(3 downto 0);
        o_seg     : out std_logic_vector(7 downto 0)
    );
end entity Seven_Segment_Driver;

architecture rtl of Seven_Segment_Driver is
    constant C_REFRESH_MAX : integer := 19999;
    signal r_refresh_cnt : integer range 0 to C_REFRESH_MAX := 0;
    signal r_digit_sel : std_logic_vector(1 downto 0) := "00";
    signal w_seg_in  : std_logic_vector(6 downto 0);
    signal w_dp_in   : std_logic;

begin

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_refresh_cnt = C_REFRESH_MAX then
                r_refresh_cnt <= 0;
                r_digit_sel   <= std_logic_vector(unsigned(r_digit_sel) + 1);
            else
                r_refresh_cnt <= r_refresh_cnt + 1;
            end if;
        end if;
    end process;

    process(r_digit_sel, i_seg_1, i_seg_2, i_seg_3, i_seg_4, i_dp_1, i_dp_2, i_dp_3, i_dp_4)
    begin
        case r_digit_sel is
            when "00" =>
                o_an     <= "1110";
                w_seg_in <= i_seg_1;
                w_dp_in  <= i_dp_1;
            when "01" =>
                o_an     <= "1101";
                w_seg_in <= i_seg_2;
                w_dp_in  <= i_dp_2;
            when "10" =>
                o_an     <= "1011";
                w_seg_in <= i_seg_3;
                w_dp_in  <= i_dp_3;
            when others =>
                o_an     <= "0111";
                w_seg_in <= i_seg_4;
                w_dp_in  <= i_dp_4;
        end case;
    end process;

    o_seg(6 downto 0) <= w_seg_in;
    o_seg(7) <= '1' when w_dp_in = '1' else '0';

end architecture rtl;