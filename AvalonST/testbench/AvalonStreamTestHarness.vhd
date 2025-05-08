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
  constant AvalonStreamDataWidth : integer := 32;
  constant AvalonStreamSymbolWidth : integer := 16;

  signal Clk   : std_logic := '1';
  signal Reset : std_logic := '0';

  signal Ready         : std_logic;
  signal Data          : std_logic_vector(31 downto 0);
  signal Valid         : std_logic;
  signal StartOfPacket : std_logic;
  signal EndOfPacket   : std_logic;
  signal Empty         : std_logic_vector(AvalonStreamDataWidth/AvalonStreamSymbolWidth - 1 downto 0);

  signal StreamRxRec, StreamTxRec : StreamRecType(
  DataToModel (AvalonStreamDataWidth - 1 downto 0),
  DataFromModel (AvalonStreamDataWidth - 1 downto 0),
  ParamToModel (AvalonStreamDataWidth - 1 downto 0),
  ParamFromModel(AvalonStreamDataWidth - 1 downto 0)
  );
  component AvalonST_TestCtrl is
    port (
      -- Global Signal Interface
      Reset : in std_logic;
      Clk   : in std_logic;
  
      -- Record Interface
      StreamTxRec : inout StreamRecType;
      StreamRxRec : inout StreamRecType
    );
    end component AvalonST_TestCtrl;
begin

  -- create Clock 
  Osvvm.ClockResetPkg.CreateClock (
  Clk    => Clk,
  Period => Tperiod_Clk
  );

  -- create nReset 
  Osvvm.ClockResetPkg.CreateReset (
  Reset       => Reset,
  ResetActive => '0',
  Clk         => Clk,
  Period      => 2 * tperiod_Clk,
  tpd         => tpd
  );

  AvalonStreamTransmitter_VC : entity osvvm_avalonst.AvalonStreamTransmitter(bhv)
    generic map(
      MODEL_ID_NAME            => "AvalonStreamTransmitter",
      AVALON_STREAM_DATA_WIDTH => AvalonStreamDataWidth,
      AVALON_STREAM_SYMBOL_WIDTH => AvalonStreamSymbolWidth,
      DEFAULT_DELAY            => 1 ns,
      tpd_Clk_Valid            => 1 ns,
      tpd_Clk_Data            => 1 ns
    )
    port map(
      Clk           => Clk,
      Reset         => Reset,
      Valid         => Valid,
      Data          => Data,
      Ready         => Ready,
      StartOfPacket => StartOfPacket,
      EndOfPacket   => EndOfPacket,
      Empty         => Empty,
      TransRec      => StreamTxRec
    );

  AvalonSreamReceiver_VC : entity osvvm_avalonst.AvalonStreamReceiver(bhv)
    generic map(
      MODEL_ID_NAME               => "AvalonSreamReceiver",
      AVALON_STREAM_DATA_WIDTH => AvalonStreamDataWidth,
      AVALON_STREAM_SYMBOL_WIDTH => AvalonStreamSymbolWidth,
      DEFAULT_DELAY               => 1 ns,
      tpd_Clk_oReady              => 1 ns
    )
    port map(
      Clk           => Clk,
      Reset         => Reset,
      Valid         => Valid,
      Data          => Data,
      Ready         => Ready,
      StartOfPacket => StartOfPacket,
      EndOfPacket   => EndOfPacket,
      Empty         => Empty,
      TransRec      => StreamRxRec
    );

  -- DUT
  -- test
  TestCtrl_1 : entity osvvm_avalonst.AvalonST_TestCtrl
    port map(
      -- Globals
      Reset => Reset,
      Clk   => Clk,

      -- Transaction Record
      StreamTxRec => StreamTxRec,
      StreamRxRec => StreamRxRec
    );
end architecture bhv;
