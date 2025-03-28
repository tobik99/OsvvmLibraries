
architecture SendGet of AvalonST_TestCtrl is
  signal scoreboard : ScoreboardIDType;
  signal TestDone   : integer_barrier               := 1;
  signal ExpData    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  signal RxData     : std_logic_vector(31 downto 0);
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
   
    SetTestName("AvalonST_SendGet");
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
    WaitForBarrier(TestDone, 3 ms);
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

    SendAsync(StreamTxRec, ExpData);
    --SendAsync(io_tx_trans_rec, ExpData);
    WaitForClock(StreamTxRec, 2);
    --Send(io_tx_trans_rec, ExpData);
    --Send(io_tx_trans_rec, ExpData);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable rx_data : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    Get(StreamRxRec, rx_data);
    RxData <= rx_data;
    wait for 0 ns;
    AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
    " /= Expected: " & to_string(RxData));

    WaitForClock(StreamRxRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture SendGet;
