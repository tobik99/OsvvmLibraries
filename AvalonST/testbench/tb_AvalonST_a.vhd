library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use osvvm.ScoreboardPkg_slv.all;

entity test_harness is
end entity;

architecture tb of test_harness is
  
  -- Component Declarations
  component AvalonStreamingSource is
    port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      valid     : out std_logic;
      data      : out std_logic_vector(31 downto 0);
      ready     : in  std_logic
    );
  end component;
  
  component DUT is
    port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      valid     : in  std_logic;
      data      : in  std_logic_vector(31 downto 0);
      ready     : out std_logic
    );
  end component;
  
  component TestCtrl is
    port (
      clk   : in std_logic;
      reset : in std_logic
    );
  end component;

  -- Signal Declarations
  signal clk   : std_logic := '0';
  signal reset : std_logic := '1';
  signal valid : std_logic;
  signal data  : std_logic_vector(31 downto 0);
  signal ready : std_logic;
  
begin
  -- Clock Process
  process
  begin
    while now < 1000 ns loop
      clk <= not clk;
      wait for 5 ns;
    end loop;
    wait;
  end process;
  
  -- Reset Process
  process
  begin
    reset <= '1';
    wait for 20 ns;
    reset <= '0';
    wait;
  end process;
  
  -- Instantiations
  AvalonSrc : AvalonStreamingSource
    port map (
      clk   => clk,
      reset => reset,
      valid => valid,
      data  => data,
      ready => ready
    );
  
  dut_inst : DUT
    port map (
      clk   => clk,
      reset => reset,
      valid => valid,
      data  => data,
      ready => ready
    );
  
  test_control : TestCtrl
    port map (
      clk   => clk,
      reset => reset
    );
  
end architecture tb;
