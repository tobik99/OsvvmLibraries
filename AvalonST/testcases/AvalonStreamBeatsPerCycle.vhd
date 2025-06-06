library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture BeatsPerCycle of AvalonST_TestCtrl is
  signal TestDone : integer_barrier := 1;
begin

  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("AvalonStreamBeatsPerCycle");
    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO, TRUE);

    wait for 0 ns;
    wait for 0 ns;

    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 200 ns);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.stop;
  end process;

  ------------------------------------------------------------
  -- Transmitter Process
  ------------------------------------------------------------
  transmitter_proc : process
    variable CheckDataWord : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    -- SendBurst and GetBurst    
    log("Send 4 word burst");
    CheckDataWord := x"0000_2000";
    for I in 1 to 4 loop
      Push(StreamTxRec.BurstFifo, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)));
    end loop;
    SendBurst(StreamTxRec, 4);
log("Transmitter erreicht Barrier");
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable RxData : std_logic_vector(31 downto 0);
    variable NumBytes : integer := 4;
    variable CheckDataWord : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    -- log("Get 5 word burst") ;
    GetBurst(StreamRxRec, NumBytes);
    AffirmIfEqual(NumBytes, 4, "Receiver: 4 Received");
    CheckDataWord := x"0000_2000";
    for I in 1 to 4 loop
      RxData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxData, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)), "RxData");
    end loop;
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture BeatsPerCycle;

configuration AvalonStreamBeatsPerCycle of AvalonStreamTestHarnessBeatsPerCycle is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(BeatsPerCycle);
    end for;
  end for;
end AvalonStreamBeatsPerCycle;