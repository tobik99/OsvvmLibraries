library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture BeatsSymbolOrder of AvalonST_TestCtrl is
  signal TestDone                 : integer_barrier := 1;
  signal C_NUM_WORDS              : integer         := 4;
  constant cAvalonStreamWordWidth : integer         := 16;
begin

  ------------------------------------------------------------
  -- ControlProc
  ------------------------------------------------------------
  ControlProc : process
  begin
    SetTestName("AvalonStreamBeatsPerCycle");
    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO, TRUE);

    wait for 0 ns;
    wait for 0 ns;

    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 200 ns);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.stop;
  end process;

  ------------------------------------------------------------
  -- Transmitter Process
  ------------------------------------------------------------
  transmitter_proc : process
    variable CheckDataWord : std_logic_vector(31 downto 0);
  begin
    wait until Reset = '1';
    -- SendBurst and GetBurst    
    log("Send 4 word burst");

    SetBurstMode(StreamTxRec, STREAM_BURST_BYTE_MODE);
    SendBurstVector(StreamTxRec, (X"12", X"34", X"56", X"78", X"90", X"12", X"34", X"56"));
    SetAvalonStreamOptions(StreamTxRec, SYMBOL_ORDER, false);
    --WaitForClock(StreamTxRec, 3);
    SendBurstVector(StreamTxRec, (X"12", X"34", X"56", X"78", X"90", X"12", X"34", X"56"));
    WaitForClock(StreamTxRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable RxData        : std_logic_vector(31 downto 0);
    variable NumBytes      : integer := 4;
    variable CheckDataWord : std_logic_vector(31 downto 0);
    variable rx_byte_data  : slv_array_t(0 to (C_NUM_WORDS * (cAvalonStreamWordWidth / 8)) - 1)(7 downto 0);
    variable RxByteData    : std_logic_vector(7 downto 0);
    variable receiveWords  : integer := C_NUM_WORDS; -- Number of words to receive
  begin
    wait until Reset = '1';
    SetBurstMode(StreamRxRec, STREAM_BURST_BYTE_MODE);
    SetAvalonStreamOptions(StreamRxRec, SYMBOL_ORDER, false);
    rx_byte_data := (0 => X"12", 1 => X"34", 2 => X"56", 3 => X"78", 4 => X"90", 5 => X"12", 6 => X"34", 7 => X"56", others => (others => '0'));

    receiveWords := 8; -- 4 data words, each split into 2 symbols = 8 Bytes to expect.
    GetBurst(StreamRxRec, receiveWords);
    AffirmIfEqual(receiveWords, 8, "Bytes");
    for i in 0 to (C_NUM_WORDS * (cAvalonStreamWordWidth / 8)) - 1 loop
      RxByteData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxByteData, rx_byte_data(i), "RxData matches expected data at index " & integer'image(i));
    end loop;

    SetAvalonStreamOptions(StreamRxRec, SYMBOL_ORDER, true);

    receiveWords := 8; -- 4 data words, each split into 2 symbols = 8 Bytes to expect.
    GetBurst(StreamRxRec, receiveWords);

    AffirmIfEqual(receiveWords, 8, "Bytes");
    for i in 0 to (C_NUM_WORDS * (cAvalonStreamWordWidth / 8)) - 1 loop
      RxByteData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxByteData, rx_byte_data(i), "RxData matches expected data at index " & integer'image(i));
    end loop;
    WaitForBarrier(TestDone);
    wait;
  end process receiver_proc;

end architecture BeatsSymbolOrder;

configuration AvalonStreamBeatsSymbolOrder of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(BeatsSymbolOrder);
    end for;
  end for;
end AvalonStreamBeatsSymbolOrder;
