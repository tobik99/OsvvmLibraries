--
--  File Name:         UartTxComponentPkg.vhd
--  Design Unit Name:  UartTxComponentPkg
--  OSVVM Release:     OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Component in package to facilitate usage of component instantiation
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    05/2019   2019.05    Updated for OSVVM public release
--    01/2020   2020.01    Updated license notice
--
--
--  This file is part of OSVVM.
--
--  Copyright (c) 2019 - 2020 by SynthWorks Design Inc.
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

library osvvm;
context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext; -- for MIT StreamRecType

--use work.AvalonST_tb_pkg.all;

package AvalonStreamComponentPkg is
  component AvalonStreamingSource is
    generic (
      MODEL_ID_NAME      : string  := "";
      DEFAULT_DATA_WIDTH : integer := 8;
      DEFAULT_DELAY      : time    := 1 ns;
      tpd_Clk_Address    : time    := DEFAULT_DELAY;
      tpd_Clk_Write      : time    := DEFAULT_DELAY;
      tpd_Clk_oData      : time    := DEFAULT_DELAY
    );
    port (
      -- global signals
      i_clk    : in std_logic;
      i_nreset : in std_logic;
      -- testbench transaction interface
      io_trans_rec : inout StreamRecType;
      -- AvalonST functional interface
      o_data  : out std_logic_vector(DEFAULT_DATA_WIDTH - 1 downto 0);
      o_valid : out std_logic;
      i_ready : in std_logic
    );
  end component AvalonStreamingSource;
  ------------------------------------------------------------
  procedure DoAvalonStreamValidHandshake (
    ------------------------------------------------------------
    signal Clk              : in std_logic;
    signal Valid            : out std_logic;
    signal Ready            : in std_logic;
    constant tpd_Clk_Valid  : in time;
    constant AlertLogID     : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage : in string         := "";
    constant TimeOutPeriod  : in time           := - 1 sec
  );

  ------------------------------------------------------------
  procedure DoAvalonStreamReadyHandshake (
    ------------------------------------------------------------
    signal Clk                : in std_logic;
    signal Valid              : in std_logic;
    signal Ready              : inout std_logic;
    constant ReadyBeforeValid : in boolean;
    constant ReadyDelayCycles : in time;
    constant tpd_Clk_Ready    : in time;
    constant AlertLogID       : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage   : in string         := "";
    constant TimeOutPeriod    : in time           := - 1 sec
  );

end package AvalonStreamComponentPkg;

-- /////////////////////////////////////////////////////////////////////////////////////////
-- /////////////////////////////////////////////////////////////////////////////////////////

package body AvalonStreamComponentPkg is

  ------------------------------------------------------------
  procedure DoAvalonStreamValidHandshake (
    ------------------------------------------------------------
    signal Clk              : in std_logic;
    signal Valid            : out std_logic;
    signal Ready            : in std_logic;
    constant tpd_Clk_Valid  : in time;
    constant AlertLogID     : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage : in string         := "";
    constant TimeOutPeriod  : in time           := - 1 sec
  ) is
  begin

    Valid <= '1' after tpd_Clk_Valid;

    if TimeOutPeriod > 0 sec then
      wait on Clk until Clk = '1' and Ready = '1' for TimeOutPeriod;
    else
      wait on Clk until Clk = '1' and Ready = '1';
    end if;

    Valid <= '0' after tpd_Clk_Valid;

    if Ready /= '1' then
      -- Check for TimeOut
      Alert(
      AlertLogID,
      TimeOutMessage & ".  Ready: " & to_string(Ready) & "  Expected: 1",
      FAILURE
      );
      wait until Clk = '1';
    end if;
  end procedure DoAvalonStreamValidHandshake;

  ------------------------------------------------------------
  procedure DoAvalonStreamReadyHandshake (
    ------------------------------------------------------------
    signal Clk                : in std_logic;
    signal Valid              : in std_logic;
    signal Ready              : inout std_logic;
    constant ReadyBeforeValid : in boolean;
    constant ReadyDelayCycles : in time;
    constant tpd_Clk_Ready    : in time;
    constant AlertLogID       : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage   : in string         := "";
    constant TimeOutPeriod    : in time           := - 1 sec
  ) is
  begin

    if ReadyBeforeValid then
      Ready <= transport '1' after ReadyDelayCycles + tpd_Clk_Ready;
    end if;

    -- Wait to Receive Transaction
    if TimeOutPeriod > 0 sec then
      wait on Clk until Clk = '1' and Valid = '1' for TimeOutPeriod;
    else
      wait on Clk until Clk = '1' and Valid = '1';
    end if;

    if Valid = '1' then
      -- Proper handling
      if not ReadyBeforeValid then
        Ready <= '1' after ReadyDelayCycles + tpd_Clk_Ready;
      end if;

      -- If ready not signaled yet, find ready at a rising edge of clk
      if Ready /= '1' then
        wait on Clk until Clk = '1' and (Ready = '1' or Valid /= '1');
        AlertIf(
        AlertLogID,
        Valid /= '1',
        TimeOutMessage &
        " Valid (" & to_string(Valid) & ") " &
        "deasserted before Ready asserted (" & to_string(Ready) & ") ",
        FAILURE
        );
      end if;
    else
      -- TimeOut handling
      Alert(
      AlertLogID,
      TimeOutMessage & " Valid: " & to_string(Valid) & "  Expected: 1",
      FAILURE
      );
    end if;

    -- End of operation
    Ready <= '0' after tpd_Clk_Ready;

    if Valid /= '1' then
      -- TimeOut or Valid deasserted after before Ready asserted
      wait until Clk = '1';
    end if;
  end procedure DoAvalonStreamReadyHandshake;

end package body AvalonStreamComponentPkg;
