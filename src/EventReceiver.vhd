library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity EventReceiver is
    generic (
        IN_DATA_WIDTH : integer := 24;
        BUFFER_DEPTH : integer := 2048
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        AER_DI : in std_logic_vector(IN_DATA_WIDTH-1 downto 0);
        AERReq_SI : in std_logic;
        AERAck_SO : out std_logic;
        data_DO : out std_logic_vector(31 downto 0);
        currentTime_DI : in unsigned(31 downto 0);
        numEventsHeld_DO : out unsigned(10 downto 0);
        fifoFull_S : out std_logic;
        numEventsFree_DO : out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        readEn_SI : in std_logic
        );
end EventReceiver;

architecture behavioural of EventReceiver is
    type state_type is (idle, wait_and_store, acknowledge, remove_ack_wait, store_timestamp);
    signal state_SN, state_SP : state_type;
    signal numWords_DN, numWords_DP : unsigned(11 downto 0);
    signal numEventsEn_S : std_logic;
    signal reset_R : std_logic;
    --signal fifoFull_S : std_logic;
    signal fifoWrite_S : std_logic;
    signal fifoIn_D : std_logic_vector(31 downto 0);
    signal waitCount_DN, waitCount_DP : unsigned(9 downto 0);
begin

    reset_R <= not reset_RBI;

    -- We need a specific process that counts the number of events present
    -- inside the FIFO, needed in the header of every output packet
    nextNumEvents : process(all)
    begin
        numWords_DN <= numWords_DP;
        if fifoWrite_S = '1' and readEn_SI = '0' then
            numWords_DN <= numWords_DP + 1;
        elsif fifoWrite_S = '0' and readEn_SI = '1' then
            numWords_DN <= numWords_DP - 1;
        end if;
    end process;

    stateProc : process(all)
    begin
        state_SN <= state_SP;
        fifoWrite_S <= '0';
        fifoIn_D <= (others => '0');
        fifoIn_D(IN_DATA_WIDTH-1 downto 0) <= AER_DI;
        numEventsHeld_DO <= numWords_DP(11 downto 1);
        waitCount_DN <= (others => '0');
        AERAck_SO <= '0';

        case state_SP is
            when idle =>
                if AERReq_SI = '1' and fifoFull_S = '0' then
                    state_SN <= wait_and_store;
                end if;
            when wait_and_store =>
                waitCount_DN <= waitCount_DP + 1;
                if waitCount_DP > 100 then
                    fifoWrite_S <= '1';
                    state_SN <= acknowledge;
                end if;
            when acknowledge =>
                AERAck_SO <= '1';
                if AERReq_SI = '0' then
                    state_SN <= remove_ack_wait;
                end if;
            when remove_ack_wait =>
                AERAck_SO <= '1';
                waitCount_DN <= waitCount_DP + 1;
                if waitCount_DP > 100 then
                    state_SN <= store_timestamp;
                end if;
            when store_timestamp =>
                fifoIn_D <= std_logic_vector(currentTime_DI);
                fifoWrite_S <= '1';
                state_SN <= idle;
                null;
        end case;
    end process;

    fifo : entity work.CustomFifo
        generic map(
            FIFO_DEPTH => BUFFER_DEPTH,
            FIFO_WIDTH => 32,
            ALMOST_FULL_OFFSET => 2,
            ALMOST_EMPTY_OFFSET => 0
            )
        port map(
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            in_DI => fifoIn_D,
            wEn_SI => fifoWrite_S,
            out_DO => data_DO,
            rEn_SI => readEn_SI,
            empty_SO => open,
            full_SO => open,
            almostFull_SO => fifoFull_S,
            almostEmpty_SO => open,
            numEntriesFree_DO => numEventsFree_DO
            );

    registers : process(clk_CI, reset_RBI)
    begin
        if rising_edge(clk_CI) then
            if reset_RBI = '0' then
                state_SP <= idle;
                numWords_DP <= (others => '0');
                waitCount_DP <= (others => '0');
            else
                state_SP <= state_SN;
                numWords_DP <= numWords_DN;
                waitCount_DP <= waitCount_DN;
            end if;
        end if;
    end process;
end behavioural;
