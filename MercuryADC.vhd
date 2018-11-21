library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MercuryADC is
  port
    (
      -- command input
      clock    : in  bit;         -- 50MHz onboard oscillator
      trigger  : in  bit;         -- assert to sample ADC
      diffn    : in  bit;         -- single/differential inputs
      channel  : in  bit_vector(2 downto 0);  -- channel to sample
      -- data output
      Dout     : out bit_vector(9 downto 0);  -- data from ADC
      OutVal   : out bit;         -- pulsed when data sampled
      -- ADC connection
      adc_miso : in  bit;         -- ADC SPI MISO
      adc_mosi : out bit;         -- ADC SPI MOSI
      adc_cs   : out bit;         -- ADC SPI CHIP SELECT
      adc_clk  : out bit          -- ADC SPI CLOCK
      );

end MercuryADC;

architecture rtl of MercuryADC is

  -- clock
  signal adc_clock : bit := '0';

  -- command
  signal trigger_flag : bit                    := '0';
  signal sgl_diff_reg : bit;
  signal channel_reg  : bit_vector(2 downto 0) := (others => '0');
  signal done         : bit                    := '0';
  signal done_prev    : bit                    := '0';

  -- output registers
  signal val : bit                    := '0';
  signal D   : bit_vector(9 downto 0) := (others => '0');

  -- state control
  signal state     : bit                    := '0';
  signal spi_count : unsigned(4 downto 0)         := (others => '0');
  signal Q         : bit_vector(9 downto 0) := (others => '0');
  
begin

  -- clock divider
  -- input clock: 50MHz
  -- adc clock: ~3.57MHz (198.4-ksps)
  clock_divider : process(clock)
  variable cnt : integer := 0;
  begin
    if clock'event and clock='1' then
      cnt := cnt + 1;
      if cnt = 7 then
        cnt := 0;
        adc_clock <= not adc_clock;
      end if;
    end if;
  end process;

  -- produce trigger flag
  trigger_cdc : process(clock)
  begin
    if clock'event and clock='1' then
      if trigger = '1' and state = '0' then
        sgl_diff_reg <= diffn;
        channel_reg  <= channel;
        trigger_flag <= '1';
      elsif state = '1' then
        trigger_flag <= '0';
      end if;
    end if;
  end process;

  adc_clk <= adc_clock;
  adc_cs  <= not state;

  -- SPI state machine (falling edge)
  adc_sm : process(adc_clock)
  begin
    if adc_clock'event and adc_clock = '0' then
      if state = '0' then
        done <= '0';
        if trigger_flag = '1' then
          state <= '1';
        else
          state <= '0';
        end if;
      else
        if spi_count = "10000" then
          spi_count <= (others => '0');
          state     <= '0';
          done      <= '1';
        else
          spi_count <= spi_count + 1;
          state     <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Register sample into 50MHz clock domain
  outreg : process(clock)
  begin
    if clock'event and clock='1' then
      done_prev <= done;
      if done_prev = '0' and done = '1' then
        D   <= Q;
        Val <= '1';
      else
        Val <= '0';
      end if;
    end if;
  end process;

  Dout   <= D;
  OutVal <= Val;

  -- MISO shift register (rising edge)
  shift_in : process(adc_clock)
  begin
    if adc_clock'event and adc_clock = '1' then
      if state = '1' then
        Q(0)          <= adc_miso;
        Q(9 downto 1) <= Q(8 downto 0);
      end if;
    end if;
  end process;

  -- Decode MOSI output
  shift_out : process(state, spi_count, sgl_diff_reg, channel_reg)
  begin
    if state = '1' then
      case spi_count is
        when "00000" => adc_mosi <= '1';  -- start bit
        when "00001" => adc_mosi <= sgl_diff_reg;
        when "00010" => adc_mosi <= channel_reg(2);
        when "00011" => adc_mosi <= channel_reg(1);
        when "00100" => adc_mosi <= channel_reg(0);
        when others  => adc_mosi <= '0';
      end case;
    else
      adc_mosi <= '0';
    end if;
  end process;

end rtl;
