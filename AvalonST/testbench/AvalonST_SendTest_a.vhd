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

  constant clk_period : time := 10 ns;

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
  begin
    -- Send data using AvalonStreamSend procedure
    --for i in 0 to 255 loop
    o_ready <= '1';
    wait for 10 ns;
    SEND(io_trans_rec, std_logic_vector(to_unsigned(13, 32)));
    wait for clk_period;
    --end loop;

    -- Check if data is sent correctly
    if data = expected_data then
      report "Data sent correctly: " & to_hstring(data);
    else
      report "Data sent incorrectly: " & to_hstring(data) severity error;
    end if;
    -- End simulation
    wait for clk_period * 10;
    std.env.stop;
  end process test_process;

end architecture AvalonST_SendTest;
