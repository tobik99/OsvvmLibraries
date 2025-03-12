library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use osvvm.ScoreboardPkg_slv;

package AvalonST_tb_pkg is
    
    -- Datenstruktur für eine Avalon Streaming Transaktion
    type AvalonStreamRecType is record
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
    end record;
    
    -- Transaktions-API
    procedure AvalonStreamSend(signal DataOut: out AvalonStreamRecType; Data: std_logic_vector(7 downto 0));
    procedure AvalonStreamReceive(signal DataIn: in AvalonStreamRecType; signal DataOut: out std_logic_vector(7 downto 0));
    
end package AvalonST_tb_pkg;

package body AvalonST_tb_pkg is
    
    procedure AvalonStreamSend(signal DataOut: out AvalonStreamRecType; Data: std_logic_vector(7 downto 0)) is
    begin
        DataOut.data  <= Data;
        DataOut.valid <= '1';
    end procedure AvalonStreamSend;
    
    procedure AvalonStreamReceive(signal DataIn: in AvalonStreamRecType; signal DataOut: out std_logic_vector(7 downto 0)) is
    begin
        if DataIn.valid = '1' then
            DataOut <= DataIn.data;
        end if;
    end procedure AvalonStreamReceive;
    
end package body AvalonST_tb_pkg;
