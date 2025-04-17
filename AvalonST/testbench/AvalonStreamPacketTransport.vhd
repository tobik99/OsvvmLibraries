library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;


architecture AvalonStreamPacketTransport of AvalonST_TestCtrl is

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
    SetTestName("AvalonStreamByteOrderSymbolWidth");
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
    
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamRxRec, PACKET_TRANSFER, true);
    wait for 10 ns;
    --WaitForBarrier(SyncPoint);

    ReceivePacket(StreamRxRec);
   wait for 150 ns;
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture AvalonStreamPacketTransport;
