library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture SendGetLatency of AvalonST_TestCtrl is

  signal TestDone  : integer_barrier := 1;
  signal RxData    : std_logic_vector(31 downto 0);
  signal TxOptions : AvalonStreamOptionsType;
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test

    SetTestName("AvalonStreamSendGetAsync");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE);   -- Enable INFO logs

    -- Wait for simulation elaboration/initialization 
    wait for 0 ns;
    wait for 0 ns;

    -- Wait for Design Reset
    wait until i_nreset = '1';
    ClearAlerts;

    -- Wait for test to finish
    -- every process has to call its own TestDone, otherwise the watchdog will execute
    WaitForBarrier(TestDone, 2000 ns);
    AlertIf(now >= 2000 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    wait for 0 ns;
    std.env.stop;
  end process;

  -- Test process
  transmitter_proc : process
    variable ExpData : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  begin
    wait until i_nreset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(io_tx_trans_rec, READY_BEFORE_VALID_DELAY_CYCLES, 3);

    for i in 3 downto 0 loop
      SendAsync(io_tx_trans_rec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) - 256, ExpData'length));
    end loop;

    WaitForClock(io_tx_trans_rec, 20);
    SendAsync(io_tx_trans_rec, ExpData);
    WaitForTransaction(io_tx_trans_rec);

    SetAvalonStreamOptions(io_tx_trans_rec, READY_BEFORE_VALID_DELAY_CYCLES, 3);
    for i in 3 downto 0 loop
      SendAsync(io_tx_trans_rec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) - 256, ExpData'length));
    end loop;

    WaitForClock(io_tx_trans_rec, 20);
    SendAsync(io_tx_trans_rec, ExpData);
    WaitForTransaction(io_tx_trans_rec);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  receiver_proc : process
    variable rx_data : std_logic_vector(31 downto 0);

    variable ExpData : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  begin
    wait until i_nreset = '1';
    -- Get(io_rx_trans_rec, rx_data);
    -- RxData <= rx_data;
    wait for 0 ns;
    for i in 3 downto 0 loop
      Check(io_rx_trans_rec, ExpData);
      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) - 256, ExpData'length));
      -- AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
      -- " /= Expected: " & to_string(RxData));
    end loop;
    WaitForClock(io_rx_trans_rec, 20);
    Check(io_rx_trans_rec, ExpData);
    WaitForTransaction(io_rx_trans_rec);

    for i in 3 downto 0 loop
      Check(io_rx_trans_rec, ExpData);

      ExpData := std_logic_vector(to_unsigned(to_integer(unsigned(ExpData)) - 256, ExpData'length));
      -- AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
      -- " /= Expected: " & to_string(RxData));
    end loop;
    WaitForClock(io_rx_trans_rec, 20);
    Check(io_rx_trans_rec, ExpData);
    WaitForTransaction(io_rx_trans_rec);
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture SendGetLatency;
