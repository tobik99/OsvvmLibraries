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
    MODEL_ID_NAME              : string                                      := "";
    AVALON_STREAM_DATA_WIDTH   : integer range 1 to 8192                     := 32;
    AVALON_STREAM_WORD_WIDTH   : integer range 1 to AVALON_STREAM_DATA_WIDTH := 32;
    AVALON_STREAM_SYMBOL_WIDTH : integer range 1 to AVALON_STREAM_DATA_WIDTH := 16;
    AVALON_STREAM_CHANNELS     : integer range 1 to 128                      := 1;
    AVALON_STREAM_ERROR        : integer range 1 to 256                      := 1;
    DEFAULT_DELAY              : time                                        := 1 ns;
    tpd_Clk_Data               : time                                        := DEFAULT_DELAY;
    tpd_Clk_Valid              : time                                        := DEFAULT_DELAY;
    tpd_Clk_StartOfPacket      : time                                        := DEFAULT_DELAY;
    tpd_Clk_EndOfPacket        : time                                        := DEFAULT_DELAY;
    tpd_Clk_Empty              : time                                        := DEFAULT_DELAY;
    --DEFAULT_CHANNELS   : integer := 1
    tperiod_Clk : time := 10 ns --todo: could be deleted
  );
  port (
    Clk   : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid         : out std_logic := '0';
    Data          : out std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    StartOfPacket : out std_logic                                                                            := '0';
    EndOfPacket   : out std_logic                                                                            := '0';
    Empty         : out std_logic_vector((AVALON_STREAM_DATA_WIDTH/AVALON_STREAM_SYMBOL_WIDTH) - 1 downto 0) := (others => '0');

    Ready : in std_logic;

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
  signal StartOfNewStream                        : integer := 1;
  signal PacketRequestCount, PacketTransmitCount : integer := 0;
  signal PacketWordLength                        : integer := 0;
  -- Verification Component Configuration
  signal ReadyLatency                                    : integer := 0;
  signal ReadyAllowance                                  : integer := 0;
  signal ByteOrder                                       : boolean := false; -- big endian is default
  signal ReadyAllowanceCycles, ReadyAllowanceCyclesCount : integer := 0;
  signal PacketTransfer                                  : boolean := false;
  signal PacketLastWordEmpty                             : integer := 0;
  signal BeatsPerCycle                                   : integer := 1;
  signal WordWidth                                       : integer := AVALON_STREAM_DATA_WIDTH;
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
    --TransmitFifo <= NewID("TransmitFifo", ID, ReportMode => ENABLED, Search => PRIVATE_NAME);

    AlertIf(ModelID, AVALON_STREAM_DATA_WIDTH mod AVALON_STREAM_SYMBOL_WIDTH /= 0,
    "AvalonStreamTransmitter: AVALON_STREAM_DATA_WIDTH must be a multiple of AVALON_STREAM_SYMBOL_WIDTH", FAILURE);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    variable vData, vDataReverse : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
    variable vSymbolCount        : integer := 0;
  begin
    wait for 0 ns;
    TransRec.TransmitFifo <= NewID("TxTransmitFifo", ModelID, Search => PRIVATE_NAME);
    TransRec.BurstFifo    <= NewID("TxPacketFifo", ModelID, Search   => PRIVATE_NAME);

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );

      case TransRec.Operation is
        when SEND | SEND_ASYNC =>
          Log(ModelID,
          "AvalonStream Transmit.", ALWAYS);
          TransmitRequestCount <= TransmitRequestCount + TransRec.IntToModel;
          wait for 0 ns;
          if IsBlocking(TransRec.Operation) then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;
        when WAIT_FOR_TRANSACTION =>
          if TransmitRequestCount /= TransmitDoneCount then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;

        when SEND_PACKET =>
          PacketWordLength   <= TransRec.IntToModel;
          PacketRequestCount <= PacketRequestCount + 1;
          wait for 0 ns;
          -- todo, check if packet transport is enabled

        when WAIT_FOR_CLOCK =>
          WaitForClock(Clk, TransRec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          TransRec.IntFromModel <= TransmitDoneCount;

        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record. Transaction # " & to_string(TransRec.Rdy), FAILURE);

        when SET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when BEATS_PER_CYCLE =>
              BeatsPerCycle <= TransRec.IntToModel;
              wait for 0 ns;
              Log(ModelID, "BeatsPerCycle = " & integer'image(BeatsPerCycle), INFO);
              if (BeatsPerCycle < 1) then
                Alert(ModelID, "BeatsPerCycle must be greater than or equal to 1", FAILURE);
              elsif (BeatsPerCycle > AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_WORD_WIDTH) then
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
                Log(ModelID, "Packet Transfer set to true", INFO, TRUE);
              else
                Log(ModelID, "Packet Transfer set to false", INFO, TRUE);
              end if;

            when BYTE_ORDER =>
              ByteOrder <= TransRec.BoolToModel;
              wait for 0 ns;
              if (ByteOrder = true) then
                Log(ModelID, "Byte Order set to Little Endian", INFO, TRUE);
              else
                Log(ModelID, "Byte Order set to Big Endian", INFO, TRUE);
              end if;

            when PACKET_LAST_WORD_EMPTY =>
              if TransRec.IntToModel <= AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH then
                PacketLastWordEmpty    <= TransRec.IntToModel;
              else
                Alert(ModelID, "PacketLastWordEmpty must be less than or equal to AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH", WARNING);
                PacketLastWordEmpty <= AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH;
              end if;
            when READY_ALLOWANCE =>
              if (TransRec.IntToModel < ReadyLatency) then
                AlertIf(ModelID, TransRec.IntToModel < ReadyLatency,
                "ReadyAllowance must be greater than or equal to ReadyLatency - set to ReadyLatency now!", WARNING);
                ReadyAllowance       <= ReadyLatency;
                ReadyAllowanceCycles <= ReadyLatency;
              else
                ReadyAllowance       <= TransRec.IntToModel;
                ReadyAllowanceCycles <= TransRec.IntToModel;
              end if;
            when READY_LATENCY =>
              ReadyLatency <= TransRec.IntToModel;
            when others =>
              Alert(ModelID, "SetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
              wait for 0 ns;
          end case;
          wait for 0 ns;
        when GET_MODEL_OPTIONS =>
          case AvalonStreamOptionsType'val(TransRec.Options) is
            when BEATS_PER_CYCLE =>
              TransRec.IntFromModel <= BeatsPerCycle;
            when PACKET_TRANSFER =>
              TransRec.BoolFromModel <= PacketTransfer;
            when BYTE_ORDER =>
              TransRec.BoolFromModel <= ByteOrder;
            when PACKET_LAST_WORD_EMPTY =>
              TransRec.IntFromModel <= PacketLastWordEmpty;
            when READY_ALLOWANCE =>
              TransRec.IntFromModel <= ReadyAllowance;
            when READY_LATENCY =>
              TransRec.IntFromModel <= ReadyLatency;
            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
          end case;
        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(TransRec.Operation), FAILURE);

      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  TransmitHandler : process is
    variable vData, vDataReverse : std_logic_vector(AVALON_STREAM_WORD_WIDTH - 1 downto 0);
    variable vEmptyBeats         : integer := 0;
    variable vSymbolCount        : integer := 0;

  begin
    -- initialize outputs
    Valid         <= '0';
    Data          <= (Data'range => 'X');
    StartOfPacket <= '0';
    EndOfPacket   <= '0';
    Empty         <= (others => '0');
    wait for 0 ns;
    wait for 0 ns; -- two delta-cycles to ensure that the scoreboards are initialized

    TransmitLoop : loop
      if PacketRequestCount = PacketTransmitCount and IsEmpty(TransRec.TransmitFifo) then
        wait on TransmitRequestCount, PacketRequestCount;
      end if;
      if PacketTransfer and (PacketRequestCount > PacketTransmitCount) then

        StartOfPacket <= '1' after tpd_Clk_StartOfPacket;
        EndOfPacket   <= '0' after tpd_Clk_EndOfPacket;
        wait for 0 ns;

        while not IsEmpty(PacketFifo) loop
          if (BeatsPerCycle > 1) then
            for i in 0 to (BeatsPerCycle - 1) loop
              if IsEmpty(TransRec.TransmitFifo) then
                Data((AVALON_STREAM_WORD_WIDTH - 1) + AVALON_STREAM_WORD_WIDTH * i downto AVALON_STREAM_WORD_WIDTH * i) <= (others => '0');
                vEmptyBeats := vEmptyBeats + 1;
              else
                vData := Pop(TransRec.TransmitFifo);
                if (ByteOrder = true) then
                  vSymbolCount := AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH;
                  for j in 0 to vSymbolCount - 1 loop
                    vDataReverse((j + 1) * AVALON_STREAM_SYMBOL_WIDTH - 1 downto j * AVALON_STREAM_SYMBOL_WIDTH) :=
                    vData((vSymbolCount - j) * AVALON_STREAM_SYMBOL_WIDTH - 1 downto (vSymbolCount - j - 1) * AVALON_STREAM_SYMBOL_WIDTH);
                  end loop;
                end if;
                Data((AVALON_STREAM_WORD_WIDTH - 1) + AVALON_STREAM_WORD_WIDTH * i downto AVALON_STREAM_WORD_WIDTH * i) <= vData;
              end if;
            end loop;
          else
            (vData) := Pop(TransRec.TransmitFifo);
            Data(AVALON_STREAM_WORD_WIDTH - 1 downto 0) <= vData;
          end if;

          -- check if is the last word in the packet
          EndOfPacket <= '1' after tpd_Clk_EndOfPacket when IsEmpty(PacketFifo) else
            '0';
          Empty <= std_logic_vector(to_unsigned(PacketLastWordEmpty, Empty'length)) after tpd_Clk_Empty when IsEmpty(PacketFifo) else
            (others => '0');

          Log(ModelID,
          "AvalonStream Packet Transmit." &
          "  Data: " & to_hxstring(vData) &
          "  SOP: " & to_string(StartOfPacket) &
          "  EOP: " & to_string(EndOfPacket) &
          "  Packet# " & to_string(PacketTransmitCount + 1),
          DEBUG
          );

          DoAvalonStreamValidHandshake(
          Clk, Valid, Ready, StartOfNewStream,
          0, 0, ReadyAllowanceCyclesCount, tpd_Clk_Valid, BusFailedID,
          "Packet Valid Handshake Timeout", tperiod_Clk * 100
          );

          -- Nach erstem Wort SOP zurücksetzen
          StartOfPacket <= '0' after tpd_Clk_StartOfPacket;

          -- Bei EOP fertig
          if EndOfPacket = '1' then
            EndOfPacket <= '0' after tpd_Clk_EndOfPacket;
            Empty       <= (others => '0') after tpd_Clk_Empty;
            exit;
          end if;

          wait for 0 ns;
        end loop;

        Increment(PacketTransmitCount);
        StartOfNewStream <= 1;
        Valid            <= '0' after tpd_Clk_Valid;
        Data             <= (Data'range => 'X');
        wait for 0 ns;
      else

        -- Find Transaction
        if IsEmpty(TransRec.TransmitFifo) and not PacketTransfer then
          WaitForToggle(TransmitRequestCount);
        end if;
        -- Get Transaction
        if (BeatsPerCycle > 1) then
          for i in 0 to (BeatsPerCycle - 1) loop
            if IsEmpty(TransRec.TransmitFifo) then
              Data((AVALON_STREAM_WORD_WIDTH - 1) + AVALON_STREAM_WORD_WIDTH * i downto AVALON_STREAM_WORD_WIDTH * i) <= (others => '0');
              vEmptyBeats := vEmptyBeats + 1;
            else
              vData := Pop(TransRec.TransmitFifo);
              if (ByteOrder = true) then
                vSymbolCount := AVALON_STREAM_DATA_WIDTH / AVALON_STREAM_SYMBOL_WIDTH;
                for j in 0 to vSymbolCount - 1 loop
                  vDataReverse((j + 1) * AVALON_STREAM_SYMBOL_WIDTH - 1 downto j * AVALON_STREAM_SYMBOL_WIDTH) :=
                  vData((vSymbolCount - j) * AVALON_STREAM_SYMBOL_WIDTH - 1 downto (vSymbolCount - j - 1) * AVALON_STREAM_SYMBOL_WIDTH);
                end loop;
              end if;
              Data((AVALON_STREAM_WORD_WIDTH - 1) + AVALON_STREAM_WORD_WIDTH * i downto AVALON_STREAM_WORD_WIDTH * i) <= vData;
            end if;
          end loop;
        else
          (vData) := Pop(TransRec.TransmitFifo);
          Data(AVALON_STREAM_WORD_WIDTH - 1 downto 0) <= vData;
        end if;
        Log(ModelID,
        "AvalonStream Transmit." &
        "  Data: " & to_hxstring(vData),
        DEBUG
        );
        DoAvalonStreamValidHandshake(Clk, Valid, Ready, StartOfNewStream,
        ReadyLatency, ReadyAllowance, ReadyAllowanceCyclesCount, tpd_Clk_Valid, BusFailedID,
        "Valid Handshake timeout", ReadyLatency * tperiod_Clk);
        if (TransmitDoneCount + BeatsPerCycle >= TransmitRequestCount) then
          StartOfNewStream          <= 1;
          Valid                     <= '0' after tpd_Clk_Valid;
          Data                      <= (others => 'X');
          ReadyAllowanceCyclesCount <= ReadyAllowance;
        else
          StartOfNewStream <= 0;
        end if;
        TransmitDoneCount <= TransmitDoneCount + BeatsPerCycle - vEmptyBeats;
        vEmptyBeats := 0;
        wait for 0 ns;

        wait for 0 ns;
      end if;
    end loop;
  end process TransmitHandler;

end bhv;
