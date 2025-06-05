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

  signal TestDone  : integer_barrier                        := 1;
  constant MAX_LEN : integer                                := maximum(CHANNEL_LEN, EMPTY_LEN);
  constant DASH    : std_logic_vector(MAX_LEN - 1 downto 0) := (others => '-');

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
    SetLogEnable(INFO, TRUE);   -- Enable INFO logs

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
  -- AxiTransmitterProc
  --   Generate transactions for AxiTransmitter
  ------------------------------------------------------------
  AvalonStreamTransmitterProc : process
    variable Data    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    variable Channel : std_logic_vector(CHANNEL_LEN - 1 downto 0); -- 8
    variable Empty   : std_logic_vector(EMPTY_LEN - 1 downto 0);   -- 4
  begin
    wait until Reset = '1';
    WaitForClock(StreamTxRec, 2);
    Channel := (others => '0');
    Channel(2) := '1'; 
    Empty   := (others => '0');

    SetAvalonStreamOptions(StreamTxRec, DEFAULT_CHANNEL, Channel);
    -- SetAxiStreamOptions(StreamTxRec, DEFAULT_DEST, Dest + 2) ;
    -- SetAxiStreamOptions(StreamTxRec, DEFAULT_USER, User + 1) ;

    for i in 1 to 1 loop
      Send(StreamTxRec, Data);
      Data := std_logic_vector(unsigned(Data) + 1);
    end loop;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, (Channel+5) & "0") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, (Dest+6) & (USER+5) & "0") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, (ID+7) & (Dest+6) & (USER+5) & "0") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, Dash(ID'range) & Dash(Dest'range) & (USER+5) & "-") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, Dash(ID'range) & (Dest+6) & Dash(USER'range) & "-") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- for i in 1 to 4 loop 
    --   Send(StreamTxRec, Data, (ID+7) & Dash(Dest'range) & Dash(USER'range) & "-") ;
    --   Data := Data + 1; 
    -- end loop ;

    -- Wait for outputs to propagate and signal TestDone
    WaitForClock(StreamTxRec, 2);
    WaitForBarrier(TestDone);
    wait;
  end process AvalonStreamTransmitterProc;
  ------------------------------------------------------------
  -- AxiReceiverProc
  --   Generate transactions for AxiReceiver
  ------------------------------------------------------------
  AvalonStreamReceiverProc : process
    variable Data, RxData   : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    variable OffSet         : integer;
    variable Channel        : std_logic_vector(CHANNEL_LEN - 1 downto 0);
    variable Empty          : std_logic_vector(EMPTY_LEN - 1 downto 0);
    variable Wildcard : std_logic := '0';
    variable Param, RxParam : std_logic_vector(CHANNEL_LEN + EMPTY_LEN + 1 - 1 downto 0);
  begin
    WaitForClock(StreamRxRec, 2);

    Channel := (others => '0');
    Channel(2) := '1'; 
    Empty   := (others => '0');


    Param := (Channel) & (Empty) & Wildcard;
    for i in 1 to 1 loop
      case i is
        when 1 =>
          Get(StreamRxRec, RxData, RxParam);
          AffirmIfEqual(RxData, Data, "Data ");
            AffirmIfEqual(RxParam, Param, "Param Channel & Empty ");
            Log("Param: " & to_hstring(Param));
            Log("RxData: " & to_hstring(RxParam));
        -- when 2 =>
        --   Check(StreamRxRec, Data, Param);
        when others =>
          Check(StreamRxRec, Data);
      end case;
      Data := std_logic_vector(unsigned(Data) + 1);
    end loop;

    -- Param := (ID+3) & (Dest+2) & (User+5) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, (USER+5) & "0") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;

    -- Param := (ID+3) & (Dest+6) & (User+5) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, (Dest+6) & (USER+5) & "0") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;

    -- Param := (ID+7) & (Dest+6) & (User+5) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, (ID+7) & (Dest+6) & (USER+5) & "0") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;

    -- Param := (ID+3) & (Dest+2) & (User+5) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, Dash(ID'range) & Dash(Dest'range) & (USER+5) & "-") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;

    -- Param := (ID+3) & (Dest+6) & (User+1) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, Dash(ID'range) & (Dest+6) & Dash(USER'range) & "-") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;

    -- Param := (ID+7) & (Dest+2) & (User+1) & "0" ;
    -- for i in 1 to 4 loop 
    --   case i is 
    --     when 1 =>
    --       Get(StreamRxRec, RxData, RxParam) ;
    --       AffirmIfEqual(RxData,  Data,    "Data ") ; 
    --       AffirmIfEqual(RxParam, Param,   "Param ID & Dest & User ") ; 
    --     when 2 => 
    --       Check(StreamRxRec, Data, Param) ;
    --     when others =>
    --       Check(StreamRxRec, Data, (ID+7) & Dash(Dest'range) & Dash(USER'range) & "-") ;
    --   end case ; 
    --   Data := Data + 1; 
    -- end loop ;     
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
