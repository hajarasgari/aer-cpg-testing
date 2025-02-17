library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BtPipeSerializer is
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        pipeOut_DO : out std_logic_vector(31 downto 0);
        eventData_DI : in std_logic_vector(31 downto 0);
        blockStrobe_SI : in std_logic;
        numEventsReady_DI : in unsigned(10 downto 0);
        readOut_SI : in std_logic;
        readIn_SO : out std_logic;
        ready_SO : out std_logic
        );
end BtPipeSerializer;

architecture behavioural of BtPipeSerializer is
    type state_type is (idle, present_num_words, read_out,wait_for_readout, backfill, wait_for_backfill);
    signal state_SN, state_SP : state_type;

    signal wordsSent_DN, wordsSent_DP : unsigned(11 downto 0);
    signal wordsToRead_DN, wordsToRead_DP : unsigned(11 downto 0);
    signal wordsToReadEn_S : std_logic;
    signal inputData_DN, inputData_DP : std_logic_vector(31 downto 0);
begin

    process(all)
    begin
        pipeOut_DO <= (others => '0');
        pipeOut_DO(11 downto 0) <= std_logic_vector(wordsToRead_DP);
        readIn_SO <= '0';
        wordsSent_DN <= (others => '0');
        wordsToReadEn_S <= '0';
        state_SN <= state_SP;
        inputData_DN <= eventData_DI;

        -- We need to continuously tell to the host that we have events to send
        -- in order to avoid stucking events in the pipe. Note that we may send
        -- empty packets if no events are available from the chip
        ready_SO <= '1';
        -- Packet is 1024 bytes wide. Every word is 4 bytes -> 256
        -- words max. Every event is 2 words -> 128 events max - 1 event used
        -- as words counter = 127 events max in a packet
        if numEventsReady_DI < 128 then
            -- Multiply by 2
            wordsToRead_DN <= numEventsReady_DI & "0";
        else
            wordsToRead_DN <= to_unsigned(254, 12);
        end if;

        case state_SP is
            when idle =>
                if readOut_SI = '1' then
                    wordsToReadEn_S <= '1';
                    state_SN <= present_num_words;
                end if;
            -- We need this state to send the number of words which will be
            -- inside the packet
            when present_num_words =>
                -- We need it because wordsToRead_DP as 1 cycle delay
                wordsToRead_DN <= wordsToRead_DP - 1;
                -- prevent underflow
                if wordsToRead_DP /= 0 then
                    wordsToReadEn_S <= '1';
                    if readOut_SI = '1' then
                        state_SN <= read_out;
                        readIn_SO <= '1';
                    else
                        state_SN <= wait_for_readout;
                    end if;
                else
                    if readOut_SI = '1' then
                        -- go directly to backfill since we have no events to read
                    state_SN <= backfill;
                    else
                        state_SN <= wait_for_backfill;
                    end if;
                end if;

            -- We need this state to fill the packet with events
            when read_out =>
                wordsToReadEn_S <= '1';
                wordsSent_DN <= wordsSent_DP + 1;
                wordsToRead_DN <= wordsToRead_DP - 1;
                pipeOut_DO <= inputData_DP;

                if readOut_SI = '1' then
                    if wordsToRead_DP = 0 then
                        state_SN <= backfill;
                    else
                        readIn_SO <= '1';
                    end if;
                elsif wordsToRead_DP = 0 then
                    state_SN <= wait_for_backfill;
                else
                    state_SN <= wait_for_readout;
                end if;

                if wordsSent_DP = 254 then
                    state_SN <= idle;
                end if;

            -- We need this state to face the problem of opalKelly deasserting
            -- readOut_SI while we are reading out the fifo.
            when wait_for_readout =>
                wordsSent_DN <= wordsSent_DP;
                if readOut_SI = '1' then
                    state_SN <= read_out;
                    readIn_SO <= '1';
                end if;

            -- We need this state to fill the remaining packet slot with empty
            -- events. Remember that we always need to send 1024 bytes
            when backfill =>
                wordsSent_DN <= wordsSent_DP + 1;
                pipeOut_DO <= (others => '0');

                if wordsSent_DP = 254 then
                    state_SN <= idle;
                elsif readOut_SI = '0' then
                    state_SN <= wait_for_backfill;
                end if;

            -- We need this state to face the problem of opalKelly deasserting
            -- readOut_SI while we are backfilling the packet with zeros.

            when wait_for_backfill =>
                wordsSent_DN <= wordsSent_DP;
                if readOut_SI = '1' then
                    state_SN <= backfill;
                end if;
        end case;
    end process;

    process(clk_CI, reset_RBI)
    begin
        if rising_edge(clk_CI) then
            if reset_RBI = '0' then
                state_SP <= idle;
                wordsSent_DP <= (others => '0');
                wordsToRead_DP <= (others => '0');
                inputData_DP <= (others => '0');
            else
                state_SP <= state_SN;
                wordsSent_DP <= wordsSent_DN;
                if wordsToReadEn_S = '1' then
                    wordsToRead_DP <= wordsToRead_DN;
                end if;
                inputData_DP <= inputData_DN;
            end if;
        end if;
    end process;
end behavioural;
