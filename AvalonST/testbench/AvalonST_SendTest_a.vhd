-- filepath: /home/tobi/repos/OsvvmLibraries/AvalonST/testbench/AvalonST_Transmitter_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;
use osvvm.ScoreboardPkg_slv.all ;


library osvvm_avalonst;
context osvvm_avalonst.AvalonST_context;
architecture AvalonST_SendTest of AvalonST_TestCtrl is
  signal data          : std_logic_vector(31 downto 0) := (others => '0');
  signal expected_data : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(13, 32));
  signal sent_data : std_logic_vector(31 downto 0) := (others => '0');
  constant clk_period : time := 10 ns;

  signal scoreboard : ScoreboardIDType;

begin
  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("TbStream_SendGet1");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE);   -- Enable INFO logs

    -- Wait for simulation elaboration/initialization 
    wait for 0 ns;
    wait for 0 ns;
    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    -- Wait for Design Reset
    wait until i_nreset = '1';
    ClearAlerts;

    -- Wait for test to finish
    WaitForBarrier(TestDone, 35 ms);
    AlertIf(now >= 35 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    TranscriptClose;
    if CHECK_TRANSCRIPT then
      AffirmIfTranscriptsMatch(AVALON_STREAM_VALIDATED_RESULTS_DIR);
    end if;
  end process;


  
  -- Test process
  test_process : process
    variable ExpData, RxData : std_logic_vector(31 downto 0);
    variable TransactionCount : integer;
    variable ErrorCount : integer;
    variable CurTime : time;
  begin
    -- Send data using AvalonStreamSend procedure
    --for i in 0 to 255 loop
    wait until i_nreset = '1';
    o_ready <= '1';
    wait for 10 ns;
    SEND(io_trans_rec, expected_data);
    wait for clk_period;
    --end loop;


    -- Check if data is sent correctly
    if i_valid = '1' and data = expected_data then
      report "Data sent correctly: " & to_hstring(data);
    else
      report "Data sent incorrectly: " & to_hstring(data) severity error;
    end if;
-- alles unter hier ist vom chat!!!!!!!!!!! todo
   -- Get and check the data
   for i in 1 to 256 loop
    -- Create words one byte at a time
    ExpData := std_logic_vector(to_unsigned(i, 32));
    -- Alternate using Get and Check
    if (i mod 2) /= 0 then
      Get(trans_rec, RxData);
      GetTransactionCount(trans_rec, TransactionCount);
      wait for 0 ns;
      AffirmIfEqual(TransactionCount, i, "Receive TransactionCount:");
      AffirmIfEqual(RxData, ExpData, "Get: ");
    else
      Check(trans_rec, ExpData);
      GetTransactionCount(trans_rec, TransactionCount);
      wait for 0 ns;
      AffirmIfEqual(TransactionCount, i, "Receive TransactionCount:");
    end if;
    if i mod 2 = 0 then
      GetErrorCount(trans_rec, ErrorCount);
      wait for 0 ns;
      AffirmIfEqual(ErrorCount, i/128, "Receiver, GetErrorCount: Verify that ErrorCount is 0");
    else
      GetAlertLogID(trans_rec, TxAlertLogID);
      ErrorCount := GetAlertCount(TxAlertLogID);
      wait for 0 ns;
      AffirmIfEqual(ErrorCount, i/128, "Receiver, GetAlertLogID/GetAlertCount: Verify that ErrorCount is 0");
    end if;
    if (i mod 32) = 0 then
      -- Verify that no transactions are pending
      CurTime := now;
      WaitForTransaction(trans_rec);
      wait for 0 ns;
      AffirmIfEqual(now, CurTime, "Receiver: WaitForTransaction executes in 0 time when using blocking transactions");
    end if;
  end loop;

  -- Wait for outputs to propagate and signal TestDone
  WaitForClock(trans_rec, 2);
  WaitForBarrier(TestDone);
  wait;
  end process test_process;

end architecture AvalonST_SendTest;
