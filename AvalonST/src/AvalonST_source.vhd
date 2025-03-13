library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
context osvvm.OsvvmContext;

use osvvm.ScoreboardPkg_slv.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonST_context;
--use osvvm_avalonst.AvalonST_tb_pkg.all; -- for rec_avalon_stream

entity AvalonStreamingSource is
  generic (
    MODEL_ID_NAME      : string  := "";
    DEFAULT_DATA_WIDTH : integer := 32;
    DEFAULT_DELAY      : time    := 1 ns;
    tpd_Clk_Address    : time    := DEFAULT_DELAY;
    tpd_Clk_Valid      : time    := DEFAULT_DELAY;
    tpd_Clk_oData      : time    := DEFAULT_DELAY
    --DEFAULT_CHANNELS   : integer := 1
  );
  port (
    i_clk    : in std_logic;
    i_nreset : in std_logic;
    -- DUT signals
    o_valid : out std_logic := '0';
    o_data  : out std_logic_vector(DEFAULT_DATA_WIDTH - 1 downto 0);
    i_ready : in std_logic;

    -- testbench record
    io_trans_rec : inout StreamRecType
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

  TransactionDispatcher : process is
    variable Data : std_logic_vector(o_data'range);
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
          --Data := SafeResize(ModelID, io_trans_rec.DataToModel, Data'length);
          --Push(TransmitFifo, '0' & Data);
          --Increment(TransmitRequestCount);
          --wait for 0 ns;
          --if IsBlocking(io_trans_rec.Operation) then
          --  wait until TransmitRequestCount = TransmitDoneCount;
          --end if;
          o_data  <= SafeResize(io_trans_rec.DataToModel, o_data'length) after tpd_Clk_oData;
          o_valid <= '1' after tpd_Clk_Valid;
          WaitForClock(i_clk);
          Log(ModelID, "Avalon Stream Send." & "data: " & to_hxstring(to_x01(o_data)), INFO);
          o_data  <= not o_data after tpd_Clk_oData;
          o_valid <= '0' after tpd_Clk_Valid;

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
  --TransmitHandler : process is
  --  variable valid : std_logic;
  --  variable data  : std_logic_vector(o_data'length - 1 downto 0);
  --begin
  --  -- initialize outputs
  --  o_valid <= '0';
  --  o_data  <= (data'range => 'X');
  --  wait for 0 ns;
  --
  --  TransmitLoop : loop
  --    -- Find Transaction
  --    if IsEmpty(TransmitFifo) then
  --      WaitForToggle(TransmitRequestCount);
  --    end if;
  --
  --    -- Get Transaction
  --    -- this is just a hack...
  --    --(data, valid) := Pop(TransmitFifo);
  --
  --    o_data  <= SafeResize(ModelID, io_trans_rec.DataToModel, Data'length);
  --    o_valid <= '1';
  --    wait for 20 ns;
  --
  --    Log(ModelID, "Avalon Stream Send." & "data: " & to_hxstring(to_x01(data)), INFO);
  --
  --    -- State after transaction
  --    o_data  <= (o_data'range => 'X');
  --    o_valid <= '0';
  --
  --    -- Signal completion
  --    Increment(TransmitDoneCount);
  --    wait for 0 ns;
  --  end loop;
  --end process TransmitHandler;

end model;
