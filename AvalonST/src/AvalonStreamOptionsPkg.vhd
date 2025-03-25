
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;

library osvvm;
context osvvm.OsvvmContext;

library OSVVM_Common;
context OSVVM_Common.OsvvmCommonContext;

package AvalonStreamOptionsPkg is
  type AvalonStreamOptionsType is (-- OptVal
    TRANSMIT_VALID_DELAY_CYCLES,       -- Integer
    TRANSMIT_VALID_BURST_DELAY_CYCLES, -- Integer
    TRANSMIT_READY_TIME_OUT,           -- Integer
    RECEIVE_READY_BEFORE_VALID,        -- Integer
    RECEIVE_READY_DELAY_CYCLES,        -- Integer
    RECEIVE_READY_WAIT_FOR_GET,        -- boolean
    DROP_UNDRIVEN,
    THE_END
  );
  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in integer
  );

  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in boolean
  );

  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in std_logic_vector
  );

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out integer
  );

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out boolean
  );

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out std_logic_vector
  );

end package AvalonStreamOptionsPkg;
package body AvalonStreamOptionsPkg is
  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in integer
  ) is
  begin
    SetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option), OptVal);
  end procedure SetAvalonStreamOptions;

  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in boolean
  ) is
  begin
    SetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option), OptVal);
  end procedure SetAvalonStreamOptions;

  procedure SetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    constant OptVal : in std_logic_vector
  ) is
  begin
    TransRec.ParamToModel <= ToTransaction(OptVal, TransRec.ParamToModel'length);
    SetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option));
  end procedure SetAvalonStreamOptions;

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out integer
  ) is
  begin
    GetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option), OptVal);
  end procedure GetAvalonStreamOptions;

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out boolean
  ) is
  begin
    GetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option), OptVal);
  end procedure GetAvalonStreamOptions;

  procedure GetAvalonStreamOptions (
    signal TransRec : inout StreamRecType;
    constant Option : in AvalonStreamOptionsType;
    variable OptVal : out std_logic_vector
  ) is
  begin
    GetModelOptions(TransRec, AvalonStreamOptionsType'POS(Option));
    OptVal := FromTransaction(TransRec.ParamFromModel, OptVal'length);
  end procedure GetAvalonStreamOptions;
end package body AvalonStreamOptionsPkg;
