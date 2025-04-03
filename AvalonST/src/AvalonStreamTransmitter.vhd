library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
context osvvm.OsvvmContext;

use osvvm.ScoreboardPkg_slv.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

entity AvalonStreamTransmitter is
  generic (
    MODEL_ID_NAME : string := "";
    -- AVALON_STREAM_CHANNELS        : integer range 1 to 128  := 1;
    --AVALON_STREAM_ERROR           : integer range 1 to 256  := 1;
    AVALON_STREAM_READY_LATENCY   : integer                 := 1; -- default behavior
    AVALON_STREAM_READY_ALLOWANCE : integer                 := AVALON_STREAM_READY_LATENCY;
    AVALON_STREAM_DATA_WIDTH      : integer range 1 to 8192 := 32;
    -- AVALON_STREAM_BIG_ENDIAN      : boolean                 := false; -- little endian is default
    DEFAULT_DELAY : time := 1 ns;
    tpd_Clk_Valid : time := DEFAULT_DELAY;
    tperiod_Clk   : time := 10 ns;
    tpd_Clk_oData : time := DEFAULT_DELAY
    --DEFAULT_CHANNELS   : integer := 1
  );
  port (
    Clk   : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid         : out std_logic := '0';
    Data          : out std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    StartOfPacket : out std_logic := '0';
    EndOfPacket   : out std_logic := '0';
    Empty : out std_logic := '0';
    --Empty : std_logic_vector(AVALON_STREAM_DATA_WIDTH - )
    Ready : in std_logic;

    -- testbench record
    TransRec : inout StreamRecType
  );
  -- Use MODEL_ID_NAME Generic if set, otherwise,
  -- use model instance label (preferred if set as entityname_1)
  constant MODEL_INSTANCE_NAME : string :=
  ifelse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME,
  to_lower(PathTail(AvalonStreamTransmitter'PATH_NAME)));

end AvalonStreamTransmitter;

architecture bhv of AvalonStreamTransmitter is
  signal ModelID, BusFailedID                    : AlertLogIDType;
  signal TransmitFifo                            : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
  signal TransmitRequestCount, TransmitDoneCount : integer := 0;
  signal StartOfNewStream                        : integer := 1;

  signal ReadyAllowanceCycles, ReadyAllowanceCyclesCount : integer := 0;

  -- Verification Component Configuration
  signal ReadyLatency   : integer := 0;
  signal ReadyAllowance : integer := 0;
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
    if (AVALON_STREAM_READY_ALLOWANCE < AVALON_STREAM_READY_LATENCY) then
      Alert(ModelID, "Ready Allowance must be at least Ready Latency or greater", FAILURE);
    end if;
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    variable vData           : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    variable NumberTransfers : integer;
  begin
    wait for 0 ns; -- Lassen, damit ModelID gesetzt wird

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );

      case TransRec.Operation is
        when SEND | SEND_ASYNC =>
          vData := SafeResize(ModelID, TransRec.DataToModel, vData'length);
          Push(TransmitFifo, vData);
          Increment(TransmitRequestCount);
          wait for 0 ns;
          if IsBlocking(TransRec.Operation) then
            log("waiting until blocked send completed");
            wait until TransmitRequestCount = TransmitDoneCount;
            log("async wait completed");
          end if;
        when WAIT_FOR_TRANSACTION =>
          if TransmitRequestCount /= TransmitDoneCount then
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
            when TRANSACTION_FIFO_SIZE =>
            -- todo
          when BEATS_PER_CYCLE =>
            -- todo
          when BYTE_ORDER =>
            -- todo
          when SYMBOL_WIDTH =>
            -- todo
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
            when TRANSACTION_FIFO_SIZE =>
              -- todo
            when BEATS_PER_CYCLE =>
              -- todo
            when BYTE_ORDER =>
              -- todo
            when SYMBOL_WIDTH =>
              -- todo
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
    variable vValid : std_logic;
    variable vData  : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);

  begin
    -- initialize outputs
    Valid <= '0';
    Data  <= (vData'range => 'X');
    wait for 0 ns;

    TransmitLoop : loop
      -- Find Transaction
      if IsEmpty(TransmitFifo) then
        WaitForToggle(TransmitRequestCount);
      end if;
      -- Get Transaction
      (vData) := Pop(TransmitFifo);
      Data <= vData;
      Log(ModelID,
      "AvalonStream Transmit." &
      "  Data: " & to_hxstring(vData) &
      "  Operation# " & to_string (TransmitDoneCount + 1),
      DEBUG
      );
      DoAvalonStreamValidHandshake(Clk, Valid, Ready, StartOfNewStream, TransmitRequestCount, TransmitDoneCount,
      ReadyLatency, ReadyAllowance, ReadyAllowanceCyclesCount, tpd_Clk_Valid, BusFailedID,
      "Valid Handshake timeout", AVALON_STREAM_READY_LATENCY * tperiod_Clk);
      if (TransmitDoneCount + 1 >= TransmitRequestCount) then
        StartOfNewStream          <= 1;
        Valid                     <= '0' after tpd_Clk_Valid;
        Data  <= (vData'range => 'X');
        ReadyAllowanceCyclesCount <= ReadyAllowance;
        --Data <= (others => 'U');
      else
        StartOfNewStream <= 0;
      end if;
      Increment(TransmitDoneCount);
      wait for 0 ns;

      wait for 0 ns;

    end loop;
  end process TransmitHandler;

end bhv;
