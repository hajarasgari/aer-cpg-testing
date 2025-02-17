library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity EventsSequencer is
    generic (
        OUT_DATA_WIDTH : integer := 20;
        BUFFER_DEPTH : integer := 2048
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        tsEvent_DI : in std_logic_vector(31 + OUT_DATA_WIDTH downto 0);
        canAcceptBlock_SO : out std_logic;
        currentTime_DI : in unsigned(31 downto 0);
        write_SI : in std_logic;
        numEventsFree_DO : out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        AER_DO : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
        AERAck_SI : in std_logic;
        AERReq_SO : out std_logic
        );
end EventsSequencer;

architecture behavioural of EventsSequencer is
    type state_type is (idle, wait_until_timestamp, apply_data, req, ack);
    signal state_SP, state_SN : state_type;

    signal fifoOut_D : std_logic_vector(31 + OUT_DATA_WIDTH downto 0);
    signal fifoReadEn_S : std_logic;
    signal fifoEmpty_S : std_logic;
    signal outputReg_DN, outputReg_DP : std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
    signal nextTsReg_DN, nextTsReg_DP : unsigned(31 downto 0);
    signal waitCount_DN, waitCount_DP : unsigned(9 downto 0);
    signal outPutRegEn_S : std_logic;
    signal nextTsRegEn_S : std_logic;
    signal reset_R : std_logic;



    signal canAcceptBlock_SB : std_logic;

begin

    canAcceptBlock_SO <= not canAcceptBlock_SB;

    reset_R <= not reset_RBI;

    process(all)
    begin
        AER_DO <= outputReg_DP(OUT_DATA_WIDTH-1 downto 0);
        AERReq_SO <= '0';
        outputReg_DN <= fifoOut_D(31 + OUT_DATA_WIDTH downto 32);
        nextTsReg_DN <= unsigned(fifoOut_D(31 downto 0));
        outputRegEn_S <= '0';
        nextTsRegEn_S <= '0';
        fifoReadEn_S <= '0';
        waitCount_DN <= (others => '0');
        state_SN <= state_SP;

        case state_SP is
            when idle =>
                if fifoEmpty_S = '0' then
                    fifoReadEn_S <= '1';
                    outputRegEn_S <= '1';
                    nextTsRegEn_S <= '1';
                    state_SN <= wait_until_timestamp;
                end if;
            when wait_until_timestamp =>
                if currentTime_DI > nextTsReg_DP then
                    state_SN <= apply_data;
                end if;
            when apply_data =>
                waitCount_DN <= waitCount_DP + 1;
                if waitCount_DP = to_unsigned(10, 10) then
                    state_SN <= req;
                end if;
            when req =>
                AERReq_SO <= '1';
                if AERAck_SI = '1' then
                    state_SN <= ack;
                end if;
            when ack =>
                if AERAck_SI = '0' then
                    state_SN <= idle;
                end if;
        end case;

    end process;

    fifo : entity work.CustomFifo
        generic map(
            FIFO_DEPTH => BUFFER_DEPTH,
            FIFO_WIDTH => 32 + OUT_DATA_WIDTH,
            ALMOST_FULL_OFFSET => 126,
            ALMOST_EMPTY_OFFSET => 0
            )
        port map(
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            in_DI => tsEvent_DI,
            wEn_SI => write_SI,
            out_DO => fifoOut_D,
            rEn_SI => fifoReadEn_S,
            empty_SO => fifoEmpty_S,
            full_SO => canAcceptBlock_SB,
            almostFull_SO => open,
            almostEmpty_SO => open,
            numEntriesFree_DO => numEventsFree_DO
            );
            
    regs : process(clk_CI, reset_RBI)
    begin
        if rising_edge(clk_CI) then
            if reset_RBI = '0' then
                outputReg_DP <= (others => '0');
                nextTsReg_DP <= (others => '0');
                waitCount_DP <= (others => '0');
                state_SP <= idle;
            else 
                if outputRegEn_S = '1' then
                    outputReg_DP <= outputReg_DN;
                end if;

                if nextTsRegEn_S = '1' then
                    nextTsReg_DP <= nextTsReg_DN;
                end if;

                state_SP <= state_SN;
                waitCount_DP <= waitCount_DN;
            end if;
        end if;
    end process;
end behavioural;