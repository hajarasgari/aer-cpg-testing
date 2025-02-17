library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity CustomFifo is
    generic (
        -- Note that actual size of FIFO is FIFO_DEPTH - 1
        FIFO_DEPTH : integer := 2048;
        FIFO_WIDTH : integer := 32;
        -- It asserts when FIFO has this number of free spaces or less
        -- If 0 it corresponds to FULL
        ALMOST_FULL_OFFSET : integer := 0;
        -- It asserts when FIFO contains more than this number of words 
        -- If 0 it corresponds to EMPTY
        ALMOST_EMPTY_OFFSET : integer := 0
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        in_DI : in std_logic_vector(FIFO_WIDTH - 1 downto 0);
        wEn_SI : in std_logic;
        out_DO : out std_logic_vector(FIFO_WIDTH - 1 downto 0);
        rEn_SI : in std_logic;
        empty_SO : out std_logic;
        full_SO : out std_logic;
        almostFull_SO : out std_logic;
        almostEmpty_SO : out std_logic;
        numEntriesFree_DO : out std_logic_vector(integer(ceil(log2(real(FIFO_DEPTH)))) - 1 downto 0)
        );
end CustomFifo;

architecture behavioural of CustomFifo is
    type buf_type is array (FIFO_DEPTH - 1 downto 0) of std_logic_vector(FIFO_WIDTH - 1 downto 0);
    signal buf_D : buf_type := (others => (others => '0'));

    signal headPtr_DN, headPtr_DP : unsigned(integer(ceil(log2(real(buf_D'length)))) - 1 downto 0);
    signal tailPtr_DN, tailPtr_DP : unsigned(integer(ceil(log2(real(buf_D'length)))) - 1 downto 0);

    signal fifoReadAddr_D : unsigned(headPtr_DP'range);

    signal fifoLevel_DN, fifoLevel_DP : unsigned(integer(ceil(log2(real(buf_D'length)))) - 1 downto 0);
    signal numEntriesFree_DN, numEntriesFree_DP : unsigned(integer(ceil(log2(real(buf_D'length)))) - 1 downto 0);
    
begin

    numEntriesFree_DO <= std_logic_vector(numEntriesFree_DP);

    comb : process(all)
    begin
        headPtr_DN <= headPtr_DP + 1;
        tailPtr_DN <= tailPtr_DP + 1;
        fifoLevel_DN <= fifoLevel_DP;
        numEntriesFree_DN <= (FIFO_DEPTH - 1) - fifoLevel_DN;
        almostFull_SO <= '0';
        almostEmpty_SO <= '0';

        if rEn_SI = '1' then
            fifoReadAddr_D <= tailPtr_DN;
        else
            fifoReadAddr_D <= tailPtr_DP;
        end if;

        if wEn_SI = '0' and rEn_SI = '1' then
            fifoLevel_DN <= fifoLevel_DP - 1;
        elsif wEn_SI = '1' and rEn_SI = '0' then
            fifoLevel_DN <= fifoLevel_DP + 1;
        end if;

        if to_unsigned(FIFO_DEPTH-1, fifoLevel_DP'length + 1) - fifoLevel_DP <= to_unsigned(ALMOST_FULL_OFFSET,
                                                                                      fifoLevel_DP'length + 1)
        then
            almostFull_SO <= '1';
        end if;

        if fifoLevel_DP <= to_unsigned(ALMOST_EMPTY_OFFSET, fifoLevel_DP'length) then
            almostEmpty_SO <= '1';
        end if;

        empty_SO <= '0';
        full_SO <= '0';

        if headPtr_DN = tailPtr_DP then
            full_SO <= '1';
        end if;

        if tailPtr_DP = headPtr_DP then
            empty_SO <= '1';
        end if;
    end process;

    registers : process(clk_CI, reset_RBI)
    begin
        if rising_edge(clk_CI) then
            if reset_RBI = '0' then
                headPtr_DP <= (others => '0');
                tailPtr_DP <= (others => '0');
                numEntriesFree_DP <= to_unsigned(FIFO_DEPTH - 1, numEntriesFree_DP'length);
                fifoLevel_DP <= (others => '0');
            else 
                if wEn_SI = '1' then
                    headPtr_DP <= headPtr_DN;
                end if;

                if rEn_SI = '1' then
                    tailPtr_DP <= tailPtr_DN;
                end if;

                numEntriesFree_DP <= numEntriesFree_DN;
                fifoLevel_DP <= fifoLevel_DN;
            end if;
        end if;
    end process;

    ram : entity work.InferredBlockRam
        generic map (
            DEPTH => FIFO_DEPTH,
            WIDTH => FIFO_WIDTH
            )
        port map (
            clk_CI => clk_CI,
            wEn_SI => wEn_SI,
            writeAddr_DI => std_logic_vector(headPtr_DP),
            readAddr_DI => std_logic_vector(fifoReadAddr_D),
            data_DI => in_DI,
            writeAddrData_DO => open,
            readAddrData_DO => out_DO
            );
end behavioural;