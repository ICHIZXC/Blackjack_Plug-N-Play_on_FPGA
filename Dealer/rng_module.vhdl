library ieee;
use ieee.std_logic_1164.all;

entity RNG_Module is
    port (
        i_clk       : in  std_logic;
        i_enable    : in  std_logic;
        o_rand_val  : out std_logic_vector(15 downto 0)
    );
end entity RNG_Module;

architecture rtl of RNG_Module is
    signal r_lfsr : std_logic_vector(15 downto 0) := x"ACE1"; 
    
begin

    process(i_clk)
        variable v_feedback : std_logic;
    begin
        if rising_edge(i_clk) then
            if i_enable = '1' then
                v_feedback := r_lfsr(15) xor r_lfsr(14) xor r_lfsr(12) xor r_lfsr(3);
                r_lfsr <= r_lfsr(14 downto 0) & v_feedback;
            end if;
        end if;
    end process;
    
    o_rand_val <= r_lfsr;

end architecture rtl;