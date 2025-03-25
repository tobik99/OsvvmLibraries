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
    tperiod_Clk                : time                    := 10 ns;
    DEFAULT_DELAY                 : time                    := 1 ns;
    tpd_Clk_oReady                : time                    := DEFAULT_DELAY
  );
  port (
    i_clk    : in std_logic;
    i_nreset : in std_logic;
    -- DUT signals
    i_valid : in std_logic := '0';
    i_data  : in std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    o_ready : out std_logic;

    -- testbench record
    io_trans_rec : inout StreamRecType
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
  -- Verification Component Configuration
  signal ReceiveReadyBeforeValid : boolean := TRUE;
  signal ReceiveReadyDelayCycles : integer := 0;
  signal WaitForGet              : boolean := FALSE;
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
    DataCheckID      <= NewID("Data Check", ID ) ;
    --BusFailedID <= NewID("No response", ID);
    
    ReceiveFifo   <= NewID("ReceiveFifo", ID, ReportMode => ENABLED, Search => PRIVATE_NAME) ;
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
    alias Operation                          : StreamOperationType is io_trans_rec.Operation;
    variable DispatcherReceiveCount          : integer := 0;
    variable WordCount                       : integer;
    variable TryWordWaiting, TryBurstWaiting : boolean;
    variable FifoWordCount, CheckWordCount   : integer;
    variable Data, ExpectedData, PopData     : std_logic_vector(i_data'range);
  begin
    o_ready <= '1';
    wait for 0 ns; -- Lassen, damit ModelID gesetzt wird

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => i_clk,
      Rdy => io_trans_rec.Rdy,
      Ack => io_trans_rec.Ack
      );

      case Operation is
        when GET | TRY_GET | CHECK | TRY_CHECK =>
        
          if IsEmpty(ReceiveFifo) and IsTry(Operation) then
            if not TryWordWaiting then
              increment(WordRequestCount);
            end if;
            TryWordWaiting := TRUE;
            -- Return if no data
            io_trans_rec.BoolFromModel  <= FALSE;
            io_trans_rec.DataFromModel  <= (io_trans_rec.DataFromModel'range  => '0');
            io_trans_rec.ParamFromModel <= (io_trans_rec.ParamFromModel'range => '0');
            wait for 0 ns;
          else
            if not TryWordWaiting then
              increment(WordRequestCount);
            end if;
            TryWordWaiting         := FALSE;
            DispatcherReceiveCount := DispatcherReceiveCount + 1;

            -- Get data
            io_trans_rec.BoolFromModel <= TRUE;
            if IsEmpty(ReceiveFifo) then
              -- Wait for data
              WaitForToggle(WordReceiveCount);
            end if;
            
            (Data) := pop(ReceiveFifo); -- modelsim failure = illegal target maybe adapt scoreboard?

            io_trans_rec.DataFromModel <= SafeResize(ModelID, Data, io_trans_rec.DataFromModel'length);

            if IsCheck(Operation) then
              ExpectedData := SafeResize(ModelID, io_trans_rec.DataToModel, AVALON_STREAM_DATA_WIDTH);
              -- ExpectedParam := UpdateOptions(
              --   Param     => SafeResize(ModelID, TransRec.ParamToModel, ExpectedParam'length),
              --   ParamID   => ParamID,
              --   ParamDest => ParamDest,
              --   ParamUser => ParamUser,
              --   ParamLast => ParamLast,
              --   Count     => WordReceiveCount - LastOffsetCount
              --   );
              AffirmIf(DataCheckID,
              --                (Data ?= ExpectedData and Param ?= ExpectedParam) = '1',
              (MetaMatch(Data, ExpectedData)),
              "Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Received.  Data: " & to_hxstring(Data),
              " Expected.  Data: " & to_hxstring(ExpectedData),
              io_trans_rec.BoolToModel or IsLogEnabled(ModelID, INFO)
              );
            else
              Log(ModelID,
              "Word Receive. " &
              " Operation# " & to_string (DispatcherReceiveCount) & " " &
              " Data: " & to_hxstring(Data),
              INFO, io_trans_rec.BoolToModel
              );
            end if;
          end if;

          --------------------------------
          wait until rising_edge(i_clk) and i_valid = '1';
          io_trans_rec.DataFromModel <= SafeResize(ModelID, Data, io_trans_rec.DataFromModel'length);
          o_ready                    <= '0' after tpd_Clk_oReady;
          wait for 0 ns;
          Log(ModelID, "Avalon Stream Get." & "data: " & to_hxstring(to_x01(SafeResize(io_trans_rec.DataFromModel, Data'length))), INFO);
          wait until rising_edge(i_clk);
          o_ready <= '1' after tpd_Clk_oReady;
        when WAIT_FOR_TRANSACTION =>
          -- Receiver either blocks or does "try" operations
          -- There are no operations in flight
          -- There can be values received but not Get yet.
          -- Cannot block on those.
          wait for 0 ns;

        when WAIT_FOR_CLOCK =>
          WaitForClock(i_clk, io_trans_rec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          --!! This is GetTotalTransactionCount vs. GetPendingTransactionCount
          --!!  Get Pending Get Count = GetFifoCount(ReceiveFifo)
          io_trans_rec.IntFromModel <= WordReceiveCount;
          wait for 0 ns;

        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record. Transaction # " & to_string(io_trans_rec.Rdy), FAILURE);

        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(io_trans_rec.Operation), FAILURE);

      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  ReceiveHandler : process
    variable Data : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);

    variable ReadyBeforeValid, ReadyDelayCycles : integer;
  begin
    -- Initialize
    o_ready <= '0';
    wait for 0 ns; -- Allow Cov models to initialize 
    wait for 0 ns; -- Allow Cov models to initialize 

    WaitForBarrier(OsvvmVcInit);
    ReceiveLoop : loop

      if WaitForGet then
        -- if no request, wait until we have one
        --!! Note:  > breaks when **RequestCount > 2**30 
        if not (WordRequestCount > WordReceiveCount) then
          wait until (WordRequestCount > WordReceiveCount) or not WaitForGet;
        end if;
      end if;
      -- Deprecated static settings
      ReadyBeforeValid := to_integer(not ReceiveReadyBeforeValid);
      ReadyDelayCycles := ReceiveReadyDelayCycles;
      ---------------------
      DoAvalonStreamReadyHandshake (
      ---------------------
      Clk              => i_clk,
      Valid            => i_valid,
      Ready            => o_ready,
      ReadyBeforeValid => ReadyBeforeValid = 0,
      ReadyDelayCycles => ReadyDelayCycles * tperiod_Clk,
      tpd_Clk_Ready    => tpd_Clk_oReady,
      AlertLogID       => ModelID
      );

      Data := to_x01(i_data);
      
      -- capture this transaction
      push(ReceiveFifo, Data);

      -- Log this operation
      Log(ModelID,
      "Axi Stream Receive." &
      "  TData: " & to_hxstring(i_data) &
      "  Operation# " & to_string (WordReceiveCount + 1),
      DEBUG
      );

      -- Signal completion
      increment(WordReceiveCount);
      wait for 0 ns;
    end loop ReceiveLoop;
  end process ReceiveHandler;
end bhv;
