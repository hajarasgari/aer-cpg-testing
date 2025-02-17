library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity Reset_Controller is
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        Prst_RBO : out std_logic;
        Srst_RBO : out std_logic;
        counterTime : in  std_logic_vector(31 downto 0);
        piperst_RBO : out std_logic
        );
end Reset_Controller;

architecture Behavioral of Reset_Controller is
constant DELAY_PRst   : integer := 10000;
constant DELAY_SRst   : integer := 10000;
signal Prst :  std_logic;
signal Srst :  std_logic;
signal piperst :  std_logic;
signal   count_reg    : unsigned(31 downto 0);

begin
count_reg  <= unsigned (counterTime);
    process(clk_CI, reset_RBI)
    begin
        if(reset_RBI = '0') then
            Prst  <= '0';
            Srst  <= '0';   
            piperst <= '0';         
         elsif(clk_CI'event and clk_CI = '1') then 
                if( count_reg <=  DELAY_PRst) then                      
                        Prst  <= '0';
                        Srst  <= '0';   
                        piperst <= '0';
                else                       
                      if( count_reg <=  DELAY_SRst) then                      
                                Prst  <= '1';
                                Srst  <= '0';   
                                piperst <= '0';
                      else                       
                                if( count_reg <=  DELAY_SRst) then                      
                                            Prst  <= '1';
                                            Srst  <= '1';   
                                            piperst <= '0';
                                else                       
                                            Prst  <= '1';
                                            Srst  <= '1';   
                                            piperst <= '1';
                                end if;
                      end if;
                end if;
                
        end if;
       
    end process;

Prst_RBO  <= Prst;
Srst_RBO  <= Srst;   
piperst_RBO <= piperst;

end Behavioral;
