--
--  File Name:         AxiStreamTbPkg.vhd
--  Design Unit Name:  AxiStreamTbPkg
--  OSVVM Release:     OSVVM MODELS STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--
--
--  Description:
--      Defines types, constants, and subprograms used by
--      OSVVM Axi4 Transaction Based Models (aka: TBM, TLM, VVC)
--
--
--  Developed by:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    2018.05   2018.05    Initial revision released as AxiStreamTransactionPkg
--    01/2020   2020.01    Updated license notice
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

library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  use ieee.math_real.all ;

  use std.textio.all ;

library OSVVM ; 
  context OSVVM.OsvvmContext ;  

  
package AvalonStreamTbPkg is 
  ------------------------------------------------------------
  function UpdateOptions (
  ------------------------------------------------------------
    Param     : std_logic_vector ;
    ParamChannel   : std_logic_vector ; 
    ParamEmpty : std_logic_vector ; 
    Count     : integer 
  ) return std_logic_vector ;


end AvalonStreamTbPkg ;

package body AvalonStreamTbPkg is 

  ------------------------------------------------------------
  function UpdateOptions (
  ------------------------------------------------------------
    Param     : std_logic_vector ;
    ParamChannel   : std_logic_vector ; 
    ParamEmpty : std_logic_vector ; 
    Count     : integer 
  ) return std_logic_vector is
    constant PARAM_LEN : integer := Param'length ; 
    constant Channel_LEN    : integer := ParamChannel'length ; 
    constant Empty_LEN  : integer := ParamEmpty'length ; 
    variable ResultParam : std_logic_vector(PARAM_LEN -1 downto 0) ; 
    
    constant Channel_RIGHT    : integer := Empty_LEN + 1 ; 
    constant Empty_RIGHT  : integer := 1 ;
  begin    
    ResultParam := Param ;
    
    if Channel_LEN > 0 and ResultParam(Channel_RIGHT) = '-' then
      ResultParam(PARAM_LEN-1 downto Channel_RIGHT) := ParamChannel ; 
    end if ; 
    
    if Empty_LEN > 0 and ResultParam(Empty_RIGHT) = '-' then 
      ResultParam(Channel_RIGHT-1 downto Empty_RIGHT) := ParamEmpty ; 
    end if ; 
    
    return ResultParam ; 
  end function UpdateOptions ; 
    
end AvalonStreamTbPkg ;
