-- filepath: /home/tobi/repos/OsvvmLibraries/AvalonST/testbench/AvalonST_Transmitter_tb.vhd

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
    --TranscriptOpen;
    --SetTranscriptMirror(TRUE);

    -- Wait for Design Reset
    wait until i_nreset = '1';
    ClearAlerts;

    -- Wait for test to finish
    -- every process has to call its own TestDone, otherwise the watchdog will execute
    WaitForBarrier(TestDone, 3 ms);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");
   -- TranscriptClose;
   -- if CHECK_TRANSCRIPT then
   --   AffirmIfTranscriptsMatch(AVALON_STREAM_VALIDATED_RESULTS_DIR);
   -- end if;
    EndOfTestReports;
    --std.env.stop(GetAlertCount);
    --EndOfTestSummary(ReportAll => TRUE);
    wait;
  end process;

  -- Test process
  transmitter_VC : process

  begin
    -- Send data using AvalonStreamSend procedure
    --for i in 0 to 255 loop
    o_ready <= '0';
    wait until i_nreset = '1';
    o_ready <= '1';
    wait for 0 ns;

    --Push(scoreboard, ExpData);
    SEND(io_trans_rec, ExpData);

    WaitForClock(io_trans_rec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_VC;

  receiver_test : process
  begin
    wait until (i_valid = '1');
    RxData <= i_data;
    wait for 0 ns;
    AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
    " /= Expected: " & to_string(RxData));

    WaitForBarrier(TestDone);
    wait;
  end process receiver_test;

end architecture AvalonST_SendTest;
