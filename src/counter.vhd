library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity counter is 
    port(clk, reset : in  std_logic;
         Q1 : out std_logic_vector(31 downto 0));
end counter;

architecture archi of counter is 

    constant WIDTH_COUNT   : positive range 2 to positive'right := 100; 
    signal   r_reg         : unsigned(31 downto 0);
    signal   r_next        : unsigned(31 downto 0);
    signal   count_reg     : unsigned(11 downto 0);
    signal   count_next    : unsigned(11 downto 0);
    signal   Q             : unsigned(31 downto 0);
    

begin

    process(clk, reset)
    begin
        if(reset = '0') then
            count_reg <= (others=>'0');
            r_reg     <= (others=>'0');            
        elsif(clk'event and clk = '1') then            
                if( count_reg <=  WIDTH_COUNT) then                      
                      count_reg   <=   count_next;
                else                       
                      count_reg   <= (others=>'0');
                      r_reg       <= r_next;
                end if;
        end if;
    end process;

    count_next   <=  count_reg + 1;
    r_next       <=  r_reg + 1;
    Q            <=  r_reg;
    Q1           <=  std_logic_vector (Q);
    
end archi;