--
--  File Name:         OsvvmTestCommonPkg.vhd
--  Design Unit Name:  Architecture of TestCtrl
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Locate the directory for the Validated Results
--      Alternately set CHECK_TRANSCRIPT to FALSE and Validated Results is not necessary
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    02/2025   2025.02    Static paths break.  Using VHDL-2019 FILE_PATH
--    10/2020   2020.10    Initial revision
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2020 by SynthWorks Design Inc.  
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

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

use osvvm.ScoreboardPkg_slv.all;


-- use std.env.all ; -- see osvvm/FileLinePathPkg.vhd

package AvalonST_test_component_pkg is
  constant RESULTS_DIR                         : string := "";
  constant PATH_TO_OsvvmTestCommonPkg          : string := FILE_PATH;
  constant AVALON_STREAM_VALIDATED_RESULTS_DIR : string := PATH_TO_OsvvmTestCommonPkg & "/../ValidatedResults";

  --  constant AXISTREAM_VALIDATED_RESULTS_DIR : string := std.env.FILE_PATH & "/../ValidatedResults" ;
  constant CHECK_TRANSCRIPT : boolean := PATH_TO_OsvvmTestCommonPkg'length > 0;

  procedure Avalon_Stream_Send(
    signal i_clk     : in  std_logic;
    signal i_ready   : in  std_logic;
    signal ModelID   : in  integer;
    signal io_trans_rec : in StreamRecType;
    signal o_data    : out std_logic_vector;
    signal o_valid   : out std_logic;
    constant tpd_Clk_oData : time;
    constant tpd_Clk_Valid : time;
    constant AVALON_STREAM_READY_LATENCY : integer
  );
end package AvalonST_test_component_pkg;

-- package body avalon_test_common_pkg is
--   procedure Avalon_Stream_Send(
--     signal i_clk     : in  std_logic;
--     signal i_ready   : in  std_logic;
--     signal ModelID   : in  integer;
--     signal io_trans_rec : in StreamRecType;
--     signal o_data    : out std_logic_vector;
--     signal o_valid   : out std_logic;
--     constant tpd_Clk_oData : time;
--     constant tpd_Clk_Valid : time;
--     constant AVALON_STREAM_READY_LATENCY : integer
-- ) is
-- begin
--     if (AVALON_STREAM_READY_LATENCY = 1) then
--         wait until rising_edge(i_clk) and i_ready = '1';
--         Log(ModelID, "Avalon Stream Send. data: " & to_hxstring(to_x01(SafeResize(io_trans_rec.DataToModel, o_data'length))), INFO);
--         o_data  <= SafeResize(io_trans_rec.DataToModel, o_data'length) after tpd_Clk_oData;
--         o_valid <= '1' after tpd_Clk_Valid;
--         wait until rising_edge(i_clk);
--         o_data  <= not o_data after tpd_Clk_oData;
--         o_valid <= '0' after tpd_Clk_Valid;
    
-- elsif (AVALON_STREAM_READY_LATENCY = 0) then
--         wait until rising_edge(i_clk);
--         Log(ModelID, "Avalon Stream Send. data: " & to_hxstring(to_x01(SafeResize(io_trans_rec.DataToModel, o_data'length))), INFO);
--         o_data  <= SafeResize(io_trans_rec.DataToModel, o_data'length) after tpd_Clk_oData;
--         o_valid <= '1' after tpd_Clk_Valid;
--         wait until rising_edge(i_clk) and i_ready = '1';
--         o_data  <= not o_data after tpd_Clk_oData;
--         o_valid <= '0' after tpd_Clk_Valid;
    
-- elsif (AVALON_STREAM_READY_LATENCY = -1) then
--         wait until rising_edge(i_clk);
--         Log(ModelID, "Avalon Stream Send. data: " & to_hxstring(to_x01(SafeResize(io_trans_rec.DataToModel, o_data'length))), INFO);
--         o_data  <= SafeResize(io_trans_rec.DataToModel, o_data'length) after tpd_Clk_oData;
--         o_valid <= '1' after tpd_Clk_Valid;
--         wait until rising_edge(i_clk);
--         o_data  <= not o_data after tpd_Clk_oData;
--         o_valid <= '0' after tpd_Clk_Valid;
--     end if;
-- end procedure Avalon_Stream_Send;
-- end package body avalon_test_common_pkg;
