library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;


architecture BeatsPerCycle of AvalonST_TestCtrl is

  signal TestDone  : integer_barrier := 1;
  signal SyncPoint : integer_barrier := 1;
  signal RxData    : std_logic_vector(31 downto 0);
  signal TxOptions : AvalonStreamOptionsType;
  signal ExpData : slv_array_t(0 to 11)(31 downto 0) := (
    "00000000000000000000000000000001", -- 1
    "00000000000000000000000000000010", -- 2
    "00000000000000000000000000000011", -- 3
    "00000000000000000000000000000100", -- 4
    "00000000000000000000000000000101", -- 5
    "00000000000000000000000000000110", -- 6
    "00000000000000000000000000000111", -- 7
    "00000000000000000000000000001000", -- 8
    "00000000000000000000000000001001", -- 9
    "00000000000000000000000000001010",  -- 10
    "00000000000000000000000000001011",  -- 11
    "00000000000000000000000000001100"  -- 12
);
begin

  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("AvalonStreamPacketTransport");
    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO, TRUE);

    wait for 0 ns;
    wait for 0 ns;

    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 1000 ns);
    AlertIf(now >= 1000 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    wait for 0 ns;
    std.env.stop;
  end process;

  ------------------------------------------------------------
  -- Transmitter Process
  ------------------------------------------------------------
  transmitter_proc : process
  
  begin
    wait until Reset = '1';
    wait for 0 ns;

    SetAvalonStreamOptions(StreamTxRec, BEATS_PER_CYCLE, 4);
    wait for 10 ns;
    SendAsync(StreamTxRec, ExpData, 12);
    wait for 100 ns;
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable Available : boolean := false;
    variable PacketLength, LastWordEmpty : integer := 0;
    variable PacketWord : std_logic_vector(31 downto 0);

    
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamRxRec, BEATS_PER_CYCLE, 2);
    wait for 10 ns;
   
    Receive(StreamRxRec, 12);
     wait for 100 ns;
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture BeatsPerCycle;

configuration AvalonStreamBeatsPerCycle of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(BeatsPerCycle);
    end for;
  end for;
end AvalonStreamBeatsPerCycle;
