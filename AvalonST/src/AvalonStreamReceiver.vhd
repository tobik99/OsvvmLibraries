library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
context osvvm.OsvvmContext;

use osvvm.ScoreboardPkg_slv.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonST_context;

entity AvalonStreamReceiver is
  generic (
    MODEL_ID_NAME      : string  := "";
    DEFAULT_DATA_WIDTH : integer := 32;
    DEFAULT_DELAY      : time    := 1 ns;
    tpd_Clk_Ready    : time    := DEFAULT_DELAY
  );
  port (
    i_clk    : in std_logic;
    i_nreset : in std_logic;
    -- DUT signals
    i_valid : in std_logic := '0';
    i_data  : in std_logic_vector(DEFAULT_DATA_WIDTH - 1 downto 0);
    o_ready : out std_logic;

    -- testbench record
    io_trans_rec : inout StreamRecType
  );

  -- Derive AXI interface properties from interface signals
  constant AVALON_STREAM_DATA_WIDTH : integer := i_data'length;
  -- Use MODEL_ID_NAME Generic if set, otherwise,
  -- use model instance label (preferred if set as entityname_1)
  constant MODEL_INSTANCE_NAME : string :=
  ifelse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME,
  to_lower(PathTail(AvalonStreamReceiver'PATH_NAME)));

end AvalonStreamReceiver;

architecture bhv of AvalonStreamReceiver is
  signal ModelID, BusFailedID : AlertLogIDType;

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
    wait;
  end process Initialize;

  ---------------------------

  TransactionDispatcher : process is
  begin
    o_ready <= '1';
    wait for 0 ns; -- Lassen, damit ModelID gesetzt wird

    TransactionDispatcherLoop : loop
      WaitForTransaction(
      Clk => i_clk,
      Rdy => io_trans_rec.Rdy,
      Ack => io_trans_rec.Ack
      );

      case io_trans_rec.Operation is
        when GET =>
          wait until rising_edge(i_clk) and i_valid = '1';
          io_trans_rec.DataFromModel  <= SafeResize(ModelID, i_data, io_trans_rec.DataFromModel'length) ;
          o_ready <= '0' after tpd_Clk_Ready;
          wait for 0 ns;
          Log(ModelID, "Avalon Stream Get." & "data: " & to_hxstring(to_x01(SafeResize(io_trans_rec.DataFromModel, i_data'length))), INFO);
          wait until rising_edge(i_clk);
          
          o_ready <= '1' after tpd_Clk_Ready;


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
end bhv;
