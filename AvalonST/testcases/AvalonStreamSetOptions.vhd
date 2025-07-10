--
--  File Name:         TbStream_AxiSetOptions2.vhd
--  Design Unit Name:  Architecture of TestCtrl
--  Revision:          OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Validates Stream Model Independent Transactions
--      Send, Get, Check with 2nd parameter, with ID, Dest, User
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    10/2020   2020.10    Initial revision
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2018 - 2020 by SynthWorks Design Inc.  
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
architecture AvalonStreamSetOptions of AvalonST_TestCtrl is

  signal TestDone : integer_barrier := 1;
  constant MAX_LEN : integer := maximum(CHANNEL_LEN, EMPTY_LEN);
  constant DASH : std_logic_vector(MAX_LEN - 1 downto 0) := (others => '-');
  constant cAvalonStreamDataWidth : integer         := 32;
  constant cNumOfWords : integer := 2;
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetTestName("AvalonStreamSetOptions");
    SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
    SetLogEnable(INFO, TRUE); -- Enable INFO logs

    -- Wait for testbench initialization 
    wait for 0 ns;
    wait for 0 ns;
    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    -- Wait for Design Reset
    wait until Reset = '1';
    ClearAlerts;

    -- Wait for test to finish
    WaitForBarrier(TestDone, 35 ms);
    AlertIf(now >= 35 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    TranscriptClose;
    -- if CHECK_TRANSCRIPT then
    --   AffirmIfTranscriptsMatch(AXISTREAM_VALIDATED_RESULTS_DIR);
    -- end if;

    EndOfTestReports;
    std.env.stop;
    wait;
  end process ControlProc;
  ------------------------------------------------------------
  -- AvalonStreamTransmitterProc
  --   Generate transactions for AvalonStreamTransmitter
  ------------------------------------------------------------
  AvalonStreamTransmitterProc : process
    variable Data : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0);
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0);
    variable TxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN - 1 downto 0);
  begin
    wait until Reset = '1';
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (others => '0');
    TxParam := (Channel) & (Empty);
    SetAvalonStreamOptions(StreamTxRec, DEFAULT_CHANNEL, Channel);
    SetAvalonStreamOptions(StreamTxRec, PACKET_TRANSFER, true);
    SetAvalonStreamOptions(StreamTxRec, SYMBOL_ORDER, false);
    SetBurstMode(StreamTxRec, STREAM_BURST_BYTE_MODE);
    SendBurstVector(StreamTxRec, (X"12", X"34", X"56", X"78", X"90", X"12", X"34", X"56"), TxParam);

    WaitForBarrier(TestDone);
    wait;
  end process AvalonStreamTransmitterProc;
  ------------------------------------------------------------
  -- AvalonStreamReceiverProc
  --   Generate transactions for AvalonStreamReceiver
  ------------------------------------------------------------
  AvalonStreamReceiverProc : process
    variable RxData : std_logic_vector(8 - 1 downto 0) := (others => '0');
    variable ReceivedWords : integer := 4;
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0);
    variable Empty : std_logic_vector(EMPTY_LEN - 1 downto 0);
    variable rx_byte_data  : slv_vector(0 to (cNumOfWords * (cAvalonStreamDataWidth / 8)) - 1)(7 downto 0);
    variable Param, RxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN - 1 downto 0);
  begin

    rx_byte_data := (0 => X"12", 1 => X"34", 2 => X"56", 3 => X"78", 4 => X"90", 5 => X"12", 6 => X"34", 7 => X"56", others => (others => '0'));
    Channel := (others => '0');
    Channel(2) := '1';
    Empty := (others => '0');
    Param := (Channel) & (Empty);

    SetBurstMode(StreamRxRec, STREAM_BURST_BYTE_MODE);
    SetAvalonStreamOptions(StreamRxRec, SYMBOL_ORDER, false);
    SetAvalonStreamOptions(StreamRxRec, PACKET_TRANSFER, true);

    GetBurst(StreamRxRec, ReceivedWords, RxParam);
    AffirmIfEqual(ReceivedWords, 4, "Words");
    AffirmIfEqual(RxParam, Param, "Param Channel & Empty");
    for i in 0 to (ReceivedWords * (cAvalonStreamDataWidth / 8)) - 1 loop
      RxData := Pop(StreamRxRec.BurstFifo);
      AffirmIfEqual(RxData, rx_byte_data(i), "RxData matches expected data at index " & integer'image(i));
    end loop;

    -- Empfang der zweiten Send-Operation mit gesetzter BYTE_ORDER Option

    -- SetAvalonStreamOptions(StreamRxRec, BYTE_ORDER, TRUE);
    -- Param := (Channel) & (Empty) & Wildcard;
    -- for i in 1 to 1 loop
    --   case i is
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam);
    --       AffirmIfEqual(RxData, Data, "Data (BYTE_ORDER)");
    --       AffirmIfEqual(RxParam, Param, "Param Channel & Empty (BYTE_ORDER)");
    --     when others =>
    --       Check(StreamRxRec, Data);
    --   end case;
    -- end loop;

    -- Wait for outputs to propagate and signal TestDone
    WaitForClock(StreamRxRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process AvalonStreamReceiverProc;

end AvalonStreamSetOptions;

configuration AvalonStreamSetOptions of AvalonStreamTestHarness is
  for bhv
    for TestCtrl_1 : AvalonST_TestCtrl
      use entity osvvm_avalonst.AvalonST_TestCtrl(AvalonStreamSetOptions);
    end for;
  end for;
end AvalonStreamSetOptions;