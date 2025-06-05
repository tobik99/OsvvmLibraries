library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

architecture PacketTransport of AvalonST_TestCtrl is

  signal scoreboard : ScoreboardIDType;
  signal TestDone : integer_barrier := 1;
  signal ExpData : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  signal SendData : std_logic_vector(31 downto 0) := x"00000000";
  signal SendDataArray : slv_vector(0 to 1)(31 downto 0) := (
    x"10011001", -- 1st data
    x"F00FF00F" -- 2nd data
  );
  constant MAX_LEN : integer := maximum(CHANNEL_LEN, EMPTY_LEN);

  signal getWords : integer := 2; -- Number of words to get from the receiver

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

    WaitForBarrier(TestDone, 200 ns);
    AlertIf(now >= 200 ns, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports;
    wait for 0 ns;
    std.env.stop;
  end process;

  ------------------------------------------------------------
  -- Transmitter Process
  ------------------------------------------------------------
  transmitter_proc : process
    variable NumBytes : integer := 5;
    variable CheckDataWord : std_logic_vector(31 downto 0);
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0); -- 8
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0); -- 4
    variable Param, RxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN + 1 - 1 downto 0);
    variable Wildcard : std_logic := '0';
  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamTxRec, PACKET_TRANSFER, TRUE);
    WaitForClock(StreamTxRec, 2);
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (0 => '1', others => '0');
    Param := (Channel) & (Empty) & Wildcard;
    wait for 10 ns;
    -- SendBurst and GetBurst    
    log("Send 5 word burst");
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop
      Push(StreamTxRec.BurstFifo, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)));
    end loop;
    SendBurst(StreamTxRec, 5, Param);

    WaitForBarrier(TestDone);
    wait;
  end process transmitter_proc;

  ------------------------------------------------------------
  -- Receiver Process
  ------------------------------------------------------------
  receiver_proc : process
    variable RxData : std_logic_vector(31 downto 0);
    variable NumBytes : integer := 5;

    variable CheckDataWord : std_logic_vector(31 downto 0);
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0); -- 8
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0); -- 4
    variable Wildcard : std_logic := '0';
    variable Param, RxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN + 1 - 1 downto 0);

  begin
    wait until Reset = '1';
    wait for 0 ns;
    SetAvalonStreamOptions(StreamRxRec, PACKET_TRANSFER, true);
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (0 => '1', others => '0');

    Param := (Channel) & (Empty) & Wildcard;
    wait for 10 ns;

    log("Get 5 word burst");
    GetBurst(StreamRxRec, NumBytes, RxParam);
    AffirmIfEqual(NumBytes, 5, "Receiver: 5 Received");
    -- check channel and empty parameters
    AffirmIfEqual(RxParam(Param'length - 1 downto EMPTY_LEN + 1), Channel, "Receiver: Channel Param");
    AffirmIfEqual(RxParam(EMPTY_LEN downto 1), Empty, "Receiver: Empty Param");
    CheckDataWord := x"0000_2000";
    for I in 1 to 5 loop
      RxData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxData, std_logic_vector(unsigned(CheckDataWord) + to_unsigned(I, CheckDataWord'length)), "RxData");
    end loop;

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