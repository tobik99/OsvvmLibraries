library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture SendGetLatency of AvalonST_TestCtrl is
   
    signal TestDone   : integer_barrier               := 1;
    signal ExpData    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
    signal RxData     : std_logic_vector(31 downto 0);
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
      WaitForBarrier(TestDone, 3 ms);
      AlertIf(now >= 20 ms, "Test finished due to timeout");
      AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");
  
      EndOfTestReports;
      wait for 0 ns;
      std.env.stop;
    end process;
  
    -- Test process
    transmitter_proc : process
    begin
      wait until i_nreset = '1';
      wait for 0 ns;
      SetAvalonStreamOptions(io_tx_trans_rec, READY_BEFORE_VALID_DELAY_CYCLES, 3);
      SendAsync(io_tx_trans_rec, ExpData);
      
      WaitForClock(io_tx_trans_rec, 2);
      WaitForBarrier(TestDone);
      wait;
    end process transmitter_proc;
  
    receiver_proc : process
      variable rx_data : std_logic_vector(31 downto 0);
    begin
      wait until i_nreset = '1';
      -- Get(io_rx_trans_rec, rx_data);
      -- RxData <= rx_data;
      wait for 0 ns;
      Check(io_rx_trans_rec, ExpData) ; 
      AffirmIf(ExpData = RxData, "Data: " & to_string(ExpData),
      " /= Expected: " & to_string(RxData));
  
      WaitForClock(io_rx_trans_rec, 2);
      WaitForBarrier(TestDone);
      wait;
    end process receiver_proc;
  
  end architecture SendGetLatency;
  