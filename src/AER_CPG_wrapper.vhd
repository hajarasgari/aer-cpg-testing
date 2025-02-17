
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;
use ieee.math_real.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;
use work.FRONTPANEL.all;

entity AER_CPG_wrapper is
    generic (
            CHAIN_DATA_WIDTH : integer := 20;
            BUFFER_DEPTH_IN : integer := 2048;
            BUFFER_DEPTH_OUT : integer := 1024;
            NOK : integer := 3
        );
	port (
	
       
        chip_fpga_req : in STD_LOGIC;
        chip_fpga_data : in STD_LOGIC_VECTOR (3 downto 0);
        chip_fpga_ack : out STD_LOGIC;
        
        fpga_chip_ack : in STD_LOGIC;
        fpga_chip_req : out STD_LOGIC;
        fpga_chip_data : out STD_LOGIC_VECTOR (CHAIN_DATA_WIDTH-1 downto 0);
        
        BGPD_ASI : out STD_LOGIC;
        DLY_CTL : out STD_LOGIC_VECTOR (1 downto 0);
        PReset : out STD_LOGIC;
        SReset : out STD_LOGIC;	 
        VDD_6  : out STD_LOGIC; 
        VDD_1  : out STD_LOGIC; 
         
		okUH      : in     STD_LOGIC_VECTOR(4 downto 0);
		okHU      : out    STD_LOGIC_VECTOR(2 downto 0);
		okUHU     : inout  STD_LOGIC_VECTOR(31 downto 0);
		okAA      : inout  STD_LOGIC;
		
		sys_clkp: in std_logic;
        sys_clkn: in std_logic;
		
		led       : out    STD_LOGIC_VECTOR(7 downto 0)
	);
end AER_CPG_wrapper;

architecture arch of  AER_CPG_wrapper is
	
--------------------------------------------------------------------
------------------------ Parameter declaration-------------------------
--------------------------------------------------------------------    

--constant CHAIN_DATA_WIDTH : positive range 2 to positive'right := 20;
--constant CHAIN_IN_DATA_WIDTH : positive range 2 to positive'right := 20;
--constant BUFFER_DEPTH_OUT         : positive range 2 to positive'right :=2048;
--constant BUFFER_DEPTH_IN         : positive range 2 to positive'right :=4;
constant CLK_PERIOD : time := 100 ns;


--------------------------------------------------------------------
------------------------ Signal declaration-------------------------
--------------------------------------------------------------------
    --signal VDD_6        :  STD_LOGIC;
	signal okClk        : STD_LOGIC;
	signal sys_clk      : STD_LOGIC;
	signal okHE         : STD_LOGIC_VECTOR(112 downto 0);
	signal okEH         : STD_LOGIC_VECTOR(64 downto 0);
	signal okEHx        : STD_LOGIC_VECTOR(65*3-1 downto 0);
	signal WireIn03     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn07     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn08     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn09     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn0A     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn11     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn0B     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireIn10     : STD_LOGIC_VECTOR(31 downto 0);
	signal WireOut21    : STD_LOGIC_VECTOR(31 downto 0);
	signal WireOut22    : STD_LOGIC_VECTOR(31 downto 0);
	signal WireOut23    : STD_LOGIC_VECTOR(31 downto 0);
	signal TrigIn40     : STD_LOGIC_VECTOR(31 downto 0);
	signal TrigIn41     : STD_LOGIC_VECTOR(31 downto 0);
	signal TrigOut60    : STD_LOGIC_VECTOR(31 downto 0);
	
	signal pipeI_write  : STD_LOGIC;
	signal pipeO_read   : STD_LOGIC;
	signal pipeI_data   : STD_LOGIC_VECTOR(31 downto 0);
	signal pipeO_data   : STD_LOGIC_VECTOR(31 downto 0);
	signal start        : STD_LOGIC;
	signal ram_reset    : STD_LOGIC;
	signal done         : STD_LOGIC;

	signal ramI_addrA   : STD_LOGIC_VECTOR(8 downto 0);
	signal ramI_addrB   : STD_LOGIC_VECTOR(8 downto 0);
	signal ramO_addrA   : STD_LOGIC_VECTOR(8 downto 0);
	signal ramO_addrB   : STD_LOGIC_VECTOR(8 downto 0);
	signal ramO_write   : STD_LOGIC;
	signal ramI_dout    : STD_LOGIC_VECTOR(31 downto 0);
	signal ramO_din     : STD_LOGIC_VECTOR(31 downto 0);

    signal clk_CI      :  std_logic;
	signal glob_reset  : STD_LOGIC;   
    signal reset_RBI   :  std_logic;
    --signal PReset :  std_logic;
    --signal SReset :  std_logic;


----- -- InPUTEVENTSCHAIN signals
    signal pipeIn_DI  : std_logic_vector(31 downto 0);
    signal pipeIn_DI1 : std_logic_vector(31 downto 0);
    signal blockStrobe_SI_1 :  std_logic;
    signal write_SI :  std_logic;
    signal write_SI1:  std_logic;
    signal canAcceptBlock_SO :  std_logic;
    signal currentTime_DI1 :  std_logic_vector(31 downto 0);
    signal AER_DO :  std_logic_vector(CHAIN_DATA_WIDTH-1 downto 0);
    signal numEventsFree_DO_1 :  std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH_IN)))) - 1 downto 0);
    signal AERAck_SI :  std_logic;
    signal AERReq_SO :  std_logic;

----- OUTPUTEVENTSCHAIN signals
    signal AER_DI :  std_logic_vector(CHAIN_DATA_WIDTH-1 downto 0);
    signal AERReq_SI :  std_logic;
    signal AERAck_SO :  std_logic;
    signal data_DO :  std_logic_vector(31 downto 0);--        
    signal numEventsFree_DO_2 : std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH_OUT)))) - 1 downto 0);
    signal currentTime_DI2 : std_logic_vector(31 downto 0);
    signal blockStrobe_SI_2 : std_logic;
    signal readEn_SI      : std_logic;
    signal ready_SO       : std_logic;
    signal fifoFull_S       : std_logic;

------ time----count
    signal Time_count : std_logic_vector(10 downto 0);
    signal counterTime :  std_logic_vector(31 downto 0);
	signal i : INTEGER;
	signal sw: std_logic;
	signal slow_clk : std_logic;
	signal count_reg     : std_logic_vector(11 downto 0);
	signal count_next    : std_logic_vector(11 downto 0);
	
begin

 -- *****************************************************************
    -- Clock generator
    -- *****************************************************************
    osc_clk : IBUFGDS port map (O=>sys_clk, I=>sys_clkp, IB=>sys_clkn);
  ---------------------------------------------------------------------
  ------------------------Slowing down the clock ----------------------
  ---------------------------------------------------------------------
     process(sys_clk, reset_RBI)
       begin
           if(reset_RBI = '0') then
               count_reg <= (others=>'0');
               slow_clk <='0';
           elsif(sys_clk'event and sys_clk = '1') then   
                   count_reg   <=   count_next;         
                   if( count_reg =  100) then                      
                         count_reg   <= (others=>'0');
                         slow_clk <= not slow_clk;
                   else                       
                         
                   end if;
           end if;
       end process;
       count_next   <=  count_reg + 1;
  
  ---- Estimating thereal time  --------------------   
    
        counter_time : entity work.counter 
        port map  (
              clk => sys_clk,
              reset =>  glob_reset,
              Q1 => counterTime
               );
    
        clk_CI           <=  slow_clk; 
--------------------------------------------------------------------
------------------------ Physical on-board LEDs---------------------
--------------------------------------------------------------------
led(7) <= '0' when (AERAck_SI = '1') else 'Z';
led(6) <= '0' when (write_SI = '1') else 'Z';
led(5) <= '0' when (AERReq_SO = '1') else 'Z';
led(4) <= '0' when (reset_RBI = '1') else 'Z';
--led(3) <= '0' when (fifoFull_S = '1') else 'Z';
--led(2) <= '0' when (readEn_SI = '1') else 'Z';
--led(1) <= '0' when (AERAck_SO = '1') else 'Z';
--led(0) <= '0' when (AERReq_SI = '1') else 'Z';
led(3) <= '0' when (AER_DO(3) = '1') else 'Z';
led(2) <= '0' when (AER_DO(2) = '1') else 'Z';
led(1) <= '0' when (AER_DO(1) = '1') else 'Z';
led(0) <= '0' when (AER_DO(0) = '1') else 'Z';

VDD_6 <= '1' ;
VDD_1 <= reset_RBI ;
DLY_CTL <= "11" ;

--------------------------------------------------------------------
------------------------ Port maps----------------------------------
--------------------------------------------------------------------

---- Getting data from cpg --------------------      
---- Sending data to PC     --------------------
OutputEventsChain2 : entity work.OutputEventsChain
generic map (
    CHAIN_IN_DATA_WIDTH => CHAIN_DATA_WIDTH,
    BUFFER_DEPTH => BUFFER_DEPTH_OUT
    )
port map (
        clk_CI =>  clk_CI,
        reset_RBI => reset_RBI,
        AER_DI => AER_DI ,--: in std_logic_vector(CHAIN_IN_DATA_WIDTH-1 downto 0);
        AERReq_SI => AERReq_SI,--: in std_logic;
        AERAck_SO => AERAck_SO,-- : out std_logic;
        data_DO  => data_DO , -- : out std_logic_vector(31 downto 0);
        numEventsFree_DO => numEventsFree_DO_2,  --: out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        currentTime_DI1 =>  currentTime_DI1,-- : in unsigned(31 downto 0);
        blockStrobe_SI => blockStrobe_SI_2,-- : in std_logic;
        readEn_SI => readEn_SI,-- : in std_logic;
        fifoFull_S => fifoFull_S,
        ready_SO => ready_SO-- : out std_logic
    );

---- Getting data from PC --------------------      
---- Sending data to cpg  --------------------

InputEventsChain1 : entity work.InputEventsChain
generic map (
    CHAIN_OUT_DATA_WIDTH => CHAIN_DATA_WIDTH,
    BUFFER_DEPTH => BUFFER_DEPTH_IN
    )
port map (
        clk_CI =>  clk_CI,
        reset_RBI => reset_RBI,
        pipeIn_DI => pipeIn_DI1, --in std_logic_vector(31 downto 0);
        blockStrobe_SI => blockStrobe_SI_1, -- : in std_logic;
        write_SI => write_SI1, -- : in std_logic;
        canAcceptBlock_SO => canAcceptBlock_SO ,--: out std_logic;
        currentTime_DI1 => currentTime_DI1, -- : in unsigned(31 downto 0);
        AER_DO => AER_DO, --: out std_logic_vector(CHAIN_OUT_DATA_WIDTH-1 downto 0);
        numEventsFree_DO =>  numEventsFree_DO_1, --: out std_logic_vector(integer(ceil(log2(real(BUFFER_DEPTH)))) - 1 downto 0);
        AERAck_SI => AERAck_SI, --: in std_logic;
        AERReq_SO => AERReq_SO  --: out std_logic
    );  

---- reset controller-----------------------

    rst_block: entity work.Reset_Controller 
    port map (
      clk_CI => sys_clk,
      reset_RBI => glob_reset,
      Prst_RBO => PReset,
      Srst_RBO => SReset,
      counterTime => counterTime,
      piperst_RBO => reset_RBI
    );

--reset_RBI <= glob_reset;


--------------------------------------------------------------------
------------------------ CHIP-FPGA communication-------------
--------------------------------------------------------------------

AER_DI <= "0000000000000000" & chip_fpga_data(3 downto 0);

AERReq_SI <= '0' when (chip_fpga_req = '1') else '1';    

chip_fpga_ack <= '0' when ( AERAck_SO = '1') else '1';

fpga_chip_data <= AER_DO;

fpga_chip_req <='0' when (AERReq_SO = '1') else '1';

--AERAck_SI <= '0' when (fpga_chip_ack = '1') else '1';
---------------------------------------------------------------------
------------------------CPU-FPGA communication endpoints--------------
-------------------------------------------------------------------
pipeIn_DI1     <=  pipeI_data;
write_SI1      <=  WireIn07(0);
pipeO_data     <=  data_DO;
readEn_SI      <=  WireIn11(0);
--ready_SO

---------------------------------------------------------------------
------------------------Creating closed-loop test-------------------
--------------------------------------------------------------------

glob_reset              <=  WireIn10(0); 
--AER_DI                  <=  WireIn08 (19 downto 0);  
--AERReq_SI               <=  WireIn09(0);
WireOut22(0)            <=  AERAck_SO;

WireOut21(19 downto 0)  <=  AER_DO;          
WireOut23(0)            <=  AERReq_SO;
AERAck_SI               <=  WireIn0A(0);

currentTime_DI1  <= counterTime;

process (clk_CI) is
begin
	if rising_edge(clk_CI) then
	    if readEn_SI='0' then
			pipeIn_DI <= (others=>'0');
            write_SI  <= '0';
            sw        <= '0';
		else
		      if sw='0' then
			                 write_SI  <= '0';
			                 pipeIn_DI <=  data_DO;
			                 sw        <= '1';
			  else
			  			     write_SI  <= '1';
                             pipeIn_DI <=  data_DO;
                             sw        <= '1';
              end if;
		end if;
	end if;
end process;

process (clk_CI) is
begin
	if rising_edge(clk_CI) then
		if (AERReq_SI = '1') then
			currentTime_DI2  <= counterTime;
		end if;
	end if;
end process;

-------------------------------------------------------------------
---- Instantiate the okHost and connect endpoints-------------------
--------------------------------------------------------------------

okHI : okHost port map (
	okUH=>okUH, 
	okHU=>okHU, 
	okUHU=>okUHU, 
	okAA=>okAA,
	okClk=>okClk, 
	okHE=>okHE, 
	okEH=>okEH
);

okWO : okWireOR     generic map (N=>3) port map (okEH=>okEH, okEHx=>okEHx);

ep03 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"03", ep_dataout=>WireIn03);
ep07 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"07", ep_dataout=>WireIn07);
ep08 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"08", ep_dataout=>WireIn08);
ep09 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"09", ep_dataout=>WireIn09);
ep0A : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"0A", ep_dataout=>WireIn0A);
ep11 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"11", ep_dataout=>WireIn11);
--ep0B : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"0B", ep_dataout=>WireIn0B);
ep10 : okWireIn     port map (okHE=>okHE,                                    ep_addr=>x"10", ep_dataout=>WireIn10);
ep21 : okWireOut    port map (okHE=>okHE,                                    ep_addr=>x"21", ep_datain =>WireOut21);
ep22 : okWireOut    port map (okHE=>okHE,                                    ep_addr=>x"22", ep_datain =>WireOut22);
ep23 : okWireOut    port map (okHE=>okHE,                                    ep_addr=>x"23", ep_datain =>WireOut23);
ep40 : okTriggerIn  port map (okHE=>okHE,                                    ep_addr=>x"40", ep_clk=>okClk, ep_trigger=>TrigIn40);
ep41 : okTriggerIn  port map (okHE=>okHE,                                    ep_addr=>x"41", ep_clk=>okClk, ep_trigger=>TrigIn41);
ep60 : okTriggerOut port map (okHE=>okHE, okEH=>okEHx( 1*65-1 downto 0*65 ), ep_addr=>x"60", ep_clk=>okClk, ep_trigger=>TrigOut60);
ep80 : okPipeIn     port map (okHE=>okHE, okEH=>okEHx( 2*65-1 downto 1*65 ), ep_addr=>x"80", ep_write=>pipeI_write, ep_dataout=>pipeI_data);
epA0 : okPipeOut    port map (okHE=>okHE, okEH=>okEHx( 3*65-1 downto 2*65 ), ep_addr=>x"a0", ep_read=>pipeO_read, ep_datain=>pipeO_data);

end arch;
