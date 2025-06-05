
architecture AvalonStreamSendGetTest of AvalonST_TestCtrl is
  signal scoreboard : ScoreboardIDType;
  signal TestDone   : integer_barrier               := 1;
  signal ExpData    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  signal SendData : std_logic_vector(31 downto 0) := x"00000000";
  signal SendDataArray : slv_vector(0 to 1)(31 downto 0) := (
    x"10011001", -- 1st data
    x"F00FF00F"  -- 2nd data
  );
  
  signal getWords : integer := 2; -- Number of words to get from the receiver
  
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test

    SetTestName("AvalonStreamSendGetTest");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE);   -- Enable INFO logs
    -- Scoreboard initialization
    scoreboard <= NewID("AvalonST_SB");
    -- Wait for simulation elaboration/initialization 
    wait for 0 ns;
    wait for 0 ns;

    -- Wait for Design Reset
    wait until Reset = '1';
    ClearAlerts;

    -- Wait for test to finish
    -- every process has to call its own TestDone, otherwise the watchdog will execute
    WaitForBarrier(TestDone, 500 ns);
    AlertIf(now >= 500 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.finish;
  end process;

  -- Test process
  transmitter_proc : process
  variable NumBytes : integer := 5;
      variable CheckDataWord : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    wait for 0 ns;

  -- Send and Get    
    log("Transmit 5 words") ;
    CheckDataWord := x"0000_0000";
    for I in 1 to 5 loop 
      Send( StreamTxRec, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length))  ) ; 
    end loop ; 

    WaitForClock(StreamTxRec, 2) ; 

-- Send and Check    
    log("Transmit 5 words") ;
    CheckDataWord := x"0000_1000";
    for I in 1 to 5 loop 
      Send( StreamTxRec,  std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length))  ) ; 
    end loop ; 
WaitForClock(StreamTxRec, 2) ; 
      
-- SendBurst and GetBurst    
    log("Send 5 word burst") ;
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop 
      Push( StreamTxRec.BurstFifo, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length))  ) ; 
    end loop ; 
    SendBurst(StreamTxRec, 5) ;

    WaitForClock(StreamTxRec, 2) ; 
-- SendBurst and CheckBurst    
    log("Send 5 word burst") ;
    CheckDataWord := x"0000_3000";
    for I in 1 to 5 loop 
       Push( StreamTxRec.BurstFifo, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)) ) ; 
    end loop ; 
    SendBurst(StreamTxRec, 5) ;

    WaitForClock(StreamTxRec, 2);
    -- SendBurst and CheckBurst    
    log("SendBurstVector 13 word burst") ;
    SendBurstVector(StreamTxRec, 
        (X"0000_4001", X"0000_4003", X"0000_4005", X"0000_4007", X"0000_4009") ) ;


          -- SendBurstIncrement and CheckBurstIncrement    
    WaitForClock(StreamTxRec, 1) ; 
    log("SendBurstIncrement 16 word burst") ;
    SendBurstIncrement(StreamTxRec, X"0000_5000", 16) ; 

-- SendBurstRandom and CheckBurstRandom    
    WaitForClock(StreamTxRec, 1) ; 
    log("SendBurstRandom 24 word burst") ;
    SendBurstRandom   (StreamTxRec, X"0000_6000", 24) ; 
    -- SendBurstVector(StreamTxRec, ExpData2);
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable rx_data   : std_logic_vector(31 downto 0);
    variable fifoWords : integer := 2;
    variable PopData : std_logic_vector(31 downto 0);
    variable receiveWords : integer := 2; -- Number of words to receive from the transmitter
      variable RxData     : std_logic_vector(31 downto 0);
      variable NumBytes : integer := 5;
      variable CheckDataWord : std_logic_vector(31 downto 0);

  begin
    wait until Reset = '1';

    log("Get 5 words") ;
     CheckDataWord := x"0000_0000";
    for I in 1 to 5 loop 
      Get(StreamRxRec, RxData) ;      
      AffirmIfEqual(RxData, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)), "CheckData RxData") ;
    end loop ; 

    log("Check 5 words") ;
    CheckDataWord := x"0000_1000";
    for I in 1 to 5 loop 
      Check(StreamRxRec,  std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)) ) ;      
    end loop ; 


    log("Get 5 word burst") ;
    GetBurst(StreamRxRec, NumBytes) ;
    AffirmIfEqual(NumBytes, 5, "Receiver: 5 Received") ;
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop 
      RxData := Pop( StreamRxRec.BurstFifo ) ;      
      AffirmIfEqual(RxData,  std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)) , "RxData") ;
    end loop ; 


    WaitForClock(StreamRxRec, 2);
    log("Check 5 word burst") ;
      CheckDataWord := x"0000_3000";
    for I in 1 to 5 loop 
      Push( StreamRxRec.BurstFifo,  std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length))  ) ; 
    end loop ; 
    CheckBurst(StreamRxRec, 5) ;

    WaitForClock(StreamRxRec, 2);
    CheckBurstVector(StreamRxRec, 
        (X"0000_4001", X"0000_4003", X"0000_4005", X"0000_4007", X"0000_4009") ) ;

      

    CheckBurstIncrement(StreamRxRec, X"0000_5000", 16) ; 

    CheckBurstRandom   (StreamRxRec, X"0000_6000", 24) ; 

  WaitForBarrier(TestDone);
  wait;
  end process receiver_proc;

end architecture AvalonStreamSendGetTest;

configuration AvalonStreamSendGetTest of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(AvalonStreamSendGetTest);
    end for;
  end for;
end AvalonStreamSendGetTest;
