library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture SendGetLatency of AvalonST_TestCtrl is

  signal TestDone  : integer_barrier := 1;
  signal SyncPoint : integer_barrier := 1;
  signal RxData    : std_logic_vector(31 downto 0);
  signal TxOptions : AvalonStreamOptionsType;
begin

  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("AvalonStreamSendGetLatency");
    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO, TRUE);

    wait for 0 ns;
    wait for 0 ns;

    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 2000 ns);
    AlertIf(now >= 2000 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    wait for 0 ns;
    std.env.stop;
  end process;

  ------------------------------------------------------------
  -- Transmitter Process
  ------------------------------------------------------------
  transmitter_proc : process
    variable ExpData : slv_array_t(0 downto 0) := (0 => (31 downto 0 => '0'));
  begin
    wait until Reset = '1';
    wait for 0 ns;
    ExpData(0)(0) := '1';
    SetAvalonStreamOptions(StreamTxRec, READY_LATENCY, 3);
    WaitForBarrier(SyncPoint);
    for i in 0 to 3 loop
      SendAsync(StreamTxRec, ExpData, 1);
      ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    SendAsync(StreamTxRec, ExpData, 1);
    SetAvalonStreamOptions(StreamTxRec, READY_LATENCY, 0);
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    wait for 50 ns; -- introduce another delay to see if ready is only asserted when valid

    ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    for i in 0 to 3 loop
      SendAsync(StreamTxRec, ExpData, 1);
      ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    SendAsync(StreamTxRec, ExpData, 1);
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable rx_data   : std_logic_vector(31 downto 0);
    variable available : boolean;
    variable ExpData   : slv_array_t(0 downto 0) := (0 => (31 downto 0 => '0'));
  begin
    wait until Reset = '1';
    wait for 0 ns;
    ExpData(0)(0) := '1';
    WaitForBarrier(SyncPoint);
    Receive(StreamRxRec, 4);
    WaitForTransaction(StreamRxRec);
    for i in 0 to 3 loop
      Check(StreamRxRec, ExpData(0));
      ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    Receive(StreamRxRec, 1);
    WaitForTransaction(StreamRxRec);
    Check(StreamRxRec, ExpData(0));
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    Receive(StreamRxRec, 4);
    WaitForTransaction(StreamRxRec);
    for i in 0 to 3 loop
      Check(StreamRxRec, ExpData(0));
      ExpData(0) := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData(0))) + 1, ExpData(0)'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);

    WaitForTransaction(StreamRxRec);
    WaitForClock(StreamRxRec, 5);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture SendGetLatency;

configuration AvalonStreamSendGetLatency of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(SendGetLatency);
    end for;
  end for;
end AvalonStreamSendGetLatency;
