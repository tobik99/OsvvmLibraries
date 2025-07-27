
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;

entity AvalonST_TestCtrl is
  generic (
    CHANNEL_LEN : integer;
    EMPTY_LEN : integer
  );
  port (
    -- Global Signal Interface
    Reset : in std_logic;
    Clk : in std_logic;

    -- Record Interface
    StreamTxRec : inout StreamRecType;
    StreamRxRec : inout StreamRecType
  );

  -- Derive AvalonStream interface properties from the StreamTxRec
  constant DATA_WIDTH : integer := StreamTxRec.DataToModel'length;

  alias TxPacketFifo : ScoreboardIdType is StreamTxRec.BurstFifo;
  alias RxPacketFifo : ScoreboardIdType is StreamRxRec.BurstFifo;
end AvalonST_TestCtrl;