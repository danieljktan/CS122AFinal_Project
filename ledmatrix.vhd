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
	LED        : out std_logic_vector(3 downto 0);
	switch_oen : out std_logic;
   memory_oen : out std_logic
	);
end ledmatrix;

architecture Behavioral of ledmatrix is

	component SRAM
		port 
		(
		next_gen : in std_logic;
		POS_X    : in  integer range 0 to 31;
		POS_Y    : in  integer range 0 to 31;
		IN_JOY   : in std_logic := '0';
		ROW : in std_logic_vector(3 downto 0);
		ROW_NEXT : in std_logic;
		SHIFT_TOP : out std_logic_vector(31 downto 0);
		SHIFT_BOT : out std_logic_vector(31 downto 0);
		CLK     : in  std_logic;
		address : out std_logic_vector(18 downto 0);
		data    : inout std_logic_vector(7 downto 0);
		mem_ce  : out std_logic;
		mem_we  : out std_logic;
		mem_oe  : out std_logic
		);
	end component;

	component matrix32x32
		port
		(
			ROW_NEXT : out std_logic;
			SHIFT_TOP : in  std_logic_vector(31 downto 0);
			SHIFT_BOT : in  std_logic_vector(31 downto 0);
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
		
	SIGNAL POS_X    : integer range 0 to 31 := 16;
	SIGNAL POS_Y    : integer range 0 to 31 := 16;
	SIGNAL R        : std_logic_vector(1 downto 0);
	SIGNAL G        : std_logic_vector(1 downto 0);
	SIGNAL B        : std_logic_vector(1 downto 0);
	SIGNAL ROW      : std_logic_vector(3 downto 0);
	SIGNAL ROW_NEXT : std_logic := '0';
	SIGNAL NEXT_GEN : std_logic := '0';
	SIGNAL IN_JOY   : std_logic := '0';
	SIGNAL ADDRESS  : std_logic_vector(18 downto 0) := B"0000000000000000000";
	SIGNAL mem_ce   : std_logic := '0';
	SIGNAL mem_we   : std_logic := '1';
	SIGNAL mem_oe   : std_logic := '0';
	
	SIGNAL mat_lat  : std_logic;
	SIGNAL mat_clk  : std_logic;
	SIGNAL mat_oe   : std_logic;
	SIGNAL SHIFT_TOP : std_logic_vector(31 downto 0) := (others=>'0');
	SIGNAL SHIFT_BOT : std_logic_vector(31 downto 0) := (others=>'0');
	SIGNAL clkb : std_logic := '0';
	SIGNAL play : std_logic := '0';
begin
	led(3) <= play;
	led(2) <= play;
	led(1) <= play;
	led(0) <= play;
	switch_oen <= not mem_ce;
   memory_oen <= mem_oe;
	CIO <= B"00";
	IO(0) <= R(0) when mem_ce='1' else ADDRESS(0);
	IO(1) <= R(1) when mem_ce='1' else ADDRESS(1);
	IO(2) <= G(0) when mem_ce='1' else ADDRESS(2);
	IO(3) <= G(1) when mem_ce='1' else ADDRESS(3);
	IO(4) <= B(0) when mem_ce='1' else ADDRESS(4);
	IO(5) <= B(1) when mem_ce='1' else ADDRESS(5);
	IO(6) <= ROW(0) when mem_ce='1' else ADDRESS(6);
	IO(7) <= ROW(1) when mem_ce='1' else ADDRESS(7);
	IO(8) <= ROW(2) when mem_ce='1' else ADDRESS(8);
	IO(9) <= ROW(3) when mem_ce='1' else ADDRESS(9);
	IO(10) <= mat_lat when mem_ce='1' else ADDRESS(10);
	IO(11) <= mat_clk when mem_ce='1' else ADDRESS(11);
	IO(12) <= mat_oe when mem_ce='1' else ADDRESS(12);
	IO(18 downto 13) <= ADDRESS(18 downto 13);
	IO(19) <= '1';
	IO(28) <= '1' when mem_ce='1' else mem_we;
	
	smem : SRAM port map
	(
		next_gen=>next_gen,
		POS_X=>POS_X,
		POS_Y=>POS_Y,
		IN_JOY=>IN_JOY,
		ROW=>ROW,
		ROW_NEXT=>ROW_NEXT,
		SHIFT_TOP=>SHIFT_TOP,
		SHIFT_BOT=>SHIFT_BOT,
		CLK=>CLK,
		address=>ADDRESS,
		data=>IO(27 downto 20),
		mem_ce=>mem_ce,
		mem_we=>mem_we,
		mem_oe=>mem_oe
	);

	adc : MercuryADC port map
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
	
	mat : matrix32x32 port map
	(
		ROW_NEXT=>ROW_NEXT,
		SHIFT_TOP=>SHIFT_TOP,
		SHIFT_BOT=>SHIFT_BOT,
		POS_X=>POS_X,
		POS_Y=>POS_Y,
		R=>R,
		G=>G,
		B=>B,
		CLK_IN=>clkb,
		ROW=>ROW,
		CLK=>MAT_CLK,
		LAT=>MAT_LAT,
		OE=>MAT_OE
	);

	process(CLK)
		VARIABLE n : integer range 0 to 3 := 0;
	begin
		if rising_edge(CLK) then
			if n < 3 then
				n := n+1;
			else
				n := 0;
				clkb <= not clkb;
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
					ADC_TRIGGER <= '1';
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
		VARIABLE n : integer range 0 to 750000 := 0;
		TYPE btnstate is (INITIAL, IDLE, PRESS);
		VARIABLE b0 : btnstate := INITIAL;
		VARIABLE b1 : btnstate := INITIAL;
	begin
		if RISING_EDGE(CLK) then
			if n < 750000 then
				n := n + 1;
				IN_JOY <= '0';
			else
				n := 0;
				case b0 is
				when INITIAL=>
					if INPIN(1)='1' then
						b0 := IDLE;
						IN_JOY <= '0';
					end if;
				when IDLE =>
					if INPIN(1)='0' then
						b0 := PRESS;
						IN_JOY <= '1';
						play <= '0';
					else
						b0 := IDLE;
					end if;
				when PRESS =>
					if INPIN(1)='0' then
						b0 := PRESS;
					else
						b0 := IDLE;
					end if;
				end case;
				
				case b1 is
				when INITIAL=>
					if INPIN(0)='0' then
						b1 := IDLE;
						play <= '0';
					end if;
				when IDLE =>
					if INPIN(0)='0' then
						b1 := PRESS;
						play <= not play;
					else
						b1 := IDLE;
					end if;
				when PRESS =>
					if INPIN(0)='0' then
						b1 := PRESS;
					else
						b1 := IDLE;
					end if;
				end case;
			end if;
		end if;
	end process;
	
	process(CLK)
		TYPE btnstate is (INITIAL, IDLE, FAST, SLOW);
		VARIABLE b : btnstate := INITIAL;
		VARIABLE freq : integer range 0 to 131071 := 65535;
		VARIABLE n : integer range 0 to 131071 := 0;--8191, 16383, 65535, 131071
		VARIABLE m : integer range 0 to 750000 := 0;
	begin
		if RISING_EDGE(CLK) then
			if m < 750000 then
				m := m+1;
			else
				m := 0;
				case b is
				when INITIAL=>
					if INPIN(3 downto 2) /= b"11" then
						b := INITIAL;
					else
						b := IDLE;
					end if;
				when IDLE=>
				case INPIN(3 downto 2) is
					when b"01"=>
						b := SLOW;
						
						case freq is
						when 8191=>
							freq := 16383;
						when 16383=>
							freq := 65535;
						when 65535=>
							freq := 131071;
						when 131071=>
							freq := 131071;
						when others=>
							NULL;
						end case;
						
					when b"10"=>
						b := FAST;
						
						case freq is
						when 8191=>
							freq := 8191;
						when 16383=>
							freq := 8191;
						when 65535=>
							freq := 16383;
						when 131071=>
							freq := 65535;
						when others=>
							NULL;
						end case;
						
					when b"00"|b"11"=>
						b := IDLE;
					when others=>
						NULL;
					end case;
				when FAST=>
					if INPIN(3 downto 2) /= b"11" then
						b := FAST;
					else
						b := IDLE;
					end if;
				when SLOW=>
					if INPIN(3 downto 2) /= b"11" then
						b := SLOW;
					else
						b := IDLE;
					end if;
				end case;
			end if;
			
			if n < freq then
				n := n+1;
				next_gen <= '0';
			else
				n := 0;
				next_gen <= play;
			end if;
		end if;
	end process;
	
end Behavioral;

