
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
    
    constant Channel_RIGHT    : integer := Empty_LEN; 
    constant Empty_RIGHT  : integer := 0 ;
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
