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
    MODEL_ID_NAME                 : string                  := "";
    AVALON_STREAM_CHANNELS        : integer range 1 to 128  := 1;
    AVALON_STREAM_ERROR           : integer range 1 to 256  := 1;
    AVALON_STREAM_READY_LATENCY   : integer                 := 1; -- default behavior
    AVALON_STREAM_READY_ALLOWANCE : integer                 := AVALON_STREAM_READY_LATENCY;
    AVALON_STREAM_DATA_WIDTH      : integer range 1 to 8192 := 32;
    AVALON_STREAM_BIG_ENDIAN      : boolean                 := false; -- little endian is default
    tperiod_Clk                   : time                    := 10 ns;
    DEFAULT_DELAY                 : time                    := 1 ns;
    tpd_Clk_oReady                : time                    := DEFAULT_DELAY
  );
  port (
    Clk   : in std_logic;
    Reset : in std_logic;
    -- DUT signals
    Valid : in std_logic := '0';
    Data  : in std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    Ready : out std_logic;

    StartOfPacket : out std_logic := '0';
    EndOfPacket   : out std_logic := '0';
    Empty         : out std_logic := '0';

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
  signal ModelID, ProtocolID                   : AlertLogIDType;
  signal DataCheckID, BusFailedID, BurstFifoID : AlertLogIDType;
  signal ReceiveFifo                           : osvvm.ScoreboardPkg_slv.ScoreboardIDType;
  signal WordRequestCount                      : integer := 0;
  signal WordReceiveCount                      : integer := 0;
  signal ReceiveByteCount, TransferByteCount   : integer := 0;
  signal StartOfNewStream                      : integer := 1;
  -- Verification Component Configuration
  signal WaitForGet     : boolean := TRUE;
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
    DataCheckID <= NewID("Data Check", ID);
    --BusFailedID <= NewID("No response", ID);

    ReceiveFifo <= NewID("ReceiveFifo", ID, ReportMode => ENABLED, Search => PRIVATE_NAME);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    alias Operation                          : StreamOperationType is TransRec.Operation;
    variable DispatcherReceiveCount          : integer := 0;
    variable WordCount                       : integer;
    variable TryWordWaiting, TryBurstWaiting : boolean;
    variable FifoWordCount, CheckWordCount   : integer;
    variable vData, ExpectedData, PopData    : std_logic_vector(Data'range);
  begin
    wait for 0 ns;

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
      );

      case Operation is
        when GET | TRY_GET | CHECK | TRY_CHECK =>

          if IsEmpty(ReceiveFifo) and IsTry(Operation) then
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
            if IsEmpty(ReceiveFifo) then
              -- Wait for data
              WaitForToggle(WordReceiveCount);
            end if;

            (vData) := pop(ReceiveFifo); -- modelsim failure = illegal target maybe adapt scoreboard?

            TransRec.DataFromModel <= SafeResize(ModelID, vData, TransRec.DataFromModel'length);

            if IsCheck(Operation) then
              ExpectedData := SafeResize(ModelID, TransRec.DataToModel, AVALON_STREAM_DATA_WIDTH);
              AffirmIf(DataCheckID,
              (MetaMatch(vData, ExpectedData)),
              "Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Received.  Data: " & to_hxstring(vData),
              " Expected.  Data: " & to_hxstring(ExpectedData),
              TransRec.BoolToModel or IsLogEnabled(ModelID, INFO)
              );
            else
              Log(ModelID,
              "Word Receive. " &
              " Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Data: " & to_hxstring(vData),
              INFO, TransRec.BoolToModel
              );
            end if;
          end if;

        when RECEIVE =>
          WordRequestCount <= WordRequestCount + TransRec.IntToModel;
          wait for 0 ns;
        when WAIT_FOR_TRANSACTION =>
          -- Receiver either blocks or does "try" operations
          -- There are no operations in flight
          -- There can be values received but not Get yet.
          -- Cannot block on those.
          wait for 0 ns;

        when WAIT_FOR_CLOCK =>
          WaitForClock(Clk, TransRec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          --!! This is GetTotalTransactionCount vs. GetPendingTransactionCount
          --!!  Get Pending Get Count = GetFifoCount(ReceiveFifo)
          TransRec.IntFromModel <= WordReceiveCount;
          wait for 0 ns;

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
                ReadyAllowance <= ReadyLatency;
              else
                ReadyAllowance <= TransRec.IntToModel;
              end if;
              Log(ModelID, "Setting AvalonStream Receiver Ready_Allowance to " & to_string(TransRec.IntToModel), DEBUG);
         
            when READY_LATENCY =>
              ReadyLatency <= TransRec.IntToModel;

            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " & to_string(AvalonStreamOptionsType'val(TransRec.Options)), FAILURE);
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

    variable ReadyBeforeValid : integer := 1;
    variable ReadyDelayCycles : integer := 0;
  begin
    -- Initialize
    Ready <= '0';
    wait for 0 ns; -- Allow Cov models to initialize 
    wait for 0 ns; -- Allow Cov models to initialize 

    --WaitForBarrier(OsvvmVcInit);
    ReceiveLoop : loop

      if WaitForGet then
        -- if no request, wait until we have one
        --!! Note:  > breaks when **RequestCount > 2**30 
        if not (WordRequestCount > WordReceiveCount) then
          wait until (WordRequestCount > WordReceiveCount) or not WaitForGet;
        end if;
      end if;

      ---------------------
      DoAvalonStreamReadyHandshake (
      ---------------------
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

      vData := to_x01(Data);

      -- capture this transaction
      push(ReceiveFifo, vData);

      -- Log this operation
      Log(ModelID,
      "AvalonStream Receive." &
      "  Data: " & to_hxstring(Data) &
      "  Operation# " & to_string (WordReceiveCount + 1),
      DEBUG
      );

      if (WordReceiveCount + 1 = WordRequestCount) then
        StartOfNewStream <= 1;
        Ready            <= '0' after tpd_Clk_oReady;
        --Data <= (others => 'U');
      else
        if (ReadyAllowance > 0) and (WordReceiveCount + ReadyAllowance >= WordRequestCount) then -- todo this if might not be necessary
          Ready <= '0' after tpd_Clk_oReady;
        end if;
        StartOfNewStream <= 0;
      end if;

      -- Signal completion
      increment(WordReceiveCount);
      wait for 0 ns;

    end loop ReceiveLoop;
  end process ReceiveHandler;
end bhv;
