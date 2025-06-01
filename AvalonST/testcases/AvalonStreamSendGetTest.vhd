
architecture AvalonStreamSendGetTest of AvalonST_TestCtrl is
  signal scoreboard : ScoreboardIDType;
  signal TestDone   : integer_barrier               := 1;
  signal ExpData    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  signal CheckData : slv_vector(0 to 1)(31 downto 0) := (
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
    WaitForBarrier(TestDone, 200 ns);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.finish;
  end process;

  -- Test process
  transmitter_proc : process
  begin
    wait until Reset = '1';
    wait for 0 ns;

   for I in 0 to 1 loop 
      Push( StreamTxRec.BurstFifo, CheckData(I) ) ; 
    end loop ; 
    SendBurst(StreamTxRec, 2) ;
    WaitForClock(StreamTxRec, 2);


    for I in 0 to 1 loop 
      Send( StreamTxRec, CheckData(I) ) ; 
    end loop ; 

      CheckData(0) <= x"11110000";
      CheckData(1) <= x"00001111";
      WaitForClock(StreamTxRec, 2);

       for I in 0 to 1 loop 
      Send( StreamTxRec, CheckData(I) ) ; 
    end loop ;
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

  begin
    wait until Reset = '1';

    for I in 0 to 1 loop 
      Push( StreamRxRec.BurstFifo, CheckData(I) ) ; 
    end loop ; 
    CheckBurst(StreamRxRec, receiveWords);
    WaitForClock(StreamRxRec, 2);

 for I in 0 to 1 loop 
      Get(StreamRxRec, RxData) ;      
      wait for 0 ns ; 
      AffirmIfEqual(RxData, CheckData(I), "Data right") ;
    end loop ; 

    WaitForClock(StreamRxRec, 2);
 for I in 0 to 1 loop 
     Check(StreamRxRec, CheckData(I));
    end loop ; 

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
