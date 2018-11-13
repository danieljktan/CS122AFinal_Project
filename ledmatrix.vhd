library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--main design
entity ledmatrix is
	port
	(
	CLK        : in  std_logic;
	INPIN      : in  std_logic_vector(3 downto 0);
	CIO        : out std_logic_vector(1 downto 0);
	DIO        : inout std_logic_vector(6 downto 0);
	IO         : inout  std_logic_vector(29 downto 0);
	BTN        : in  std_logic;
	ADC_MISO   : in  std_logic;         -- ADC SPI MISO
	ADC_MOSI   : out std_logic;         -- ADC SPI MOSI
	ADC_CSN    : out std_logic;         -- ADC SPI CHIP SELECT
	ADC_SCK    : out std_logic;          -- ADC SPI CLOCK
	LED        : out std_logic_vector(3 downto 0)
	);
end ledmatrix;

architecture Behavioral of ledmatrix is
	component matrix32x32
		port
		(
			NEXT_GEN : in  std_logic;
			INSERT   : in  std_logic;
			POS_X    : in  integer range 0 to 31;
			POS_Y    : in  integer range 0 to 31;
			R        : out std_logic_vector(1 downto 0);
			G        : out std_logic_vector(1 downto 0);
			B        : out std_logic_vector(1 downto 0);
			CLK_IN   : in  std_logic;
			ROW      : out std_logic_vector(3 downto 0);
			CLK      : out std_logic;
			LAT      : out std_logic;
			OE       : out std_logic
		);
	end component;
	
	component MercuryADC is
		port
		(
			clock    : in  std_logic;         -- 50MHz onboard oscillator
			trigger  : in  std_logic;         -- assert to sample ADC
			diffn    : in  std_logic;         -- single/differential inputs
			channel  : in  std_logic_vector(2 downto 0);  -- channel to sample
			Dout     : out std_logic_vector(9 downto 0);  -- data from ADC
			OutVal   : out std_logic;         -- pulsed when data sampled
			adc_miso : in  std_logic;         -- ADC SPI MISO
			adc_mosi : out std_logic;         -- ADC SPI MOSI
			adc_cs   : out std_logic;         -- ADC SPI CHIP SELECT
			adc_clk  : out std_logic          -- ADC SPI CLOCK
      );
	end component;
		
	SIGNAL ADC_OUTPUT  : std_logic_vector(9 downto 0);
	SIGNAL ADC_TRIGGER : std_logic := '0';
	SIGNAL ADC_CHANNEL : std_logic_vector(2 downto 0);
	SIGNAL ADC_OUT_BIT : std_logic := '0';
	
	SIGNAL JOY_X  : unsigned(9 downto 0);
	SIGNAL JOY_Y  : unsigned(9 downto 0);
		
	SIGNAL POS_X    : integer range 0 to 31 := 0;
	SIGNAL POS_Y    : integer range 0 to 31 := 0;
	SIGNAL R        : std_logic_vector(1 downto 0);
	SIGNAL G        : std_logic_vector(1 downto 0);
	SIGNAL B        : std_logic_vector(1 downto 0);
	SIGNAL ROW      : std_logic_vector(3 downto 0);
	SIGNAL NEXT_GEN : std_logic := '0';
	SIGNAL INSERT   : std_logic := '0';
	
	
	SIGNAL ADDRESS : std_logic_vector(18 downto 0) := B"0000000000000000000";
	SIGNAL DATA    : std_logic_vector(7 downto 0);
	SIGNAL mem_ce  : std_logic := '0';
	SIGNAL mem_we  : std_logic := '1';
	SIGNAL mem_oe  : std_logic := '0';
begin
	IO(29) <= mem_we;
	IO(28) <= mem_oe;
	IO(27) <= mem_ce;
	--DATA <= IO(26 downto 19);
	IO(26 downto 19) <= DATA when mem_we='0' else (others => 'Z');
	--DATA <= IO(26 downto 19) when mem_we='1' else (others => 'Z');
	IO(18 downto 0) <= ADDRESS; --when switch_oens='1' and memory_oens='0' else (others => '0');
	LED(3 downto 0) <= ADDRESS(3 downto 0);

	mercury_adc : MercuryADC port map
	(
		clock => CLK,
		trigger => ADC_TRIGGER,
		diffn => '0',
		channel => ADC_CHANNEL,
		Dout => ADC_OUTPUT,
		OutVal => ADC_OUT_BIT, 
		adc_miso => ADC_MISO,
		adc_mosi => ADC_MOSI,
		adc_cs => ADC_CSN,
		adc_clk => ADC_SCK
	);
	
	matrix : matrix32x32 port map
	(
		NEXT_GEN => NEXT_GEN,
		INSERT => INSERT,
		POS_X => POS_X,
		POS_Y => POS_Y,
		R => R,
		G => G,
		B => B,
		CLK_IN => CLK,
		ROW => ROW,
		CLK => DIO(6),
		LAT => CIO(0),
		OE => CIO(1)
	);
	
	DIO(0) <= R(0);
	DIO(1) <= G(0);
	DIO(2) <= B(0);
	DIO(3) <= R(1);
	DIO(4) <= G(1);
	DIO(5) <= B(1);

	process(CLK)
		VARIABLE n : integer range 0 to 1999999 := 0;
		type MEMSTATE is (INITIALIZE, IDLE, READ_STATE, WRITE_STATE);
		VARIABLE s : MEMSTATE := INITIALIZE;
		VARIABLE temp : integer range 0 to 255 := 0;
	begin
		if RISING_EDGE(CLK) then
			if n < 1999999 then
				n := n+1;
			else
				n := 0;
				case s is
				when INITIALIZE=>
					if ADDRESS(3 downto 0) /= B"1111" then
						s := INITIALIZE;
						DATA <= B"00000000";
						ADDRESS <= STD_LOGIC_VECTOR(UNSIGNED(ADDRESS)+1);
						mem_we <= '0';
						mem_oe <= '1';
						mem_ce <= '0';
					else
						s := IDLE;
						DATA <= B"00000000";
						ADDRESS <= (others => '0');
						mem_we <= '0';
						mem_oe <= '1';
						mem_ce <= '0';
					end if;
				when IDLE=>
					mem_we <= '1';
					mem_oe <= '0';
					mem_ce <= '0';
					ADDRESS <= std_logic_vector((unsigned(ADDRESS)+1) mod 16);
					s := READ_STATE;
					temp := 0;
				when READ_STATE=>
					mem_we <= '1';
					mem_oe <= '0';
					mem_ce <= '0';
					temp := TO_INTEGER(UNSIGNED(IO(26 downto 19)));
					s := WRITE_STATE;
				when WRITE_STATE=>
					mem_we <= '0';
					mem_oe <= '1';
					mem_ce <= '0';
					--if ADDRESS(0)='1' then
					DATA <= STD_LOGIC_VECTOR(TO_UNSIGNED(temp+1, 8));
					--else
					--	DATA <= NOT STD_LOGIC_VECTOR(TO_UNSIGNED(temp, 8));
					--end if;
					s := IDLE;
				when others =>
					NULL;
				end case;
			end if;
		end if;
	end process;

	process(CLK)
		type ADCSTATE is (READ_ADC, RECEIVE_ADC);
		VARIABLE adc_state : ADCSTATE := READ_ADC;
		VARIABLE num       : integer range 0 to 8191 := 0;
	begin
		if RISING_EDGE(CLK) then 
			case adc_state is 
			when READ_ADC =>
				if num < 8191 then
					num := num+1;
					ADC_TRIGGER <= '0';
				else
					num := 0;
					ADC_TRIGGER <= '1', '0' after 1 ps;
					adc_state   := RECEIVE_ADC;
				end if;
			when RECEIVE_ADC =>
				ADC_TRIGGER <= '0';
				if ADC_OUT_BIT='1' then
					case ADC_CHANNEL is
					when B"000" =>
						JOY_X <= unsigned(ADC_OUTPUT);
						ADC_CHANNEL <= B"010";
						adc_state := READ_ADC;
					when B"010" =>
						JOY_Y <= unsigned(ADC_OUTPUT);
						ADC_CHANNEL <= B"000";
						adc_state := READ_ADC;
					when others => NULL;
					end case;
				end if;
			when others => NULL;
			end case;
		end if;
	end process;
	
	process(CLK) 
		VARIABLE num : integer range 0 to 4500000 := 0;
	begin
		if RISING_EDGE(CLK) then
			if num < 4500000 then
				num := num + 1;
			else
				num := 0;
				if JOY_X < 300 then
					POS_X <= (POS_X - 1) mod 32;
				elsif JOY_X > 723 then
					POS_X <= (POS_X + 1) mod 32;
				end if;
				if JOY_Y < 300 then
					POS_Y <= (POS_Y + 1) mod 32;
				elsif JOY_Y > 723 then
					POS_Y <= (POS_Y - 1) mod 32;
				end if;
			end if;
		end if;
	end process;
	
	process(CLK) 
		VARIABLE n : integer range 0 to 2500000 := 0;
		TYPE btnstate is (IDLE, PRESS);
		VARIABLE state : btnstate := IDLE;
	begin
		if RISING_EDGE(CLK) then
			if n < 2500000 then
				n := n + 1;
			else
				n := 0;
				case state is
				when IDLE =>
					if INPIN(1)='1' then
						state := PRESS;
						INSERT <= '1';
					else
						state := IDLE;
						INSERT <= '0';
					end if;
				when PRESS =>
					if BTN='1' then
						state := PRESS;
						INSERT <= '0';
					else
						state := IDLE;
						INSERT <= '0';
					end if;
				end case;
			end if;
		end if;
	end process;
	
	process(CLK) 
		VARIABLE n : integer range 0 to 5000000 := 0;
		TYPE btnstate is (IDLE, PRESS);
		VARIABLE state : btnstate := IDLE;
	begin
		if RISING_EDGE(CLK) then
			if n < 5000000 then
				n := n + 1;
			else
				n := 0;
				case state is
				when IDLE =>
					if INPIN(0)='1' then
						state := PRESS;
						NEXT_GEN <= not NEXT_GEN;
					else
						state := IDLE;
					end if;
				when PRESS =>
					if BTN='1' then
						state := PRESS;
					else
						state := IDLE;
					end if;
				end case;
			end if;
		end if;
	end process;
end Behavioral;

