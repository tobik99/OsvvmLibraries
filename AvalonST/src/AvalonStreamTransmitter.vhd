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
    MODEL_ID_NAME                 : string                  := "";
    AVALON_STREAM_CHANNELS        : integer range 1 to 128  := 1;
    AVALON_STREAM_ERROR           : integer range 1 to 256  := 1;
    AVALON_STREAM_READY_LATENCY   : integer                 := 1; -- default behavior
    AVALON_STREAM_READY_ALLOWANCE : integer                 := AVALON_STREAM_READY_LATENCY;
    AVALON_STREAM_DATA_WIDTH      : integer range 1 to 8192 := 32;
    AVALON_STREAM_BIG_ENDIAN      : boolean                 := false; -- little endian is default
    DEFAULT_DELAY                 : time                    := 1 ns;
    tpd_Clk_Valid                 : time                    := DEFAULT_DELAY;
    tperiod_Clk    : time := 10 ns ;
    tpd_Clk_oData                 : time                    := DEFAULT_DELAY
    --DEFAULT_CHANNELS   : integer := 1
  );
  port (
    i_clk    : in std_logic;
    i_nreset : in std_logic;
    -- DUT signals
    o_valid : out std_logic := '0';
    o_data  : out std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
    i_ready : in std_logic;

    -- testbench record
    io_trans_rec : inout StreamRecType
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
    variable Data : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
  begin
    wait for 0 ns; -- Lassen, damit ModelID gesetzt wird

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => i_clk,
      Rdy => io_trans_rec.Rdy,
      Ack => io_trans_rec.Ack
      );

      case io_trans_rec.Operation is
        when SEND | SEND_ASYNC =>
          Data := SafeResize(ModelID, io_trans_rec.DataToModel, Data'length);
          Push(TransmitFifo, Data);
          Increment(TransmitRequestCount);
          wait for 0 ns;
          if IsBlocking(io_trans_rec.Operation) then
            log("waiting until blocked send completed");
            wait until TransmitRequestCount = TransmitDoneCount;
            log("async wait completed");
          end if;

        when WAIT_FOR_TRANSACTION =>
          if TransmitRequestCount /= TransmitDoneCount then
            wait until TransmitRequestCount = TransmitDoneCount;
          end if;

        when WAIT_FOR_CLOCK =>
          WaitForClock(i_clk, io_trans_rec.IntToModel);

        when GET_TRANSACTION_COUNT =>
          io_trans_rec.IntFromModel <= TransmitDoneCount;

        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record. Transaction # " & to_string(io_trans_rec.Rdy), FAILURE);

        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(io_trans_rec.Operation), FAILURE);

      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  TransmitHandler : process is
    variable valid : std_logic;
    variable data  : std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
  begin
    -- initialize outputs
    o_valid <= '0';
    o_data  <= (data'range => 'X');
    wait for 0 ns;

    TransmitLoop : loop
      -- Find Transaction
      if IsEmpty(TransmitFifo) then
        WaitForToggle(TransmitRequestCount);
      end if;
      -- Get Transaction
      (data) := Pop(TransmitFifo);
      o_data <= data;
      DoAvalonStreamValidHandshake(i_clk, o_valid, i_ready, tpd_Clk_Valid, BusFailedID, "Valid Handshake timeout", AVALON_STREAM_READY_LATENCY * tperiod_Clk); -- the wait statement for o_data is covered in here;
     
      -- when done
      Increment(TransmitDoneCount);
      wait for 0 ns;
      -- Get Transaction

    end loop;
  end process TransmitHandler;

end bhv;
