library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity ResetBlock is
    generic (
        DELAY_PRst : integer := 100000;
        DELAY_SRst : integer := 100000
        );
    port (
        clk_CI : in std_logic;
        reset_RBI : in std_logic;
        Prst_RBO : out std_logic;
        Srst_RBO : out std_logic;
        piperst_RBO : out std_logic
        );
end ResetBlock;

architecture behavioural of ResetBlock is
    -- We rely heavily on initial values for registers. On Xilinx devices it is
    -- guaranteed that the initial value specified at signal definition will
    -- appear in the register at power on.
    -- This is the only module in which it is allowed to rely on this feature.
    -- All other modules must use a reset input.
    type state_type is (startup, assert_srst, assert_prst, deassert_prst, deassert_srst, idle);
    signal state_SP : state_type := startup; -- Xilinx guarantees initial value
    signal state_SN : state_type;

    signal reset_RBP : std_logic := '1';
    signal reset_RBN : std_logic;
    signal resetWasHigh_SP : std_logic := '1';
    signal resetWasHigh_SN : std_logic;

    signal PRst_SP : std_logic := '0'; -- Xilinx guarantees initial value
    signal SRst_SP : std_logic := '0'; -- Xilinx guarantees initial value
    signal PRst_SN : std_logic;
    signal SRst_SN : std_logic;
    signal pipeRst_SP : std_logic := '0'; -- Xilinx guarantees initial value
    signal pipeRst_SN : std_logic;
    signal waitCountPR_DN, waitCountPR_DP : unsigned(9 downto 0) := (others => '0');
    signal waitCountPREn_S : std_logic;
    signal waitCountSR_DN, waitCountSR_DP : unsigned(9 downto 0) := (others => '0');
    signal waitCountSREn_S : std_logic;
begin

    process(all)
    begin
        if reset_RBI = '1' then
            resetWasHigh_SN <= '1';
        else
            resetWasHigh_SN <= '0';
        end if;

        if reset_RBI = '0' and resetWasHigh_SP = '1' then
            reset_RBN <= '0';
        else
            reset_RBN <= reset_RBP;
        end if;

        PRst_SN <= PRst_SP;
        SRst_SN <= SRst_SP;
        pipeRst_SN <= pipeRst_SP;
        waitCountPR_DN <= waitCountPR_DP + 1;
        waitCountPREn_S <= '0';
        waitCountSR_DN <= waitCountSR_DP + 1;
        waitCountSREn_S <= '0';

        state_SN <= state_SP;

        pipeRst_RBO <= pipeRst_SP;
        SRst_RBO <= SRst_SP;
        PRst_RBO <= PRst_SP;

        case state_SP is
            when startup =>
                waitCountPREn_S <= '1';
                if waitCountPR_DP = DELAY_PRst then
                    waitCountPR_DN <= (others => '0');
                    state_SN <= deassert_prst;
                end if;
            when idle =>
                pipeRst_SN <= '1';
                waitCountPr_DN <= (others => '0');
                waitCountPrEn_S <= '1';
                waitCountSr_DN <= (others => '0');
                waitCountSrEn_S <= '1';
                if reset_RBP = '0' then
                    -- initialize the reset procedure and mark the reset
                    -- reg as accepted. If another reset arrives while
                    -- we are resetting, it will simply be executed when
                    -- we get back here
                    state_SN <= assert_srst;
                    reset_RBN <= '1';
                    pipeRst_SN <= '0';
                end if;
            when assert_srst =>
                SRst_SN <= '0';
                waitCountSREn_S <= '1';
                if waitCountSR_DP = DELAY_SRst then
                    waitCountSR_DN <= (others => '0');
                    state_SN <= assert_prst;
                end if;
            when assert_prst =>
                PRst_SN <= '0';
                waitCountPREn_S <= '1';
                if waitCountPR_DP = DELAY_PRst then
                    waitCountPR_DN <= (others => '0');
                    state_SN <= deassert_prst;
                end if;
            when deassert_prst =>
                PRst_SN <= '1';
                waitCountPREn_S <= '1';
                if waitCountPR_DP = DELAY_PRst then
                    waitCountPR_DN <= (others => '0');
                    state_SN <= deassert_srst;
                end if;
            when deassert_srst =>
                SRst_SN <= '1';
                waitCountSREn_S <= '1';
                if waitCountSR_DP = DELAY_SRst then
                    waitCountSR_DN <= (others => '0');
                    reset_RBN <= '1';
                    state_SN <= idle;
                end if;
        end case;


    end process;

    registers : process(clk_CI, reset_RBP)
    begin
        if rising_edge(clk_CI) then
            state_SP <= state_SN;
            PRst_SP <= PRst_SN;
            SRst_SP <= SRst_SN;
            pipeRst_SP <= pipeRst_SN;

            if waitCountPREn_S = '1' then
                waitCountPR_DP <= waitCountPR_DN;
            end if;

            if waitCountSREn_S = '1'then
                waitCountSR_DP <= waitCountSR_DN;
            end if;
        end if;
    end process;

    inputLatch : process(clk_CI)
    begin
        if rising_edge(clk_CI) then
            reset_RBP <= reset_RBN;
            resetWasHigh_SP <= resetWasHigh_SN;
        end if;
    end process;

end behavioural;
