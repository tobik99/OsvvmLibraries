 
architecture AvalonStreamSetOptions of AvalonST_TestCtrl is

  signal TestDone : integer_barrier := 1;
  constant MAX_LEN : integer := maximum(CHANNEL_LEN, EMPTY_LEN);
  constant DASH : std_logic_vector(MAX_LEN - 1 downto 0) := (others => '-');
  constant cAvalonStreamDataWidth : integer := 32;
  constant cNumOfWords : integer := 2;
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("AvalonStreamSetOptions");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE); -- Enable INFO logs
    SetLogEnable(DEBUG, TRUE); -- Enable INFO logs

    -- Wait for testbench initialization 
    wait for 0 ns;
    wait for 0 ns;
    -- TranscriptOpen;
    -- SetTranscriptMirror(TRUE);

    -- Wait for Design Reset
    wait until Reset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, 1000 ns);
    AlertIf(now >= 1000 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    std.env.finish;
    wait;
  end process ControlProc;
  ------------------------------------------------------------
  -- AvalonStreamTransmitterProc
  --   Generate transactions for AvalonStreamTransmitter
  ------------------------------------------------------------
  AvalonStreamTransmitterProc : process
    variable Data : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0);
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0);
    variable SendNumWords : integer := 2;
    variable TxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN - 1 downto 0);
    variable tx_byte_data : slv_vector(0 to 7)(7 downto 0);
    variable tx_data : slv_vector(0 to 7)(31 downto 0);
  begin
    wait until Reset = '1';
    tx_byte_data := (0 => X"12", 1 => X"34", 2 => X"56", 3 => X"78", 4 => X"90", 5 => X"12", 6 => X"34", 7 => X"56", others => (others => '0'));
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (others => '1');
    TxParam := (Channel) & (Empty);
    SetAvalonStreamOptions(StreamTxRec, DEFAULT_CHANNEL, Channel);
    SetAvalonStreamOptions(StreamTxRec, PACKET_TRANSFER, true);
    SetAvalonStreamOptions(StreamTxRec, SYMBOL_ORDER, false);
    SetBurstMode(StreamTxRec, STREAM_BURST_BYTE_MODE);
    wait for 10 ns;
    for i in 0 to 7 loop
      push(StreamTxRec.BurstFifo, tx_byte_data(i));
    end loop;
    SendBurst(StreamTxRec, 8, TxParam);
    wait for 20 ns;
    -- send/check burst with param mode
    SetBurstMode(StreamTxRec, STREAM_BURST_WORD_PARAM_MODE);
    tx_data := (0 => X"12345678", 1 => X"90ABCDEF", 2 => X"12345678", 3 => X"90ABCDEF",
                4 => X"12345678", 5 => X"90ABCDEF", 6 => X"12345678", 7 => X"90ABCDEF", others => (others => '0'));
    for i in 0 to 7 loop
      Push(StreamTxRec.BurstFifo, tx_data(i) & TxParam);
    end loop;
    SendBurst(StreamTxRec, 8);
    WaitForBarrier(TestDone);
    wait;
  end process AvalonStreamTransmitterProc;
  ------------------------------------------------------------
  -- AvalonStreamReceiverProc
  --   Generate transactions for AvalonStreamReceiver
  ------------------------------------------------------------
  AvalonStreamReceiverProc : process
    variable RxData : std_logic_vector(8 - 1 downto 0) := (others => '0');
    variable ReceivedWords : integer := 8;
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0);
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0);
    variable rx_byte_data : slv_vector(0 to 7)(7 downto 0);
    variable rx_data : slv_vector(0 to 7)(31 downto 0);
    variable Param, RxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN - 1 downto 0);
  begin
    wait until Reset = '1';
    rx_byte_data := (0 => X"12", 1 => X"34", 2 => X"56", 3 => X"78", 4 => X"90", 5 => X"12", 6 => X"34", 7 => X"56", others => (others => '0'));
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (others => '1');
    Param := (Channel) & (Empty);

    SetBurstMode(StreamRxRec, STREAM_BURST_BYTE_MODE);
    SetAvalonStreamOptions(StreamRxRec, SYMBOL_ORDER, true);
    SetAvalonStreamOptions(StreamRxRec, PACKET_TRANSFER, true);
    wait for 10 ns;
    GetBurst(StreamRxRec, ReceivedWords, RxParam);
    AffirmIfEqual(ReceivedWords, 8);
    AffirmIfEqual(RxParam, Param, "Param Channel & Empty");
    for i in 0 to 7 loop
      RxData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxData, rx_byte_data(i), "RxData matches expected data at index " & integer'image(i));
    end loop;
    wait for 60 ns;
     -- send/check burst with param mode
    SetBurstMode(StreamRxRec, STREAM_BURST_WORD_PARAM_MODE);
    rx_data := (0 => X"12345678", 1 => X"90ABCDEF", 2 => X"12345678", 3 => X"90ABCDEF",
                4 => X"12345678", 5 => X"90ABCDEF", 6 => X"12345678", 7 => X"90ABCDEF", others => (others => '0'));
    for i in 0 to 7 loop
      Push(StreamRxRec.BurstFifo, rx_data(i) & Param);
    end loop;
    CheckBurst(StreamRxRec, 8, Param);

    WaitForBarrier(TestDone);
    wait;
  end process AvalonStreamReceiverProc;

end AvalonStreamSetOptions;

configuration AvalonStreamSetOptions of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(AvalonStreamSetOptions);
    end for;
  end for;
end AvalonStreamSetOptions;