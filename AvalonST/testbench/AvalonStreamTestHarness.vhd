--
--  File Name:         TbStream.vhd
--  Design Unit Name:  TbStream
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Top level testbench for AxiStreamTransmitter and AxiStreamReceiver
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    07/2024   2024.07    Updated CreateClock
--    01/2023   2023.01    Added DUT (pass thru)
--    10/2020   2020.10    Updated name to be TbStream.vhd in conjunction with Model Indepenedent Transactions
--    01/2020   2020.01    Updated license notice
--    05/2018   2018.05    Initial revision
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2018 - 2024 by SynthWorks Design Inc.  
--  
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--  
--      https://www.apache.org/licenses/LICENSE-2.0
--  
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--  
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_avalonst;
context osvvm_avalonst.AvalonStreamContext;
use osvvm_avalonst.AvalonStreamReceiver;
use osvvm_avalonst.AvalonStreamTransmitter;



entity AvalonST_test_harness is
end entity AvalonST_test_harness;
architecture AvalonST_test_harness_arch of AvalonST_test_harness is

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

  AvalonStreamTransmitter_VC : entity osvvm_avalonst.AvalonStreamTransmitter
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

  AvalonSreamReceiver_VC : entity osvvm_avalonst.AvalonStreamReceiver
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
end architecture AvalonST_test_harness_arch;
