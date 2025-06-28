library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
context osvvm.OsvvmContext;

use osvvm.ScoreboardPkg_slv.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

entity AvalonStreamReceiver is
  generic (

    INIT_CHANNEL : std_logic_vector := "";
    INIT_EMPTY : std_logic_vector := "";
    INIT_LAST : natural := 0;
    MODEL_ID_NAME : string := "";
    AVALON_STREAM_DATA_WIDTH : integer range 1 to 8192 := 32;
    AVALON_STREAM_WORD_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 32;
    AVALON_STREAM_SYMBOL_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 16;
    AVALON_STREAM_ERROR : integer range 1 to 256 := 1;
    tperiod_Clk : time := 10 ns;
    DEFAULT_DELAY : time := 1 ns;
    tpd_Clk_Ready : time := DEFAULT_DELAY
  );
  port (
    Clk : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid : in std_logic := '0';
    Data : in std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    Ready : out std_logic;

    StartOfPacket : in std_logic := '0';
    EndOfPacket : in std_logic := '0';
    Empty : in std_logic_vector((AVALON_STREAM_DATA_WIDTH/AVALON_STREAM_SYMBOL_WIDTH) - 1 downto 0) := (others => '0');
    Channel : in std_logic_vector(7 downto 0) := (others => '0');
    -- testbench record
    TransRec : inout StreamRecType
  );

  -- Use MODEL_ID_NAME Generic if set, otherwise,
  -- use model instance label (preferred if set as entityname_1)
  constant MODEL_INSTANCE_NAME : string :=
                                          ifelse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME,
                                          to_lower(PathTail(AvalonStreamReceiver'PATH_NAME)));

end AvalonStreamReceiver;

architecture bhv of AvalonStreamReceiver is
  constant CHANNEL_LEN : integer := Channel'length;
  constant EMPTY_LEN : integer := Empty'length;
  constant PARAM_LENGTH : integer := CHANNEL_LEN + EMPTY_LEN + 1;
  constant EMPTY_RIGHT : integer := 1;
  constant CHANNEL_RIGHT : integer := EMPTY_LEN + 1;
  signal ModelID : AlertLogIDType;
  signal DataCheckID : AlertLogIDType;
  signal WordRequestCount, WordReceiveCount : integer := 0;
  signal BurstRequestCount, BurstReceiveCount : integer := 0;
  signal StartOfNewStream : integer := 1;
  signal TimeOutPeriod : time := 0 sec; -- 0 sec means no timeout TODO add to options

  signal ReceiveFifo : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
  signal ReceivedWordsInCurrentBurst, RequestWordsInCurrentBurst : integer := 0;
  -- Verification Component Configuration
  signal WaitForGet : boolean := true;
  signal ReadyLatency : integer := 0;
  signal ReadyAllowance : integer := 0;
  signal ByteOrder : boolean := false; -- big endian is default
  signal PacketTransfer : boolean := false;
  signal BeatsPerCycle : integer := AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_WORD_WIDTH;
  signal WordWidth : integer := AVALON_STREAM_DATA_WIDTH;

  signal LastOffsetCount : integer := 0;
  signal ParamChannel : std_logic_vector(Channel'range) := ifelse(INIT_CHANNEL'length > 0, INIT_CHANNEL, (Channel'range => '0'));
  signal ParamEmpty : std_logic_vector(Empty'range) := ifelse(INIT_EMPTY'length > 0, INIT_EMPTY, (Empty'range => '0'));
  signal ParamLast : natural := INIT_LAST;
  constant DEFAULT_BURST_MODE : StreamFifoBurstModeType := STREAM_BURST_WORD_MODE;
  signal BurstFifoMode : StreamFifoBurstModeType := DEFAULT_BURST_MODE;
  signal BurstFifoByteMode : boolean := (DEFAULT_BURST_MODE = STREAM_BURST_BYTE_MODE);

begin
  ------------------------------------------------------------
  --  Initialize alerts
  ------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
  begin
    -- Alerts
    ID := NewID(MODEL_INSTANCE_NAME);
    ModelID <= ID;
    DataCheckID <= NewID("Data Check", ID);
    ReceiveFifo <= NewID("ReceiveFifo", ID, ReportMode => DISABLED, Search => PRIVATE_NAME);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    alias Operation : StreamOperationType is TransRec.Operation;
    variable Data, ExpectedData : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    variable Param, PopParam, ExpectedParam : std_logic_vector(PARAM_LENGTH - 1 downto 0) := (others => '0');
    variable PopData : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0) := (others => '0');

    variable TryWordWaiting, TryBurstWaiting : boolean := false;
    variable DispatcherReceiveCount : integer := 0;
    variable BurstTransferCount : integer := 0;
    variable WordCount : integer;
    variable FifoWordCount, CheckWordCount : integer;
    variable BurstBoundary : std_logic;
    function param_to_string(Param : std_logic_vector) return string is
      alias aParam : std_logic_vector(Param'length - 1 downto 0) is Param;
      alias aChannel : std_logic_vector(CHANNEL_LEN - 1 downto 0) is aParam(PARAM_LENGTH - 1 downto PARAM_LENGTH - CHANNEL_LEN);
      alias aEmpty : std_logic_vector(EMPTY_LEN - 1 downto 0) is aParam(EMPTY_LEN downto 1);
    begin
      return
      ifelse(CHANNEL_LEN > 0, "  Channel: " & to_hxstring(aChannel), "") &
      ifelse(EMPTY_LEN > 0, "  Empty: " & to_hxstring(aEmpty), "");
    end function param_to_string;
  begin
    wait for 0 ns;
    Log(ModelID, "AvalonStreamReceiver TransactionDispatcher started", INFO);
    TransRec.BurstFifo <= NewID("RxPacketFifo", ModelID, Search => PRIVATE_NAME);

    TransactionDispatcherLoop : loop
      Log(ModelID, "TransactionDispatcher Loop", INFO);
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );
      Log(ModelID, "TransactionDispatcher: Received Transaction", INFO);

      case Operation is
        when GET | TRY_GET | CHECK | TRY_CHECK =>
          if IsEmpty(ReceiveFifo) and IsTry(Operation) then
            if not TryWordWaiting then
              increment(WordRequestCount);
            end if;
            TryWordWaiting := TRUE;
            -- Return if no data
            TransRec.BoolFromModel <= FALSE;
            TransRec.DataFromModel <= (TransRec.DataFromModel'range => '0');
            TransRec.ParamFromModel <= (TransRec.ParamFromModel'range => '0');
            wait for 0 ns;
          else
            if not TryWordWaiting then
              RequestWordsInCurrentBurst <= 1;
              increment(BurstRequestCount);
            end if;
            TryWordWaiting := FALSE;
            DispatcherReceiveCount := DispatcherReceiveCount + 1;

            -- Get data
            TransRec.BoolFromModel <= TRUE;
            -- if IsEmpty(ReceiveFifo) then
            --   -- Wait for data
            --   WaitForToggle(WordReceiveCount);
            -- end if;
            if (BurstReceiveCount - BurstRequestCount) = 0 then
              -- Wait for data
              WaitForToggle(BurstReceiveCount);
            end if;
            -- Put Data and Parameters into record
            (Data, Param, BurstBoundary) := pop(ReceiveFifo);

            -- if BurstBoundary = '1' then
            -- At BurstBoundary, there is always another word that
            -- follows that triggered the Burst Boundary
            (Data, Param, BurstBoundary) := pop(ReceiveFifo);
            -- end if;
            TransRec.DataFromModel <= SafeResize(ModelID, Data, TransRec.DataFromModel'length);
            TransRec.ParamFromModel <= SafeResize(ModelID, Param, TransRec.ParamFromModel'length);

            if IsCheck(Operation) then
              ExpectedData := SafeResize(ModelID, TransRec.DataToModel, ExpectedData'length);
              ExpectedParam := UpdateOptions(
                               Param => SafeResize(ModelID, TransRec.ParamToModel, TransRec.ParamToModel'length),
                               ParamChannel => ParamChannel,
                               ParamEmpty => ParamEmpty, -- used for empty signal
                               ParamLast => 0,
                               Count => WordReceiveCount - LastOffsetCount
                               );
              AffirmIf(DataCheckID,
              --                (Data ?= ExpectedData and Param ?= ExpectedParam) = '1',
              (MetaMatch(Data, ExpectedData) and MetaMatch(Param, ExpectedParam)),
              "Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Received.  Data: " & to_hxstring(Data) & param_to_string(Param),
              " Expected.  Data: " & to_hxstring(ExpectedData) & param_to_string(ExpectedParam),
              TransRec.BoolToModel or IsLogEnabled(ModelID, INFO)
              );
            else
              Log(ModelID,
              "Word Receive. " &
              " Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Data: " & to_hxstring(Data) & param_to_string(Param),
              INFO, TransRec.BoolToModel
              );
            end if;
          end if;
        when GET_BURST | TRY_GET_BURST =>
        Log(ModelID, "GET_BURST and TRY_GET_BURST are not supported in AvalonStreamReceiver", INFO);
          if (BurstReceiveCount - BurstRequestCount) = 0 and IsTry(Operation) then
            if not TryBurstWaiting then
              increment(BurstRequestCount);
            end if;
            TryBurstWaiting := TRUE;
            -- Return if no data
            TransRec.BoolFromModel <= FALSE;
            TransRec.DataFromModel <= (TransRec.DataFromModel'range => '0');
            TransRec.ParamFromModel <= (TransRec.ParamFromModel'range => '0');
            wait for 0 ns;
          else
         
            if not TryBurstWaiting then
              RequestWordsInCurrentBurst <= TransRec.IntToModel;
              increment(BurstRequestCount);
            end if;
            TryBurstWaiting := FALSE;
            DispatcherReceiveCount := DispatcherReceiveCount + 1; -- Operation or #Words Transfered based?

            -- Get data
            TransRec.BoolFromModel <= TRUE;
             
            if (BurstReceiveCount - BurstRequestCount) = 0 then
              -- Wait for data
             
              WaitForToggle(BurstReceiveCount);
            end if;
            FifoWordCount := 0;
            WordCount := 0;

            loop
              (PopData, PopParam, BurstBoundary) := pop(ReceiveFifo);
              -- BurstBoundary indication does not contain data for
              -- this transaction so exit
              exit when BurstBoundary = '1';
              WordCount := WordCount + 1;
              Data(AVALON_STREAM_WORD_WIDTH - 1 downto 0) := PopData(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
              Param := PopParam;
              case BurstFifoMode is
                when STREAM_BURST_BYTE_MODE =>
                  -- PushWord(TransRec.BurstFifo, Data, DropUndriven) ;
                  -- FifoWordCount := FifoWordCount + CountBytes(Data, DropUndriven) ;
                  log("using burst byte mode");
                when STREAM_BURST_WORD_MODE =>
                  Push(TransRec.BurstFifo, Data(AVALON_STREAM_WORD_WIDTH - 1 downto 0));
                  FifoWordCount := FifoWordCount + 1;

                when STREAM_BURST_WORD_PARAM_MODE =>
                  -- Push(TransRec.BurstFifo, Data & Param(USER_LEN downto 1)) ;
                  -- FifoWordCount := FifoWordCount + 1 ;
                  log("using burst word param mode");
                when others =>
                  Alert(ModelID, "BurstFifoMode: Invalid Mode: " & to_string(BurstFifoMode));
              end case;
              exit when Param(0) = '1';
            end loop;

            -- Adjust WordRequestCount for the number of words consumed during the burst
            WordRequestCount <= Increment(WordRequestCount, WordCount);

            BurstTransferCount := BurstTransferCount + 1;
            TransRec.IntFromModel <= FifoWordCount;
            TransRec.DataFromModel <= SafeResize(ModelID, Data, TransRec.DataFromModel'length);
            TransRec.ParamFromModel <= SafeResize(ModelID, Param, TransRec.ParamFromModel'length);

            Log(ModelID,
            "Burst Receive. " &
            " Operation# " & to_string (DispatcherReceiveCount) & " " &
            " Last Data: " & to_hxstring(Data) & param_to_string(Param),
            INFO, TransRec.BoolToModel or IsLogEnabled(ModelID, PASSED)
            );
            wait for 0 ns;
          end if;
        when CHECK_BURST | TRY_CHECK_BURST =>
          if (BurstReceiveCount - BurstRequestCount) = 0 and IsTry(Operation) then
            if not TryBurstWaiting then
              increment(BurstRequestCount);
            end if;
            TryBurstWaiting := TRUE;
            -- Return if no data
            TransRec.BoolFromModel <= FALSE;
            TransRec.DataFromModel <= (TransRec.DataFromModel'range => '0');
            TransRec.ParamFromModel <= (TransRec.ParamFromModel'range => '0');
            wait for 0 ns;
          else
            if not TryBurstWaiting then
              RequestWordsInCurrentBurst <= TransRec.IntToModel;
              increment(BurstRequestCount);
            end if;
            TryBurstWaiting := FALSE;
            DispatcherReceiveCount := DispatcherReceiveCount + 1;
            -- Get data
            TransRec.BoolFromModel <= TRUE;
            if (BurstReceiveCount - BurstRequestCount) = 0 then
              -- Wait for data
              WaitForToggle(BurstReceiveCount);
            end if;
            CheckWordCount := TransRec.IntToModel;
            FifoWordCount := 0;
            WordCount := 0;
            loop
              (PopData, PopParam, BurstBoundary) := pop(ReceiveFifo);
              -- BurstBoundary indication does not contain data for
              -- this transaction so exit
              exit when BurstBoundary = '1';
              WordCount := WordCount + 1;
              Data(AVALON_STREAM_WORD_WIDTH - 1 downto 0) := PopData(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
              Param := PopParam;
              case BurstFifoMode is
                when STREAM_BURST_BYTE_MODE =>
                  -- todo
                  -- CheckWord(TransRec.BurstFifo, Data, DropUndriven);
                  -- FifoWordCount := FifoWordCount + CountBytes(Data, DropUndriven);

                when STREAM_BURST_WORD_MODE =>
                  Check(TransRec.BurstFifo, Data);
                  FifoWordCount := FifoWordCount + 1;

                when STREAM_BURST_WORD_PARAM_MODE =>
                  -- todo
                  -- Checking done here to differentiate data from user
                  -- (ExpectedData, ExpectedUser) := Pop(TransRec.BurstFifo);
                  -- AffirmIfEqual(BurstFifoID, Data, ExpectedData, "Data");
                  -- AffirmIfEqual(BurstFifoID, Param(USER_LEN downto 1), ExpectedUser, "User");
                  -- --                Check(TransRec.BurstFifo, Data & Param(USER_LEN downto 1)) ;
                  -- FifoWordCount := FifoWordCount + 1;

                when others =>
                  Alert(ModelID, "BurstFifoMode: Invalid Mode: " & to_string(BurstFifoMode));
              end case;
              exit when Param(0) = '1';
              exit when FifoWordCount >= CheckWordCount;
            end loop;
            if (FifoWordCount = CheckWordCount) then
              -- there should be a burst boundary now -> consume it
              (PopData, PopParam, BurstBoundary) := pop(ReceiveFifo);
            end if;
            --   if (BurstBoundary = '0') then
            --     Alert(ModelID, "Expected BurstBoundary = 1", FAILURE);
            --   end if;
            -- end if;

            -- Adjust WordRequestCount for the number of words consumed during the burst
            WordRequestCount <= Increment(WordRequestCount, WordCount);

            BurstTransferCount := BurstTransferCount + 1;
            TransRec.IntFromModel <= FifoWordCount;
            TransRec.DataFromModel <= SafeResize(ModelID, Data, TransRec.DataFromModel'length);
            TransRec.ParamFromModel <= SafeResize(ModelID, Param, TransRec.ParamFromModel'length);

            Log(ModelID,
            "Burst Check. " &
            " Operation# " & to_string (DispatcherReceiveCount) & " " &
            " Last Data: " & to_hxstring(Data) & param_to_string(Param),
            INFO, TransRec.BoolToModel or IsLogEnabled(ModelID, PASSED)
            );
            if not (BurstBoundary = '1') then
              Log(ModelID,
              "Burst Check finished without Last or BurstBoundary - normal when next word is burst boundary",
              DEBUG
              );
            end if;
            AffirmIfEqual(ModelID, FifoWordCount, CheckWordCount, "Burst Check WordCount");
            ExpectedParam := UpdateOptions(
                             Param => SafeResize(ModelID, TransRec.ParamToModel, TransRec.ParamToModel'length),
                             ParamChannel => ParamChannel,
                             ParamEmpty => ParamEmpty, -- used for empty signal
                             ParamLast => 0,
                             Count => 0
                             );
            if CHANNEL_LEN > 0 then
              AffirmIfEqual(ModelID, Param(CHANNEL_RIGHT + CHANNEL_LEN - 1 downto CHANNEL_RIGHT),
              ExpectedParam(CHANNEL_RIGHT + CHANNEL_LEN - 1 downto CHANNEL_RIGHT), "Channel");
            end if;
            if EMPTY_LEN > 0 then
              AffirmIfEqual(ModelID, Param(EMPTY_RIGHT + EMPTY_LEN - 1 downto EMPTY_RIGHT),
              ExpectedParam(EMPTY_RIGHT + EMPTY_LEN - 1 downto EMPTY_RIGHT), "Empty");
            end if;
            --AffirmIfEqual(ModelID, Param(0) or BurstBoundary, ExpectedParam(0), "Last");

            wait for 0 ns;
          end if;
        when WAIT_FOR_TRANSACTION =>
          if (WordReceiveCount /= WordRequestCount) then
            wait until WordReceiveCount = WordRequestCount;
          end if;
          if (BurstRequestCount /= BurstReceiveCount) then
            wait until BurstRequestCount = BurstReceiveCount;
          end if;
        when WAIT_FOR_CLOCK =>
          WaitForClock(Clk, TransRec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          --!! This is GetTotalTransactionCount vs. GetPendingTransactionCount
          --!!  Get Pending Get Count = GetFifoCount(PacketFifo)
          TransRec.IntFromModel <= WordReceiveCount;

        when SET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is

            when PACKET_TRANSFER =>
              PacketTransfer <= TransRec.BoolToModel;
              wait for 0 ns;
              if (PacketTransfer = true) then
                Log(ModelID, "Packet Transfer set to true", INFO);
              else
                Log(ModelID, "Packet Transfer set to false", INFO);
              end if;
            when BYTE_ORDER =>
              ByteOrder <= TransRec.BoolToModel;
              if (ByteOrder = true) then
                Log(ModelID, "Byte Order set to Little Endian", INFO);
              else
                Log(ModelID, "Byte Order set to Big Endian", INFO);
              end if;
            when READY_ALLOWANCE =>
              if (TransRec.IntToModel < ReadyLatency) then
                AlertIf(ModelID, TransRec.IntToModel < ReadyLatency,
                "ReadyAllowance must be greater than or equal to ReadyLatency - set to ReadyLatency now!", WARNING);
                ReadyAllowance <= ReadyLatency;
              else
                ReadyAllowance <= TransRec.IntToModel;
              end if;
              Log(ModelID, "Setting AvalonStream Receiver Ready_Allowance to " & to_string(TransRec.IntToModel), INFO);
            when READY_LATENCY =>
              ReadyLatency <= TransRec.IntToModel;
            when SET_BURST_MODE =>
              BurstFifoMode <= TransRec.IntToModel;
              BurstFifoByteMode <= (TransRec.IntToModel = STREAM_BURST_BYTE_MODE);
            when DEFAULT_CHANNEL =>
              ParamChannel <= SafeResize(ModelID, TransRec.ParamToModel, ParamChannel'length);

            when DEFAULT_EMPTY =>
              ParamEmpty <= SafeResize(ModelID, TransRec.ParamToModel, ParamEmpty'length);

            when DEFAULT_LAST =>
              ParamLast <= TransRec.IntToModel;
              LastOffsetCount <= WordReceiveCount;

            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
          wait for 0 ns;
        when GET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when DEFAULT_CHANNEL =>
              TransRec.ParamFromModel <= SafeResize(ModelID, ParamChannel, TransRec.ParamFromModel'length);
            when PACKET_TRANSFER =>
              TransRec.BoolFromModel <= PacketTransfer;
            when BYTE_ORDER =>
              TransRec.BoolFromModel <= ByteOrder;
            when READY_ALLOWANCE =>
              TransRec.IntFromModel <= ReadyAllowance;
            when READY_LATENCY =>
              TransRec.IntFromModel <= ReadyLatency;
            when GET_BURST_MODE =>
              TransRec.IntFromModel <= BurstFifoMode;
            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record. Transaction # " & to_string(TransRec.Rdy), FAILURE);

        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(TransRec.Operation), FAILURE);
      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  ReceiveHandler : process
    variable vData : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    variable vParam : std_logic_vector(PARAM_LENGTH - 1 downto 0) := (others => '0');
    variable vChannel : std_logic_vector(Channel'range) := (Channel'range => '0');
    variable vEmpty : std_logic_vector(Empty'range) := (Empty'range => '0');
    variable PushData : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0) := (others => '0');
    variable ReadyBeforeValid : boolean := false;
    variable ReadyDelayCycles : integer := 0;
  begin
    -- Initialize
    Ready <= '0';
    wait for 0 ns;
    wait for 0 ns; -- ensure that the scoreboards are initialized.

    --WaitForBarrier(OsvvmVcInit);
    ReceiveLoop : loop
      if WaitForGet then
        -- if no request, wait until we have one
        if not ((BurstRequestCount > BurstReceiveCount)) then
          Log(ModelID, "ReceiveHandler: Waiting for Get Request", INFO);
          wait until (BurstRequestCount > BurstReceiveCount) or not WaitForGet;
          Log(ModelID, "ReceiveHandler: Get Request received", INFO);
          -- push(ReceiveFifo, vData & vParam & '1'); -- marks the start of the burst
        end if;
      end if;

      if BurstReceiveCount < BurstRequestCount and PacketTransfer then
        -- Packet Mode
        -- start of procedure
        loop
          Ready <= '1' after tpd_Clk_Ready;

          if TimeOutPeriod > 0 sec then
            wait on Clk until Clk = '1' and Valid = '1' and StartOfPacket = '1' for TimeOutPeriod;
          else
            wait on Clk until Clk = '1' and Valid = '1' and StartOfPacket = '1';
          end if;
          -- start of packet
          vData := Data;
          vChannel := Channel;
          vEmpty := Empty;
          vParam := vChannel & vEmpty & '0'; -- 0 is wildcard
          push(ReceiveFifo, vData & vParam & '0'); -- 0 is not last

          Log(ModelID, "PacketTransfer: Received Word: " & to_hxstring(vData), INFO);
          exit when Valid = '1' and StartOfPacket = '1';
        end loop;
        loop
          -- in packet
          Ready <= '1' after tpd_Clk_Ready;

          if TimeOutPeriod > 0 sec then
            wait on Clk until Clk = '1' and Valid = '1' for TimeOutPeriod;
          else
            wait on Clk until Clk = '1' and Valid = '1';
          end if;

          if Valid = '1' then
            vData := Data;
            vChannel := Channel;
            vEmpty := Empty;
            vParam := vChannel & vEmpty & '0'; -- 0 is wildcard
            push(ReceiveFifo, vData & vParam & '0'); -- 0 is not last
            Log(ModelID, "PacketTransfer: Received Word: " & to_hxstring(vData), INFO);
            exit when EndOfPacket = '1';
          else
            Alert(ModelID, " Valid: " & to_string(Valid) & "  Expected: 1", FAILURE);
          end if;
        end loop;
        Ready <= '0' after tpd_Clk_Ready;
        -- packet received
        -- push burst boundary
        push(ReceiveFifo, vData & vParam & '1'); -- marks the end of the burst

        -- end of procedure!
        increment(BurstReceiveCount);
        wait for 0 ns;

      elsif BurstReceiveCount < BurstRequestCount and not PacketTransfer then
        -- normal receive mode
        DoAvalonStreamReadyHandshake(
        Clk => Clk,
        Valid => Valid,
        Ready => Ready,
        StartOfNewStream => StartOfNewStream,
        WordRequestCount => RequestWordsInCurrentBurst,
        WordReceiveCount => ReceivedWordsInCurrentBurst,
        ReadyAllowance => ReadyAllowance,
        ReadyBeforeValid => ReadyBeforeValid,
        ReadyDelayCycles => ReadyDelayCycles * tperiod_Clk,
        tpd_Clk_Ready => tpd_Clk_Ready,
        AlertLogID => ModelID
        );
        vData := Data;
        vChannel := Channel;
        vEmpty := Empty;
        vParam := vChannel & vEmpty & '0'; -- 0 is wildcard
        if (ByteOrder = true) then
          ReverseSymbolOrder(vData, AVALON_STREAM_SYMBOL_WIDTH, AVALON_STREAM_WORD_WIDTH);
        end if;
       
        case BurstFifoMode is
          when STREAM_BURST_BYTE_MODE =>
            -- todo
            -- PushWord(TransRec.BurstFifo, vData, DropUndriven) ;
            -- ReceivedWordsInCurrentBurst <= ReceivedWordsInCurrentBurst + CountBytes(vData, DropUndriven) ;
            log("using burst byte mode");
          when STREAM_BURST_WORD_MODE =>

            if BeatsPerCycle = 0 then
              Log(ModelID,
              "Received Word: " & to_hxstring(vData), INFO);
              push(ReceiveFifo, vData & vParam & '0');
            else
              log("pushing beats per cycle: " & to_string(BeatsPerCycle));
              for j in 0 to BeatsPerCycle - 1 loop
                PushData := vData((j + 1) * AVALON_STREAM_WORD_WIDTH - 1 downto j * AVALON_STREAM_WORD_WIDTH);
                push(ReceiveFifo, PushData & vParam & '0');
              end loop;
            end if;
          when STREAM_BURST_WORD_PARAM_MODE =>
            -- todo
            -- Push(TransRec.BurstFifo, vData & vParam(USER_LEN downto 1)) ;
            -- ReceivedWordsInCurrentBurst <= ReceivedWordsInCurrentBurst + 1 ;
            log("using burst word param mode");
          when others =>
            Alert(ModelID, "BurstFifoMode: Invalid Mode: " & to_string(BurstFifoMode));
        end case;

        ReceivedWordsInCurrentBurst <= ReceivedWordsInCurrentBurst + BeatsPerCycle; -- todo here aswell
        wait for 0 ns;
        log("received " & to_string(ReceivedWordsInCurrentBurst));
        if (ReceivedWordsInCurrentBurst = RequestWordsInCurrentBurst) then -- todo subtract empty, doesn't have to fit
          StartOfNewStream <= 1;
          BurstReceiveCount <= BurstReceiveCount + 1;
          Ready <= '0' after tpd_Clk_Ready; -- end of burst
          push(ReceiveFifo, PushData & vParam & '1'); -- marks the end of the burst 
        elsif (ReceivedWordsInCurrentBurst > RequestWordsInCurrentBurst) then
          wait for 10 ns;
          Alert(ModelID, "ReceivedWordsInCurrentBurst > RequestWordsInCurrentBurst: " &
          to_string(ReceivedWordsInCurrentBurst) & " > " & to_string(RequestWordsInCurrentBurst), FAILURE);
        end if;
      else
        wait for 10 ns;
        Alert(ModelID, "AvalonStreamReceiver: No Word or Packet request was received!", FAILURE);
      end if;
    end loop ReceiveLoop;
  end process ReceiveHandler;
end bhv;