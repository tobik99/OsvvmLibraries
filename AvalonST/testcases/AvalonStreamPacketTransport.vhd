library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;


architecture PacketTransport of AvalonST_TestCtrl is

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
  variable ExpData : slv_array_t(0 to 9)(31 downto 0) := (
    "00000000000000000000000000000001", -- 1
    "00000000000000000000000000000010", -- 2
    "00000000000000000000000000000011", -- 3
    "00000000000000000000000000000100", -- 4
    "00000000000000000000000000000101", -- 5
    "00000000000000000000000000000110", -- 6
    "00000000000000000000000000000111", -- 7
    "00000000000000000000000000001000", -- 8
    "00000000000000000000000000001001", -- 9
    "00000000000000000000000000001010"  -- 10
);
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamTxRec, PACKET_TRANSFER, TRUE);
    SetAvalonStreamOptions(StreamTxRec, PACKET_LAST_WORD_EMPTY, 1); -- use the empty signal for the last word in packet
    wait for 10 ns;
    for i in ExpData'range loop
      push(TxPacketFifo, ExpData(i));
    end loop;
    SendPacket(StreamTxRec, ExpData'length);

    wait for 150 ns;
    --WaitForTransaction(StreamTxRec);
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
    variable ExpData : slv_array_t(0 to 9)(31 downto 0) := (
      "00000000000000000000000000000001", -- 1
      "00000000000000000000000000000010", -- 2
      "00000000000000000000000000000011", -- 3
      "00000000000000000000000000000100", -- 4
      "00000000000000000000000000000101", -- 5
      "00000000000000000000000000000110", -- 6
      "00000000000000000000000000000111", -- 7
      "00000000000000000000000000001000", -- 8
      "00000000000000000000000000001001", -- 9
      "00000000000000000000000000001010"  -- 10
  );
    
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamRxRec, PACKET_TRANSFER, true);
    wait for 10 ns;
    --WaitForBarrier(SyncPoint);

    ReceivePacket(StreamRxRec);
   wait for 150 ns;
  
  -- packet can also be checked this way:
  -- GetPacket(StreamRxRec, PacketLength);
  --  for i in 0 to PacketLength - 1 loop
  --   PacketWord := pop(RxPacketFifo);
  --   Log("PacketWord: " & to_string(PacketWord), INFO, TRUE);
  --   AffirmIf(PacketWord = ExpData(i), "Data: " & to_string(PacketWord) & " /= Expected: " & to_string(ExpData(i)));
  --  end loop;
    CheckPacket(StreamRxRec, ExpData);
    GetAvalonStreamOptions(StreamRxRec, PACKET_LAST_WORD_EMPTY, LastWordEmpty);
    AffirmIf(LastWordEmpty = 1, "LastWordEmpty is correctly set to 1");
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture PacketTransport;

configuration AvalonStreamPacketTransport of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(PacketTransport);
    end for;
  end for;
end AvalonStreamPacketTransport;
