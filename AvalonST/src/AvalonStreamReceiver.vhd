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
    MODEL_ID_NAME              : string                                      := "";
    AVALON_STREAM_DATA_WIDTH   : integer range 1 to 8192                     := 32;
    AVALON_STREAM_WORD_WIDTH   : integer range 1 to AVALON_STREAM_DATA_WIDTH := 32;
    AVALON_STREAM_SYMBOL_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 16;
    AVALON_STREAM_CHANNELS     : integer range 1 to 128                      := 1;
    AVALON_STREAM_ERROR        : integer range 1 to 256                      := 1;
    tperiod_Clk                : time                                        := 10 ns;
    DEFAULT_DELAY              : time                                        := 1 ns;
    tpd_Clk_oReady             : time                                        := DEFAULT_DELAY
  );
  port (
    Clk   : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid : in std_logic := '0';
    Data  : in std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    Ready : out std_logic;

    StartOfPacket : in std_logic                                                                            := '0';
    EndOfPacket   : in std_logic                                                                            := '0';
    Empty         : in std_logic_vector((AVALON_STREAM_DATA_WIDTH/AVALON_STREAM_SYMBOL_WIDTH) - 1 downto 0) := (others => '0');

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
  signal ModelID                                : AlertLogIDType;
  signal DataCheckID                            : AlertLogIDType;
  signal WordRequestCount, WordReceiveCount     : integer := 0;
  signal PacketRequestCount, PacketReceiveCount : integer := 0;
  signal PacketWordLength                       : integer := 0;
  signal StartOfNewStream                       : integer := 1;
  signal PacketLastWordEmpty                    : integer := 0;
  -- Verification Component Configuration
  signal WaitForGet     : boolean := true;
  signal ReadyLatency   : integer := 0;
  signal ReadyAllowance : integer := 0;
  signal ByteOrder      : boolean := false; -- big endian is default
  signal PacketTransfer : boolean := false;
  signal BeatsPerCycle  : integer := 1;
  signal WordWidth      : integer := AVALON_STREAM_DATA_WIDTH;

begin
  ------------------------------------------------------------
  --  Initialize alerts
  ------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
  begin
    -- Alerts
    ID := NewID(MODEL_INSTANCE_NAME);
    ModelID     <= ID;
    DataCheckID <= NewID("Data Check", ID);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    alias Operation                 : StreamOperationType is TransRec.Operation;
    variable DispatcherReceiveCount : integer := 0;
    variable TryWordWaiting         : boolean;
    variable vData    : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    variable ExpectedData : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
  begin
    wait for 0 ns;
    TransRec.BurstFifo    <= NewID("RxPacketFifo", ModelID, Search   => PRIVATE_NAME);
    TransRec.TransmitFifo <= NewID("RxTransmitFifo", ModelID, Search => PRIVATE_NAME);

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );

      case Operation is
        when GET | TRY_GET =>
          if IsEmpty(TransRec.TransmitFifo) and IsTry(Operation) then
            if not TryWordWaiting then
              increment(WordRequestCount);
            end if;
            TryWordWaiting := TRUE;
            -- Return if no data
            TransRec.BoolFromModel  <= FALSE;
            TransRec.DataFromModel  <= (TransRec.DataFromModel'range  => '0');
            TransRec.ParamFromModel <= (TransRec.ParamFromModel'range => '0');
            wait for 0 ns;
          else
            if not TryWordWaiting then
              increment(WordRequestCount);
            end if;
            TryWordWaiting         := FALSE;
            DispatcherReceiveCount := DispatcherReceiveCount + 1;

            -- Get data
            TransRec.BoolFromModel <= TRUE;
            if IsEmpty(TransRec.TransmitFifo) then
              -- Wait for data
              WaitForToggle(WordReceiveCount);
            end if;

            (vData) := pop(TransRec.TransmitFifo); -- modelsim failure = illegal target maybe adapt scoreboard?

            TransRec.DataFromModel <= SafeResize(ModelID, vData, TransRec.DataFromModel'length);

            if IsCheck(Operation) then
              ExpectedData := SafeResize(ModelID, TransRec.DataToModel, AVALON_STREAM_WORD_WIDTH);
              AffirmIf(DataCheckID,
              (MetaMatch(vData, ExpectedData)),
              " Received.  Data: " & to_hxstring(vData),
              " Expected.  Data: " & to_hxstring(ExpectedData),
              TransRec.BoolToModel or IsLogEnabled(ModelID, INFO)
              );
            else
              Log(ModelID,
              "Word Receive. " &
              " Data: " & to_hxstring(vData),
              INFO, TransRec.BoolToModel
              );
            end if;
          end if;
        when CHECK | TRY_CHECK =>
          if IsEmpty(TransRec.TransmitFifo) then
            Alert(ModelID, "Can not check any data due to the Receive FIFO being empty!", FAILURE);
          end if;
          vData(AVALON_STREAM_WORD_WIDTH -1 downto 0) := pop(TransRec.TransmitFifo); -- modelsim failure = illegal target maybe adapt scoreboard?

          TransRec.DataFromModel <= SafeResize(ModelID, vData, TransRec.DataFromModel'length);

          if IsCheck(Operation) then
            ExpectedData := SafeResize(ModelID, TransRec.DataToModel, AVALON_STREAM_WORD_WIDTH);
            AffirmIf(DataCheckID,
            (MetaMatch(vData(AVALON_STREAM_WORD_WIDTH -1 downto 0), ExpectedData)),
            " Received.  Data: " & to_hxstring(vData(AVALON_STREAM_WORD_WIDTH -1 downto 0)),
            " Expected.  Data: " & to_hxstring(ExpectedData),
            TransRec.BoolToModel or IsLogEnabled(ModelID, INFO)
            );
          end if;
        when RECEIVE =>
          WordRequestCount <= WordRequestCount + TransRec.IntToModel;
        when RECEIVE_PACKET =>
          PacketRequestCount <= PacketRequestCount + 1;
        when GET_PACKET =>
          TransRec.IntFromModel <= PacketWordLength;
        when CHECK_WORD_OF_PACKET =>
          vData        := pop(TransRec.BurstFifo); -- modelsim failure = illegal target maybe adapt scoreboard?
          ExpectedData := SafeResize(ModelID, TransRec.DataToModel, AVALON_STREAM_DATA_WIDTH);
          AffirmIf(DataCheckID,
          (MetaMatch(vData, ExpectedData)),
          "PacketWord: " &
          " Received.  Data: " & to_hxstring(vData),
          " Expected.  Data: " & to_hxstring(ExpectedData),
          TransRec.BoolToModel or IsLogEnabled(ModelID, INFO)
          );
        when WAIT_FOR_TRANSACTION =>
          if (WordReceiveCount /= WordRequestCount) then
            wait until WordReceiveCount = WordRequestCount;
          end if;
          if (PacketRequestCount /= PacketReceiveCount) then
            wait until PacketReceiveCount = PacketRequestCount;
          end if;
        when WAIT_FOR_CLOCK =>
          WaitForClock(Clk, TransRec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          --!! This is GetTotalTransactionCount vs. GetPendingTransactionCount
          --!!  Get Pending Get Count = GetFifoCount(PacketFifo)
          TransRec.IntFromModel <= WordReceiveCount;

        when SET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when BEATS_PER_CYCLE =>
              BeatsPerCycle <= TransRec.IntToModel;
              wait for 0 ns;
              if (BeatsPerCycle < 1) then
                Alert(ModelID, "BeatsPerCycle must be greater than or equal to 1", FAILURE);
              end if;
              if (BeatsPerCycle > AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH) then
                Alert(ModelID, "BeatsPerCycle must be less than or equal to AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_WORD_WIDTH", FAILURE);
              end if;
            when WORD_WIDTH =>
              WordWidth <= TransRec.IntToModel;
              wait for 0 ns;
              if (WordWidth < 1) then
                Alert(ModelID, "WordWidth must be greater than or equal to 1", FAILURE);
              end if;
              if (WordWidth > AVALON_STREAM_DATA_WIDTH) then
                Alert(ModelID, "WordWidth must be less than or equal to AVALON_STREAM_DATA_WIDTH", FAILURE);
              end if;
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

            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
          wait for 0 ns;
        when GET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when BEATS_PER_CYCLE =>
              TransRec.IntFromModel <= BeatsPerCycle;
            when WORD_WIDTH =>
              TransRec.IntFromModel <= WordWidth;
            when PACKET_TRANSFER =>
              TransRec.BoolFromModel <= PacketTransfer;
            when PACKET_LAST_WORD_EMPTY =>
              TransRec.IntFromModel <= PacketLastWordEmpty;
            when BYTE_ORDER =>
              TransRec.BoolFromModel <= ByteOrder;
            when READY_ALLOWANCE =>
              TransRec.IntFromModel <= ReadyAllowance;
            when READY_LATENCY =>
              TransRec.IntFromModel <= ReadyLatency;
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
    variable vData            : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    variable ReadyBeforeValid : integer := 1;
    variable ReadyDelayCycles : integer := 0;
    variable Word             : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
    variable Offset           : integer;
  begin
    -- Initialize
    Ready <= '0';
    wait for 0 ns;
    wait for 0 ns; -- ensure that the scoreboards are initialized.

    --WaitForBarrier(OsvvmVcInit);
    ReceiveLoop : loop
      if WaitForGet then
        -- if no request, wait until we have one
        if not (WordRequestCount > WordReceiveCount or PacketRequestCount > PacketReceiveCount) then
          wait until (WordRequestCount > WordReceiveCount) or (PacketRequestCount > PacketReceiveCount) or not WaitForGet;
        end if;
      end if;

      if PacketRequestCount > PacketReceiveCount then
        -- Packet Mode
        DoAvalonStreamPacketReadyHandshake(
        Clk           => Clk,
        Valid         => Valid,
        Ready         => Ready,
        StartOfPacket => StartOfPacket,
        EndOfPacket   => EndOfPacket,
        Data          => Data,
        TransRec      => TransRec,
        WordsInPacket => PacketWordLength,
        ByteOrder     => ByteOrder,
        SymbolWidth   => AVALON_STREAM_SYMBOL_WIDTH,
        tpd_Clk_Ready => tpd_Clk_oReady,
        AlertLogID    => ModelID
        );

        PacketLastWordEmpty <= to_integer(unsigned(Empty));
        increment(PacketReceiveCount);
        wait for 0 ns;

      elsif (WordRequestCount > WordReceiveCount) then
        -- normal receive mode
        DoAvalonStreamReadyHandshake(
        Clk              => Clk,
        Valid            => Valid,
        Ready            => Ready,
        WordRequestCount => WordRequestCount,
        WordReceiveCount => WordReceiveCount,
        ReadyAllowance   => ReadyAllowance,
        ReadyBeforeValid => ReadyBeforeValid = 1,
        ReadyDelayCycles => ReadyDelayCycles * tperiod_Clk,
        tpd_Clk_Ready    => tpd_Clk_oReady,
        AlertLogID       => ModelID
        );

        vData := Data;
        if (ByteOrder = true) then
          ReverseSymbolOrder(vData, AVALON_STREAM_SYMBOL_WIDTH, AVALON_STREAM_WORD_WIDTH);
        end if;
        for i in 0 to BeatsPerCycle - 1 loop
          push(
          TransRec.TransmitFifo,
          vData((i + 1) * AVALON_STREAM_WORD_WIDTH - 1 downto i * AVALON_STREAM_WORD_WIDTH)
          );
        end loop;
        Log(ModelID, "WordTransfer: Received Word: " & to_hxstring(vData), INFO);
        if (WordReceiveCount + 1 = WordRequestCount) then
          StartOfNewStream <= 1;
          Ready            <= '0' after tpd_Clk_oReady;
        else
          if (ReadyAllowance > 0) and (WordReceiveCount + ReadyAllowance >= WordRequestCount) then
            Ready <= '0' after tpd_Clk_oReady;
          end if;
          StartOfNewStream <= 0;
        end if;
        WordReceiveCount <= WordReceiveCount + BeatsPerCycle;
        wait for 0 ns;
      else
        Alert(ModelID, "AvalonStreamReceiver: No Word or Packet request was received!", FAILURE);
      end if;
    end loop ReceiveLoop;
  end process ReceiveHandler;
end bhv;
