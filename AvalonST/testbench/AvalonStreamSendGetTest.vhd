
architecture AvalonST_SendTest of AvalonST_TestCtrl is
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
    SetTestName("AvalonST_Send");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE);   -- Enable INFO logs
    -- Scoreboard initialization
    scoreboard <= NewID("AvalonST_SB");
    -- Wait for simulation elaboration/initialization 
    wait for 0 ns;
    wait for 0 ns;

    -- Wait for Design Reset
    wait until i_nreset = '1';
    ClearAlerts;

    -- Wait for test to finish
    -- every process has to call its own TestDone, otherwise the watchdog will execute
    WaitForBarrier(TestDone, 3 ms);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.stop;
  end process;

  -- Test process
  transmitter_proc : process
  begin
    wait until i_nreset = '1';
    wait for 0 ns;

    SEND(io_tx_trans_rec, ExpData);

    WaitForClock(io_tx_trans_rec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable rx_data : std_logic_vector(31 downto 0);
  begin
    wait until i_nreset = '1';
    Get(io_rx_trans_rec, rx_data);
    RxData <= rx_data;
    wait for 0 ns;
    AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
    " /= Expected: " & to_string(RxData));

    WaitForClock(io_rx_trans_rec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture AvalonST_SendTest;
