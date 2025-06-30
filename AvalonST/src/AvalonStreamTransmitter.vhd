library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;
library osvvm;
context osvvm.OsvvmContext;

use osvvm.ScoreboardPkg_slv.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;
entity AvalonStreamTransmitter is
  generic (
    INIT_CHANNEL : std_logic_vector := "";
    INIT_EMPTY : std_logic_vector := "";
    INIT_LAST : natural := 0;

    MODEL_ID_NAME : string := "";
    AVALON_STREAM_DATA_WIDTH : integer range 1 to 8192 := 32;
    AVALON_STREAM_WORD_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 32;
    AVALON_STREAM_SYMBOL_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 16;
    AVALON_STREAM_CHANNELS : integer range 1 to 256 := 1;
    AVALON_STREAM_ERROR : integer range 1 to 256 := 1;
    DEFAULT_DELAY : time := 1 ns;
    tpd_Clk_Data : time := DEFAULT_DELAY;
    tpd_Clk_Valid : time := DEFAULT_DELAY;
    tpd_Clk_StartOfPacket : time := DEFAULT_DELAY;
    tpd_Clk_EndOfPacket : time := DEFAULT_DELAY;
    tpd_Clk_Empty : time := DEFAULT_DELAY;
    --DEFAULT_CHANNELS   : integer := 1
    tperiod_Clk : time := 10 ns --todo: could be deleted
  );
  port (
    Clk : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid : out std_logic := '0';
    Data : out std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    StartOfPacket : out std_logic := '0';
    EndOfPacket : out std_logic := '0';
    Empty : out std_logic_vector((AVALON_STREAM_DATA_WIDTH/AVALON_STREAM_WORD_WIDTH) - 1 downto 0) := (others => '0');

    Ready : in std_logic;
    Channel : out std_logic_vector(7 downto 0) := (others => '0');

    -- testbench record
    TransRec : inout StreamRecType
  );
  -- Use MODEL_ID_NAME Generic if set, otherwise,
  -- use model instance label (preferred if set as entityname_1)
  constant MODEL_INSTANCE_NAME : string :=
                                          ifelse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME,
                                          to_lower(PathTail(AvalonStreamTransmitter'PATH_NAME)));

  alias PacketFifo : ScoreboardIdType is TransRec.BurstFifo;
end AvalonStreamTransmitter;

architecture bhv of AvalonStreamTransmitter is
  signal ModelID, BusFailedID : AlertLogIDType;
  --signal TransmitFifo                            : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
  signal TransmitRequestCount, TransmitDoneCount : integer := 0;
  signal StartOfNewStream : integer := 1;
  signal TransmitFifo : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
  -- Verification Component Configuration
  signal ReadyLatency : integer := 0;
  signal ReadyAllowance : integer := 0;
  signal SymbolOrder : boolean := true; -- little endian is default
  signal ReadyAllowanceTransferCount : integer := 0;
  signal PacketTransfer : boolean := false;
  signal LastOffsetCount : integer := 0;
  signal BeatsPerCycle : integer := AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH;
  signal ParamChannel : std_logic_vector(Channel'range) := ifelse(INIT_CHANNEL'length > 0, INIT_CHANNEL, (Channel'range => '0'));
  signal ParamEmpty : std_logic_vector(Empty'range) := ifelse(INIT_EMPTY'length > 0, INIT_EMPTY, (Empty'range => '0'));

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
    --    ProtocolID       <= NewID("Protocol Error", ID ) ;
    --    DataCheckID      <= NewID("Data Check", ID ) ;
    --BusFailedID  <= NewID("No response", ID);
    TransmitFifo <= NewID("TransmitFifo", ID, ReportMode => ENABLED, Search => PRIVATE_NAME);

    AlertIf(ModelID, AVALON_STREAM_DATA_WIDTH mod AVALON_STREAM_SYMBOL_WIDTH /= 0,
    "AvalonStreamTransmitter: AVALON_STREAM_DATA_WIDTH must be a multiple of AVALON_STREAM_SYMBOL_WIDTH", FAILURE);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    variable vData : std_logic_vector(Data'range);
    variable Param : std_logic_vector(TransRec.ParamToModel'length - 1 downto 0);
    variable BytesToSend, NumberTransfers : integer;
    variable PopValid : boolean;
    variable Last : std_logic;
  begin
    wait for 0 ns;
    TransRec.BurstFifo <= NewID("TxTransmitFifo", ModelID, Search => PRIVATE_NAME);

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );

      case TransRec.Operation is
        when SEND | SEND_ASYNC =>
          vData := SafeResize(ModelID, TransRec.DataToModel, Data'length);
          Param := UpdateOptions(
                   Param => SafeResize(ModelID, TransRec.ParamToModel, TransRec.ParamToModel'length),
                   ParamChannel => ParamChannel,
                   ParamEmpty => ParamEmpty, -- used for empty signal
                   Count => ((TransmitRequestCount + 1) - LastOffsetCount)
                   );
          Push(TransmitFifo, vData & Param);
          Increment(TransmitRequestCount);
          if IsBlocking(TransRec.Operation) then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;
        when WAIT_FOR_TRANSACTION =>
          if TransmitRequestCount /= TransmitDoneCount then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;
        when SEND_BURST =>
          Param := UpdateOptions(
                   Param => SafeResize(ModelID, TransRec.ParamToModel, TransRec.ParamToModel'length),
                   ParamChannel => ParamChannel,
                   ParamEmpty => ParamEmpty, -- used for empty signal
                   Count => ((TransmitRequestCount + 1) - LastOffsetCount)
                   );
          if BurstFifoByteMode then
            BytesToSend := TransRec.IntToModel;
            NumberTransfers := integer(ceil(real(TransRec.IntToModel) / real(BeatsPerCycle)));
          else
            NumberTransfers := TransRec.IntToModel;
          end if;
          TransmitRequestCount <= TransmitRequestCount + NumberTransfers;
        
          for i in NumberTransfers - 1 downto 0 loop
            case BurstFifoMode is
              when STREAM_BURST_BYTE_MODE =>
                PopWord(TransRec.BurstFifo, PopValid, vData, BytesToSend);
                AlertIfNot(ModelID, PopValid, "BurstFifo Empty during burst transfer", FAILURE);
              when STREAM_BURST_WORD_MODE =>
                vData := Pop(TransRec.BurstFifo);

              when STREAM_BURST_WORD_PARAM_MODE =>
                (vData, Param)                := Pop(TransRec.BurstFifo);
              when others =>
                Alert(ModelID, "BurstFifoMode: Invalid Mode: " & to_string(BurstFifoMode));
            end case;

            Push(TransmitFifo, vData & Param);
          end loop;
          if IsBlocking(TransRec.Operation) then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;
        when WAIT_FOR_CLOCK =>
          WaitForClock(Clk, TransRec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          TransRec.IntFromModel <= TransmitDoneCount;

        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record. Transaction # " & to_string(TransRec.Rdy), FAILURE);

        when SET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when DEFAULT_CHANNEL =>
              ParamChannel <= SafeResize(ModelID, TransRec.ParamToModel, ParamChannel'length);
            when PACKET_TRANSFER =>
              PacketTransfer <= TransRec.BoolToModel;
              wait for 0 ns;
              if (PacketTransfer = true) then
                Log(ModelID, "Packet Transfer set to true", INFO, TRUE);
              else
                Log(ModelID, "Packet Transfer set to false", INFO, TRUE);
              end if;

            when SYMBOL_ORDER =>
              SymbolOrder <= TransRec.BoolToModel;
              wait for 0 ns;
              if (SymbolOrder = true) then
                Log(ModelID, "Byte Order set to Little Endian", INFO, TRUE);
              else
                Log(ModelID, "Byte Order set to Big Endian", INFO, TRUE);
              end if;

            when READY_ALLOWANCE =>

              ReadyAllowance <= TransRec.IntToModel;
            when READY_LATENCY =>
              ReadyLatency <= TransRec.IntToModel;
            when others =>
              Alert(ModelID, "SetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
          wait for 0 ns;
        when GET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when PACKET_TRANSFER =>
              TransRec.BoolFromModel <= PacketTransfer;
            when SYMBOL_ORDER =>
              TransRec.BoolFromModel <= SymbolOrder;
            when READY_ALLOWANCE =>
              TransRec.IntFromModel <= ReadyAllowance;
            when READY_LATENCY =>
              TransRec.IntFromModel <= ReadyLatency;
            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
        when SET_BURST_MODE =>
          BurstFifoMode <= TransRec.IntToModel;
          BurstFifoByteMode <= (TransRec.IntToModel = STREAM_BURST_BYTE_MODE);
          Log(ModelID, "AvalonStreamTransmitter: BurstFifoMode set to " & to_string(BurstFifoMode), INFO, TRUE);
          wait for 0 ns;
        when GET_BURST_MODE =>
          TransRec.IntFromModel <= BurstFifoMode;
        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(TransRec.Operation), FAILURE);

      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  TransmitHandler : process is
    variable vData : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0) := (Data'range => 'X');
    variable vEmptyBeats : integer := 0;
  begin
    -- initialize outputs
    Valid <= '0';
    Data <= (Data'range => 'X');
    StartOfPacket <= '0';
    EndOfPacket <= '0';
    Empty <= (others => '0');
    wait for 0 ns;
    wait for 0 ns; -- two delta-cycles to ensure that the scoreboards are initialized

    TransmitLoop : loop
      if IsEmpty(TransmitFifo) and TransmitRequestCount <= TransmitDoneCount then
        wait on TransmitRequestCount;
      end if;
      if PacketTransfer and (TransmitRequestCount > TransmitDoneCount) then

        StartOfPacket <= '1' after tpd_Clk_StartOfPacket;
        EndOfPacket <= '0' after tpd_Clk_EndOfPacket;
        wait for 0 ns;
        while not IsEmpty(TransmitFifo) and PacketTransfer = true loop
          DoPrepareTransmitData(Data, Channel, Empty, TransmitFifo, vEmptyBeats, BurstFifoMode, BeatsPerCycle, SymbolOrder, AVALON_STREAM_WORD_WIDTH, AVALON_STREAM_SYMBOL_WIDTH);
          -- check if is the last word in the packet
          EndOfPacket <= '1' after tpd_Clk_EndOfPacket when IsEmpty(TransmitFifo) else
                         '0';

          Log(ModelID,
          "AvalonStream Packet Transmit." &
          "  Data: " & to_hxstring(vData) &
          "  SOP: " & to_string(StartOfPacket) &
          "  EOP: " & to_string(EndOfPacket),
          DEBUG
          );
          DoAvalonStreamValidHandshake(
          Clk, Valid, Ready, StartOfNewStream,
          ReadyLatency, ReadyAllowance, ReadyAllowanceTransferCount, tpd_Clk_Valid, ModelID,
          "Packet Valid Handshake Timeout", 0 ns
          );

          -- Nach erstem Wort SOP zur�cksetzen
          StartOfPacket <= '0' after tpd_Clk_StartOfPacket;
          TransmitDoneCount <= TransmitDoneCount + 1;
          -- Bei EOP fertig
          if EndOfPacket = '1' then
            EndOfPacket <= '0' after tpd_Clk_EndOfPacket;
            Empty <= (others => '0') after tpd_Clk_Empty;
            exit;
          end if;

          wait for 0 ns;

        end loop;
        StartOfNewStream <= 1;
        Valid <= '0' after tpd_Clk_Valid;
        Data <= (Data'range => 'X');
        wait for 0 ns;
      else

        -- Find Transaction
        if IsEmpty(TransmitFifo) and not PacketTransfer then
          Log(ModelID, "AvalonStream Transmitter: No data to transmit", INFO);
          WaitForToggle(TransmitRequestCount);
        end if;
        -- Get Transaction
        -- Data preparation
        DoPrepareTransmitData(Data, Channel, Empty, TransmitFifo, vEmptyBeats, BurstFifoMode, BeatsPerCycle, SymbolOrder, AVALON_STREAM_WORD_WIDTH, AVALON_STREAM_SYMBOL_WIDTH);

        DoAvalonStreamValidHandshake(Clk, Valid, Ready, StartOfNewStream,
        ReadyLatency, ReadyAllowance, ReadyAllowanceTransferCount, tpd_Clk_Valid, BusFailedID,
        "Valid Handshake timeout", 0 ns);

        if (TransmitDoneCount + 1 >= TransmitRequestCount) then
          StartOfNewStream <= 1;
          Valid <= '0' after tpd_Clk_Valid;
          Data <= (others => 'X');
        else
          StartOfNewStream <= 0;
        end if;
        TransmitDoneCount <= TransmitDoneCount + 1;
        vEmptyBeats := 0;
        Log(ModelID,
        "AvalonStream Transmit." &
        "  Data: " & to_hxstring(Data), INFO
        );
        wait for 0 ns;
      end if;
    end loop;
  end process TransmitHandler;

end bhv;