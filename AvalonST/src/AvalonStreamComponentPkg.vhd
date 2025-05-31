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
use osvvm.ScoreboardPkg_slv.all;

library osvvm_common;
context osvvm_common.OsvvmCommonContext; -- for MIT StreamRecType

--use work.AvalonST_tb_pkg.all;

package AvalonStreamComponentPkg is
  component AvalonStreamTransmitter is
    generic (
      MODEL_ID_NAME            : string  := "";
      AVALON_STREAM_DATA_WIDTH : integer := 8;
      DEFAULT_DELAY            : time    := 1 ns;
      tpd_Clk_Data             : time    := DEFAULT_DELAY;
      tpd_Clk_Valid            : time    := DEFAULT_DELAY;
      tpd_Clk_StartOfPacket    : time    := DEFAULT_DELAY;
      tpd_Clk_EndOfPacket      : time    := DEFAULT_DELAY;
      tpd_Clk_Empty            : time    := DEFAULT_DELAY
    );
    port (
      Clk   : in std_logic;
      Reset : in std_logic;
      -- DUT signals
      Valid         : out std_logic := '0';
      Data          : out std_logic_vector(AVALON_STREAM_DATA_WIDTH - 1 downto 0);
      StartOfPacket : out std_logic := '0';
      EndOfPacket   : out std_logic := '0';
      Empty         : out std_logic := '0';
      --Empty : std_logic_vector(AVALON_STREAM_DATA_WIDTH - )
      Ready : in std_logic;

      -- testbench record
      TransRec : inout StreamRecType);
  end component AvalonStreamTransmitter;
  ------------------------------------------------------------
  procedure DoAvalonStreamValidHandshake (
    ------------------------------------------------------------
    signal Clk                       : in std_logic;
    signal Valid                     : out std_logic;
    signal Ready                     : in std_logic;
    signal StartOfNewStream          : in integer;
    constant ReadyLatency            : in integer;
    constant ReadyAllowance          : in integer;
    signal ReadyAllowanceCyclesCount : inout integer;
    constant tpd_Clk_Valid           : in time;
    constant AlertLogID              : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage          : in string         := "";
    constant TimeOutPeriod           : in time           := - 1 sec
  );

  ------------------------------------------------------------
  procedure DoAvalonStreamReadyHandshake (
    ------------------------------------------------------------
    signal Clk                : in std_logic;
    signal Valid              : in std_logic;
    signal Ready              : inout std_logic;
    constant WordRequestCount : in integer;
    constant WordReceiveCount : in integer;
    constant ReadyAllowance   : in integer;
    constant ReadyBeforeValid : in boolean;
    constant ReadyDelayCycles : in time;
    constant tpd_Clk_Ready    : in time;
    constant AlertLogID       : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage   : in string         := "";
    constant TimeOutPeriod    : in time           := - 1 sec
  );

  procedure DoAvalonStreamPacketReadyHandshake (
    signal Clk              : in std_logic;
    signal Valid            : in std_logic;
    signal Ready            : inout std_logic;
    signal StartOfPacket    : in std_logic;
    signal EndOfPacket      : in std_logic;
    signal Data             : in std_logic_vector;
    signal TransRec         : inout StreamRecType;
    signal WordsInPacket    : inout integer;
    constant BeatsPerCycle  : in integer;
    constant ByteOrder      : in boolean;
    constant WordWidth      : in integer;
    constant SymbolWidth    : in integer;
    constant tpd_Clk_Ready  : in time;
    constant AlertLogID     : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage : in string         := "";
    constant TimeOutPeriod  : in time           := - 1 sec
  );

  procedure DoPrepareTransmitData (
    signal Data            : out std_logic_vector;
    signal Channel         : out std_logic_vector;
    signal Empty           : out std_logic_vector;
    signal Scoreboard      : inout ScoreboardIdType;
    variable EmptyBeats    : inout integer;
    constant BurstFifoMode : in StreamFifoBurstModeType;
    constant BeatsPerCycle : in integer;
    constant ByteOrder     : in boolean;
    constant WordWidth     : in integer;
    constant SymbolWidth   : in integer
  );

  procedure WaitForReady (
    signal Clk          : in std_logic;
    signal Ready        : in std_logic;
    constant TimeOut    : in time;
    constant AlertLogID : in AlertLogIDType;
    constant Msg        : in string
  );

  procedure ReverseSymbolOrder (
    variable Data        : inout std_logic_vector;
    constant SymbolWidth : in integer;
    constant TotalWidth  : in integer
  );

end package AvalonStreamComponentPkg;

-- /////////////////////////////////////////////////////////////////////////////////////////
-- /////////////////////////////////////////////////////////////////////////////////////////

package body AvalonStreamComponentPkg is

  procedure DoAvalonStreamValidHandshake (
    signal Clk                       : in std_logic;
    signal Valid                     : out std_logic;
    signal Ready                     : in std_logic;
    signal StartOfNewStream          : in integer;
    constant ReadyLatency            : in integer;
    constant ReadyAllowance          : in integer;
    signal ReadyAllowanceCyclesCount : inout integer;
    constant tpd_Clk_Valid           : in time;
    constant AlertLogID              : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage          : in string         := "";
    constant TimeOutPeriod           : in time           := - 1 sec
  ) is
  begin
    if Ready = '1' then
      Valid <= '1' after tpd_Clk_Valid;

    elsif StartOfNewStream = 1 then
      ReadyAllowanceCyclesCount <= ReadyAllowance;

      if ReadyLatency > 0 then
        WaitForReady(Clk, Ready, TimeOutPeriod, AlertLogID, TimeOutMessage);
        for i in 1 to ReadyLatency loop
          wait until Clk = '1';
        end loop;
      end if;

      Valid <= '1' after tpd_Clk_Valid;

    elsif StartOfNewStream = 0 then
      if ReadyAllowance > ReadyLatency then
        if Ready = '0' and ReadyAllowanceCyclesCount > 0 then
          ReadyAllowanceCyclesCount <= ReadyAllowanceCyclesCount - 1;
          Valid                     <= '1' after tpd_Clk_Valid;
        elsif Ready = '0' then
          Valid <= '0' after tpd_Clk_Valid;
        else
          Alert(AlertLogID, "Failure in ReadyAllowance, this alert should not be reached!", FAILURE);
        end if;

      elsif ReadyAllowance = ReadyLatency then
        Valid <= '1' after tpd_Clk_Valid;
        if Ready /= '1' then
          WaitForReady(Clk, Ready, TimeOutPeriod, AlertLogID, TimeOutMessage);
          Valid <= '0'; -- ggf. je nach Verhalten überdenken
        end if;
      end if;
    end if;

    wait until Clk = '1';
  end procedure;

  ------------------------------------------------------------
  procedure DoAvalonStreamReadyHandshake (
    ------------------------------------------------------------
    signal Clk                : in std_logic;
    signal Valid              : in std_logic;
    signal Ready              : inout std_logic;
    constant WordRequestCount : in integer;
    constant WordReceiveCount : in integer;
    constant ReadyAllowance   : in integer;
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
    else
      Ready <= transport '0' after ReadyDelayCycles + tpd_Clk_Ready;
    end if;
    if (ReadyAllowance > 0) and ((WordReceiveCount + ReadyAllowance) >= WordRequestCount) then
      Ready <= '0' after tpd_Clk_Ready;
    end if;

    -- Wait to Receive Transaction
    if TimeOutPeriod > 0 sec then
      wait on Clk until Clk = '1' and Valid = '1' for TimeOutPeriod;
    else
      wait on Clk until Clk = '1' and Valid = '1';
    end if;

    if Valid = '1' then
      if ReadyAllowance > 0 and (WordReceiveCount + ReadyAllowance >= WordRequestCount) then
        AlertIf(AlertLogID, Valid /= '1', "this alert should never be reached", FAILURE);
      else
        if not ReadyBeforeValid then
          Ready <= '1' after ReadyDelayCycles + tpd_Clk_Ready;
        end if;
        -- If ready not signaled yet, find ready at a rising edge of clk
        if Ready /= '1' then
          wait on Clk until Clk = '1' and (Ready = '1' or Valid /= '1');
          AlertIf(AlertLogID, Valid /= '1', TimeOutMessage & " Valid (" & to_string(Valid) & ") " &
          "deasserted before Ready asserted (" & to_string(Ready) & ") ",
          FAILURE
          );
        end if;
      end if;
    else
      -- TimeOut handling
      Alert(
      AlertLogID,
      TimeOutMessage & " Valid: " & to_string(Valid) & "  Expected: 1",
      FAILURE
      );
    end if;
  end procedure DoAvalonStreamReadyHandshake;

  ------------------------------------------------------------

  procedure DoAvalonStreamPacketReadyHandshake (
    signal Clk              : in std_logic;
    signal Valid            : in std_logic;
    signal Ready            : inout std_logic;
    signal StartOfPacket    : in std_logic;
    signal EndOfPacket      : in std_logic;
    signal Data             : in std_logic_vector;
    signal TransRec         : inout StreamRecType;
    signal WordsInPacket    : inout integer;
    constant BeatsPerCycle  : in integer;
    constant ByteOrder      : in boolean;
    constant WordWidth      : in integer;
    constant SymbolWidth    : in integer;
    constant tpd_Clk_Ready  : in time;
    constant AlertLogID     : in AlertLogIDType := ALERTLOG_DEFAULT_ID;
    constant TimeOutMessage : in string         := "";
    constant TimeOutPeriod  : in time           := - 1 sec
  ) is
    variable vData : std_logic_vector(Data'range) := (others => 'X');
  begin
    WordsInPacket <= 0;
    loop
      Ready <= '1' after tpd_Clk_Ready;

      if TimeOutPeriod > 0 sec then
        wait on Clk until Clk = '1' and Valid = '1' and StartOfPacket = '1' for TimeOutPeriod;
      else
        wait on Clk until Clk = '1' and Valid = '1' and StartOfPacket = '1';
      end if;
      -- start of packet
      vData := Data;
      if ByteOrder then
        ReverseSymbolOrder(vData, SymbolWidth, Data'length);
      end if;
      for i in 0 to BeatsPerCycle - 1 loop
        push(
        TransRec.BurstFifo,
        vData((i + 1) * WordWidth - 1 downto i * WordWidth)
        );
      end loop;
      Log(AlertLogID, "PacketTransfer: Received Word: " & to_hxstring(vData), INFO);
      WordsInPacket <= WordsInPacket + 1;
      exit when Valid = '1' and StartOfPacket = '1';
    end loop;
    loop
      -- in packet
      Ready <= '1' after tpd_Clk_Ready;

      if TimeOutPeriod > 0 sec then
        wait on Clk until Clk = '1' and Valid = '1' for TimeOutPeriod;
      else
        wait on Clk until Clk = '1' and Valid = '1';
      end if;

      if Valid = '1' then
        vData := Data;
        if ByteOrder then
          ReverseSymbolOrder(vData, SymbolWidth, Data'length);
        end if;
        for i in 0 to BeatsPerCycle - 1 loop
          push(
          TransRec.BurstFifo,
          vData((i + 1) * WordWidth - 1 downto i * WordWidth)
          );
        end loop;
        Log(AlertLogID, "PacketTransfer: Received Word: " & to_hxstring(vData), INFO);
        WordsInPacket <= WordsInPacket + 1;
        wait for 0 ns;
        exit when EndOfPacket = '1';
      else
        Alert(AlertLogID, TimeOutMessage & " Valid: " & to_string(Valid) & "  Expected: 1", FAILURE);
      end if;
    end loop;
    Ready <= '0' after tpd_Clk_Ready;
    -- packet received
    wait for 0 ns;
  end procedure;
  -------------------------------------------------------------
  procedure WaitForReady (
    signal Clk          : in std_logic;
    signal Ready        : in std_logic;
    constant TimeOut    : in time;
    constant AlertLogID : in AlertLogIDType;
    constant Msg        : in string
  ) is
  begin
    if TimeOut > 0 sec then
      wait on Clk until Clk = '1' and Ready = '1' for TimeOut;
      if Ready /= '1' then
        Alert(AlertLogID, Msg & ".  Ready: " & to_string(Ready) & "  Expected: 1", FAILURE);
        wait until Clk = '1';
      end if;
    else
      wait on Clk until Clk = '1' and Ready = '1';
    end if;
  end procedure;

  -------------------------------------------------------------
  procedure ReverseSymbolOrder (
    variable Data        : inout std_logic_vector;
    constant SymbolWidth : in integer;
    constant TotalWidth  : in integer
  ) is
    variable SymbolCount   : integer;
    variable vDataReversed : std_logic_vector(Data'range) := (others => 'X');
  begin
    SymbolCount := TotalWidth / SymbolWidth;
    for i in 0 to SymbolCount - 1 loop
      vDataReversed((SymbolCount - i) * SymbolWidth - 1 downto (SymbolCount - i - 1) * SymbolWidth) :=
      Data((i + 1) * SymbolWidth - 1 downto i * SymbolWidth);
    end loop;
    Data := vDataReversed;
  end procedure;
  procedure DoPrepareTransmitData (
    signal Data            : out std_logic_vector;
    signal Channel         : out std_logic_vector;
    signal Empty           : out std_logic_vector;
    signal Scoreboard      : inout ScoreboardIdType;
    variable EmptyBeats    : inout integer;
    constant BurstFifoMode : in StreamFifoBurstModeType;
    constant BeatsPerCycle : in integer;
    constant ByteOrder     : in boolean;
    constant WordWidth     : in integer;
    constant SymbolWidth   : in integer
  ) is
    variable vData       : std_logic_vector(WordWidth - 1 downto 0) := (others => 'U');
    variable vEmptyBeats : integer                                  := 0;
    variable vChannel    : std_logic_vector(Channel'range);
    variable vEmpty      : std_logic_vector(Empty'range);
    variable vLast       : std_logic;
  begin
    case BurstFifoMode is
      when STREAM_BURST_WORD_MODE =>
        for i in 0 to (BeatsPerCycle - 1) loop
          if IsEmpty(Scoreboard) then
            Data((WordWidth - 1) + WordWidth * i downto WordWidth * i) <= (others => 'U');
            vEmptyBeats := vEmptyBeats + 1;
          else
            (vData, vChannel, vEmpty, vLast) := Pop(Scoreboard);
            Data((WordWidth - 1) + WordWidth * i downto WordWidth * i) <= vData;
          end if;
        end loop;
      when others =>
        vData(WordWidth - 1 downto 0) := Pop(Scoreboard);
        if (ByteOrder = true) then
          ReverseSymbolOrder(vData, SymbolWidth, WordWidth);
        end if;
        Data(WordWidth - 1 downto 0) <= vData(WordWidth - 1 downto 0);
    end case;
    EmptyBeats := vEmptyBeats;
  end procedure;
end package body AvalonStreamComponentPkg;
