---- Dual-Port RAM with Synchronous Read (Read Through)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity InferredBlockRam is
    generic (
        DEPTH : integer := 2048;
        WIDTH : integer := 32
        );
    port (
        clk_CI           : in std_logic;
        wEn_SI           : in std_logic;
        writeAddr_DI     : in std_logic_vector(integer(ceil(log2(real(DEPTH)))) - 1 downto 0);
        readAddr_DI      : in std_logic_vector(integer(ceil(log2(real(DEPTH)))) - 1 downto 0);
        data_DI          : in std_logic_vector(WIDTH - 1 downto 0);
        writeAddrData_DO : out std_logic_vector(WIDTH - 1 downto 0);
        readAddrData_DO  : out std_logic_vector(WIDTH - 1 downto 0)
        );
end InferredBlockRam;

architecture syn of InferredBlockRam is
    type ram_type is array (DEPTH-1 downto 0) of std_logic_vector (WIDTH-1 downto 0);
    signal RAM : ram_type  := (others => (others => '0'));
    signal read_a : std_logic_vector(integer(ceil(log2(real(RAM'length)))) - 1 downto 0) := (others => '0');
    signal read_dpra : std_logic_vector(integer(ceil(log2(real(RAM'length)))) - 1 downto 0) := (others => '0');
begin

    process (clk_CI)
    begin
        if (clk_CI'event and clk_CI = '1') then
            if (wEn_SI = '1') then
                RAM(to_integer(unsigned(writeAddr_DI))) <= data_DI;
            end if;
            read_a <= writeAddr_DI;
            read_dpra <= readAddr_DI;
        end if;
    end process;
    writeAddrData_DO <= RAM(to_integer(unsigned(read_a)));
    readAddrData_DO <= RAM(to_integer(unsigned(read_dpra)));

end syn;
