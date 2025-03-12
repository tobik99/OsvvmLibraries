

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;
use osvvm.ScoreboardPkg_slv.all;

--use work.UartTbPkg.all ;
--use osvvm.AvalonStreamingTbPkg.all; -- Falls du eine OSVVM-Testbench-Erweiterung machst

entity AvalonStreamingSource is
  generic (
    MODEL_ID_NAME      : string  := "";
    DEFAULT_DATA_WIDTH : integer := 32;
    DEFAULT_CHANNELS   : integer := 1
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;
    -- DUT signals
    o_valid : out std_logic := '0';
    o_data  : out std_logic_vector(DEFAULT_DATA_WIDTH - 1 downto 0);
    i_ready : in std_logic;

    -- testbench record
    TransRec : inout StreamRecType
  );

  -- Derive AXI interface properties from interface signals
  constant AVALON_STREAM_DATA_WIDTH : integer := o_data'length;
  -- Use MODEL_ID_NAME Generic if set, otherwise,
  -- use model instance label (preferred if set as entityname_1)
  constant MODEL_INSTANCE_NAME : string :=
  ifelse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME,
  to_lower(PathTail(AvalonStreamingSource'PATH_NAME)));

end AvalonStreamingSource;

architecture model of AvalonStreamingSource is
  signal ModelID, BusFailedID : AlertLogIDType;

  signal TransmitFifo : osvvm.ScoreboardPkg_slv.ScoreboardIDType;

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
    BusFailedID  <= NewID("No response", ID);
    TransmitFifo <= NewID("TransmitFifo", ID, ReportMode => DISABLED, Search => PRIVATE_NAME);
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process
    variable Data : std_logic_vector(o_data'length);
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
          Data := SafeResize(ModelID, TransRec.DataToModel, Data'length);
          Push(TransmitFifo, '0' & Data);
          Increment(TransmitRequestCount);
          wait for 0 ns;
          if IsBlocking(TransRec.Operation) then
            wait until TransmitRequestCount = TransmitDoneCount;
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

        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(TransRec.Operation), FAILURE);

      end case;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;
  TransmitHandler : process
    variable valid : std_logic;
    variable data  : std_logic_vector(o_data'length - 1 downto 0);
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
      (data, valid) := Pop(TransmitFifo);

      -- Do Transaction TODO where is the delta-cycle performed?
      o_data  <= data;
      o_valid <= valid;

      Log(ModelID, "Avalon Stream Send." & "data: " & to_hxstring(to_x01(data)), INFO);

      -- State after transaction
      o_data  <= (o_data'range => 'X');
      o_valid <= '0';

      -- Signal completion
      Increment(TransmitDoneCount);
      wait for 0 ns;
    end loop;
  end process TransmitHandler;

end model;
