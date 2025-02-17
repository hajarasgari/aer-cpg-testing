library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity InputEventsChain is
    generic (
        CHAIN_OUT_DATA_WIDTH : integer := 20;
        BUFFER_DEPTH : integer := 2048
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        pipeIn_DI : in std_logic_vector(31 downto 0);
        blockStrobe_SI : in std_logic;
        write_SI : in std_logic;
        canAcceptBlock_SO : out std_logic;
        currentTime_DI1 : in std_logic_vector(31 downto 0);
        AER_DO : out std_logic_vector(CHAIN_OUT_DATA_WIDTH-1 downto 0);
        numEventsFree_DO : out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        AERAck_SI : in std_logic;
        AERReq_SO : out std_logic
        );
end InputEventsChain;

architecture structural of InputEventsChain is
    signal BtPipeReady_S : std_logic;
    signal BtPipeOut_DO : std_logic_vector(31 + CHAIN_OUT_DATA_WIDTH downto 0);
    signal seqReadIn_S : std_logic;
    signal currentTime_DI : unsigned (31 downto 0);

begin
    currentTime_DI <=  unsigned (currentTime_DI1);
    seqReadIn_S <= BtPipeReady_S;

    des : entity work.BtPipeDeserializer
        generic map(CHAIN_OUT_DATA_WIDTH => CHAIN_OUT_DATA_WIDTH)
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            pipeIn_DI => pipeIn_DI,
            blockStrobe_SI => blockStrobe_SI,
            write_SI => write_SI,
            read_SI => seqReadIn_S,
            ready_SO => BtPipeReady_S,
            outWord_DO => BtPipeOut_DO
            );

    sequencer : entity work.EventsSequencer
        generic map(
            OUT_DATA_WIDTH => CHAIN_OUT_DATA_WIDTH,
            BUFFER_DEPTH => BUFFER_DEPTH)
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            tsEvent_DI => BtPipeOut_DO,
            canAcceptBlock_SO => canAcceptBlock_SO,
            currentTime_DI => currentTime_DI,
            write_SI => BtPipeReady_S,
            numEventsFree_DO => numEventsFree_DO,
            AER_DO => AER_DO,
            AERAck_SI => AERAck_SI,
            AERReq_SO => AERReq_SO
            );
end;