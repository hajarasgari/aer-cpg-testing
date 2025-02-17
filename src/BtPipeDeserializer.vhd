library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity BtPipeDeserializer is
    generic (
        CHAIN_OUT_DATA_WIDTH : integer := 20
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        pipeIn_DI : in std_logic_vector(31 downto 0);
        blockStrobe_SI : in std_logic;
        write_SI : in std_logic;
        read_SI : in std_logic;
        ready_SO : out std_logic;
        outWord_DO : out std_logic_vector(31+CHAIN_OUT_DATA_WIDTH downto 0)
        );
end BtPipeDeserializer;

architecture behavioural of BtPipeDeserializer is
    type state_type is (idle, shift, accept_remaining);
    signal state_SP, state_SN : state_type;

    signal wordCount_DN, wordCount_DP : unsigned(7 downto 0);
    signal wordCountEn_S : std_logic;
    signal targetCount_DN, targetCount_DP : unsigned(7 downto 0);

    -- timestamp and data FIFo signals
    signal tsFifoOut_D, dataFifoOut_D : std_logic_vector(31 downto 0);
    signal tsFifoEmpty_S, tsFifoWrite_SI : std_logic;
    signal dataFifoEmpty_S, dataFifoWrite_SI : std_logic;

    signal fifoEnablesState_D : std_logic_vector(1 downto 0);
begin

    -- Hardwired connections
    tsFifoWrite_SI <= fifoEnablesState_D(1);
    dataFifoWrite_SI <= fifoEnablesState_D(0);

    stateProcess: process(all)
    begin
        -- Default state updates
        targetCount_DN <= targetCount_DP;
        state_SN <= state_SP;
        wordCount_DN <= wordCount_DP + 1;

        -- Default output values of FSM if not specified by the state differently
        wordCountEn_S <= '0';
        ready_SO <= '0';
        fifoEnablesState_D <= (others => '0');

        -- Merge FIFO outputs together to general OUT
        outWord_DO(31+CHAIN_OUT_DATA_WIDTH downto 32) <= dataFifoOut_D(CHAIN_OUT_DATA_WIDTH-1 downto 0);
        outWord_DO(31 downto 0) <= tsFifoOut_D;

        -- Decide if to write or not FIFO values
        if tsFifoEmpty_S = '0' and dataFifoEmpty_S = '0' then
            ready_SO <= '1';
        end if;

        -- FSM
        case state_SP is
            when idle =>
                if write_SI = '1' then
                    targetCount_DN <= unsigned(pipeIn_DI(7 downto 0));--number of whole events max 2^8=256
                    wordCountEn_S <= '1';
                    state_SN <= shift;
                end if;
            when shift =>
                if write_SI = '1' then
                    -- Odd words (1, 3,...) are timestamps -> enable fifo 1
                    -- Even words (2, 4, ...) are data -> enable fifo 0
                    fifoEnablesState_D(TO_INTEGER(wordCount_DP) mod 2) <= '1'; -- mod( a , m ) returns the remainder after division of a by m , 
                    if wordCount_DP = 255 then
                        state_SN <= idle;
                        wordCount_DN <= (others => '0');
                        wordCountEn_S <= '1';
                    elsif wordCount_DP = targetCount_DP then
                        state_SN <= accept_remaining;
                        wordCountEn_S <= '1';
                    else
                        wordCountEn_S <= '1';
                    end if;
                end if;
            when accept_remaining =>
                if write_SI = '1' then
                    wordCountEn_S <= '1';
                    if wordCount_DP = 255 then
                        state_SN <= idle;
                        wordCount_DN <= (others => '0');
                        wordCountEn_S <= '1';
                    end if;
                end if;
        end case;
    end process;

    regs : process(clk_CI, reset_RBI)
    begin
        if rising_edge(clk_CI) then
            if reset_RBI = '0' then
                wordCount_DP <= (others => '0');
                targetCount_DP <= (others => '0');
                state_SP <= idle;
            else
                targetCount_DP <= targetCount_DN;
                state_SP <= state_SN;
                if wordCountEn_S = '1' then
                    wordCount_DP <= wordCount_DN;
                end if;
            end if;
        end if;
    end process;

    fifoTs : entity work.CustomFifo
        generic map (
            FIFO_DEPTH => 4,
            FIFO_WIDTH => 32
            )
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            in_DI => pipeIn_DI,
            wEn_SI => tsFifoWrite_SI,
            out_DO => tsFifoOut_D,
            rEn_SI => read_SI,
            empty_SO => tsFifoEmpty_S,
            full_SO => open,
            almostFull_SO => open,
            almostEmpty_SO => open,
            numEntriesFree_DO => open
            );

    fifoData : entity work.CustomFifo
        generic map (
            FIFO_DEPTH => 4,
            FIFO_WIDTH => 32
            )
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            in_DI => pipeIn_DI,
            wEn_SI => dataFifoWrite_SI,
            out_DO => dataFifoOut_D,
            rEn_SI => read_SI,
            empty_SO => dataFifoEmpty_S,
            full_SO => open,
            almostFull_SO => open,
            almostEmpty_SO => open,
            numEntriesFree_DO => open
            );
end behavioural;
