
architecture AvalonStreamSendGetTest of AvalonST_TestCtrl is
  signal scoreboard : ScoreboardIDType;
  signal TestDone   : integer_barrier               := 1;
  signal ExpData    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  signal ExpData2   : slv_vector(0 to 1)            := (x"10011001", x"F00FF00F");
  signal CheckData : slv_array_t(0 to 1)(31 downto 0) := (
    x"10011001", -- 1st data
    x"F00FF00F"  -- 2nd data
  );
  signal RxData     : std_logic_vector(31 downto 0);
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

   
    Send(StreamTxRec, CheckData(0));
    WaitForTransaction(StreamTxRec);
    wait for 20 ns;


    SendBurstVector(StreamTxRec, ExpData2);
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable rx_data   : std_logic_vector(31 downto 0);
    variable fifoWords : integer := 2;
    variable PopData : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    ReceiveBurst(StreamRxRec, 1);
    WaitForTransaction(StreamRxRec);
    GetBurst(StreamRxRec, fifoWords);
    for i in 0 to 0 loop
      PopData := pop(StreamRxRec.BurstFifo);
      AffirmIf(PopData = CheckData(i), "Data is right");
    end loop;
 wait for 20 ns;


    ReceiveBurst(StreamRxRec, 2);
    WaitForTransaction(StreamRxRec);
    GetBurst(StreamRxRec, fifoWords);
     for i in 0 to fifoWords - 1 loop
      PopData := pop(StreamRxRec.BurstFifo);
      AffirmIf(PopData = CheckData(i), "Data is right");
    end loop;

    WaitForClock(StreamRxRec, 2);
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
