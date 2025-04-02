library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture ReadyLatencyAllowance of AvalonST_TestCtrl is

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
    SetTestName("AvalonStreamSendGetAsync");
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
    variable ExpData : slv_array_t(0 to 9)(3 downto 0) := (
    "0001", -- 1
    "0010", -- 2
    "0011", -- 3
    "0100", -- 4
    "0101", -- 5
    "0110", -- 6
    "0111", -- 7
    "1000", -- 8
    "1001", -- 9
    "1010"  -- 10
);
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamTxRec, READY_LATENCY, 2);
    SetAvalonStreamOptions(StreamTxRec, READY_ALLOWANCE, 3);
    wait for 10 ns;
    WaitForBarrier(SyncPoint);
    SendAsync(StreamTxRec, ExpData);
    WaitForBarrier(SyncPoint);
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable Available : boolean := false;
    variable ExpData : slv_array_t(0 to 9)(3 downto 0) := (
      "0001", -- 1
      "0010", -- 2
      "0011", -- 3
      "0100", -- 4
      "0101", -- 5
      "0110", -- 6
      "0111", -- 7
      "1000", -- 8
      "1001", -- 9
      "1010"  -- 10
  );
  begin
    wait until Reset = '1';
    wait for 0 ns;
    --SetAvalonStreamOptions(StreamRxRec, READY_LATENCY, 3);
    SetAvalonStreamOptions(StreamRxRec, READY_ALLOWANCE, 3);
    wait for 10 ns;
    WaitForBarrier(SyncPoint);
   



    Receive(StreamRxRec, 10);
    WaitForTransaction(StreamRxRec);
    WaitForClock(StreamRxRec, 5);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture ReadyLatencyAllowance;
