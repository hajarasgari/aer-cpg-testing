library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity OutputEventsChain is
    generic (
        CHAIN_IN_DATA_WIDTH : integer := 30;
        BUFFER_DEPTH : integer := 2048
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        AER_DI : in std_logic_vector(CHAIN_IN_DATA_WIDTH-1 downto 0);
        AERReq_SI : in std_logic;
        AERAck_SO : out std_logic;
        data_DO : out std_logic_vector(31 downto 0);
        numEventsFree_DO : out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        --currentTime_DI : in unsigned(31 downto 0);
        currentTime_DI1 : in std_logic_vector(31 downto 0);
        blockStrobe_SI : in std_logic;
        readEn_SI : in std_logic;
        fifoFull_S : out std_logic;
        ready_SO : out std_logic
        );
end OutputEventsChain;

architecture structural of OutputEventsChain is
    signal receiverData_D : std_logic_vector(31 downto 0);
    signal receiverNumEventsHeld_D : unsigned(10 downto 0);
    signal currentTime_DI : unsigned(31 downto 0);
    signal receiverReadEn_S : std_logic;
    
begin
    
currentTime_DI <= unsigned(currentTime_DI1);

    receiver : entity work.EventReceiver
        generic map (
            IN_DATA_WIDTH => CHAIN_IN_DATA_WIDTH,
            BUFFER_DEPTH => BUFFER_DEPTH
            )
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            AER_DI => AER_DI,
            AERReq_SI => AERReq_SI,
            AERAck_SO => AERAck_SO,
            data_DO => receiverData_D,
            currentTime_DI => currentTime_DI,
            numEventsHeld_DO => receiverNumEventsHeld_D,
            fifoFull_S => fifoFull_S,
            numEventsFree_DO => numEventsFree_DO,
            readEn_SI => receiverReadEn_S
            );

    serializer : entity work.BtPipeSerializer
        port map (
            clk_CI => clk_CI,
            reset_RBI => reset_RBI,
            pipeOut_DO => data_DO,
            eventData_DI => receiverData_D,
            blockStrobe_SI => blockStrobe_SI,
            numEventsReady_DI => receiverNumEventsHeld_D,
            readOut_SI => readEn_SI,
            readIn_SO => receiverReadEn_S,
            ready_SO => ready_SO
            );
end structural;