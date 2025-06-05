library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture ReadyLatencyAllowance of AvalonST_TestCtrl is

  signal TestDone : integer_barrier := 1;
begin

  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("AvalonStreamReadyLatencyAllowance");
    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO, TRUE);

    wait for 0 ns;
    wait for 0 ns;

    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 1000 ns);
    AlertIf(now >= 1000 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    wait for 0 ns;
    std.env.stop;
  end process;

  -- Test process
  transmitter_proc : process
    variable CheckDataWord : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    SetAvalonStreamOptions(StreamTxRec, READY_LATENCY, 1);
    SetAvalonStreamOptions(StreamTxRec, READY_ALLOWANCE, 3);

    -- Send and Get    
    log("Transmit 5 words");
    CheckDataWord := x"0000_0000";
    for I in 1 to 5 loop
      Send(StreamTxRec, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)));
      WaitForClock(StreamTxRec, 5);
    end loop;

    WaitForClock(StreamTxRec, 5);

    -- Send and Check    
    log("Transmit 5 words");
    CheckDataWord := x"0000_1000";
    for I in 1 to 5 loop
      Send(StreamTxRec, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)));
      WaitForClock(StreamTxRec, 5);
    end loop;
WaitForClock(StreamTxRec, 5);

-- SendBurst and GetBurst    
    log("Send 5 word burst") ;
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop 
      Push( StreamTxRec.BurstFifo, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length))  ) ; 
    end loop ; 
    SendBurst(StreamTxRec, 5) ;
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable RxData : std_logic_vector(31 downto 0);
    variable CheckDataWord : std_logic_vector(31 downto 0);
    variable NumBytes : integer := 5;

  begin
    wait until Reset = '1';
    SetAvalonStreamOptions(StreamRxRec, READY_LATENCY, 1);
    SetAvalonStreamOptions(StreamRxRec, READY_ALLOWANCE, 3);

    log("Get 5 words");
    CheckDataWord := x"0000_0000";
    for I in 1 to 5 loop
      Get(StreamRxRec, RxData);
      AffirmIfEqual(RxData, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)), "CheckData RxData");
      WaitForClock(StreamRxRec, 5);
    end loop;

    WaitForClock(StreamRxRec, 5);

    log("Check 5 words");
    CheckDataWord := x"0000_1000";
    for I in 1 to 5 loop
      Check(StreamRxRec, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)));
      WaitForClock(StreamRxRec, 5);
    end loop;

    WaitForClock(StreamRxRec, 5);

    log("Get 5 word burst") ;
    GetBurst(StreamRxRec, NumBytes) ;
    AffirmIfEqual(NumBytes, 5, "Receiver: 5 Received") ;
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop 
      RxData := Pop( StreamRxRec.BurstFifo ) ;      
      AffirmIfEqual(RxData,  std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)) , "RxData") ;
    end loop ; 
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture ReadyLatencyAllowance;

configuration AvalonStreamReadyLatencyAllowance of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(ReadyLatencyAllowance);
    end for;
  end for;
end AvalonStreamReadyLatencyAllowance;