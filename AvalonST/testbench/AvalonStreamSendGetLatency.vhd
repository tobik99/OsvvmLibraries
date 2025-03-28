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
    variable ExpData : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamTxRec, READY_BEFORE_VALID_DELAY_CYCLES, 3);
    WaitForBarrier(SyncPoint);
    for i in 0 to 3 loop
      SendAsync(StreamTxRec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    SendAsync(StreamTxRec, ExpData);
    SetAvalonStreamOptions(StreamTxRec, READY_BEFORE_VALID_DELAY_CYCLES, 0);
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    wait for 50 ns; -- introduce another delay to see if ready is only asserted when valid

    ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    for i in 0 to 3 loop
      SendAsync(StreamTxRec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    SendAsync(StreamTxRec, ExpData);
    WaitForTransaction(StreamTxRec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable rx_data : std_logic_vector(31 downto 0);
    variable ExpData : std_logic_vector(31 downto 0) := (0 => '1', others => '0');
  begin
    wait until Reset = '1';
    wait for 0 ns;
    WaitForBarrier(SyncPoint);
    for i in 0 to 3 loop
      Check(StreamRxRec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    Check(StreamRxRec, ExpData);
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    for i in 0 to 3 loop
      Check(StreamRxRec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) + 1, ExpData'length));
    end loop;
    wait for 50 ns;
    WaitForBarrier(SyncPoint);
    Check(StreamRxRec, ExpData);
    WaitForTransaction(StreamRxRec);
    WaitForClock(StreamRxRec, 5);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture SendGetLatency;
