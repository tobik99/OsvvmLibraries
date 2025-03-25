library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;



entity AvalonStreamTestHarness is
end entity AvalonStreamTestHarness;
architecture bhv of AvalonStreamTestHarness is

  constant tperiod_Clk : time := 10 ns;
  constant tpd         : time := 2 ns;

  signal clk    : std_logic := '1';
  signal nreset : std_logic;

  signal ready : std_logic;
  signal data  : std_logic_vector(31 downto 0);
  signal valid : std_logic;

  signal tx_trans_rec, rx_trans_rec : StreamRecType(
  DataToModel (32 - 1 downto 0),
  DataFromModel (32 - 1 downto 0),
  ParamToModel (32 - 1 downto 0),
  ParamFromModel(32 - 1 downto 0)
  );

begin

  -- create Clock 
  Osvvm.ClockResetPkg.CreateClock (
  Clk    => Clk,
  Period => Tperiod_Clk
  );

  -- create nReset 
  Osvvm.ClockResetPkg.CreateReset (
  Reset       => nReset,
  ResetActive => '0',
  Clk         => clk,
  Period      => 7 * tperiod_Clk,
  tpd         => tpd
  );

  AvalonStreamTransmitter_VC : entity osvvm_avalonst.AvalonStreamTransmitter(bhv)
    generic map(
      MODEL_ID_NAME      => "AvalonStreamTransmitter",
      AVALON_STREAM_DATA_WIDTH => 32,
      AVALON_STREAM_READY_LATENCY => 0,
      DEFAULT_DELAY      => 1 ns,
      tpd_Clk_Valid      => 1 ns,
      tpd_Clk_oData      => 1 ns
    )
    port map(
      i_clk        => clk,
      i_nreset     => nreset,
      o_valid      => valid,
      o_data       => data,
      i_ready      => ready,
      io_trans_rec => tx_trans_rec
    );

  AvalonSreamReceiver_VC : entity osvvm_avalonst.AvalonStreamReceiver(bhv)
    generic map(
      MODEL_ID_NAME      => "AvalonSreamReceiver",
      AVALON_STREAM_DATA_WIDTH => 32,
      AVALON_STREAM_READY_LATENCY => 0,
      DEFAULT_DELAY      => 1 ns,
      tpd_Clk_oReady      => 1 ns
    )
    port map(
      i_clk        => clk,
      i_nreset     => nreset,
      i_valid      => valid,
      i_data       => data,
      o_ready      => ready,
      io_trans_rec => rx_trans_rec
    );

  -- DUT
  -- test
  TestCtrl_2 : entity osvvm_avalonst.AvalonST_TestCtrl(SendGetLatency)
    port map(
      -- Globals
      i_nreset => nreset,
      i_clk    => clk,
     
      -- Transaction Record
      io_tx_trans_rec => tx_trans_rec,
      io_rx_trans_rec => rx_trans_rec
    );
end architecture bhv;
