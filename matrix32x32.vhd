library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--matrix 32x32 entity
entity matrix32x32 is
	port
	(
		ROW_NEXT  : out  std_logic;
		SHIFT_TOP : in  std_logic_vector(31 downto 0);
		SHIFT_BOT : in  std_logic_vector(31 downto 0);
		POS_X     : in  integer range 0 to 31;
		POS_Y     : in  integer range 0 to 31;
		R         : out std_logic_vector(1 downto 0);
		G         : out std_logic_vector(1 downto 0);
		B         : out std_logic_vector(1 downto 0);
		CLK_IN    : in  std_logic;
		ROW       : out std_logic_vector(3 downto 0);
		CLK       : out std_logic;
		LAT       : out std_logic;
		OE        : out std_logic
	);
end matrix32x32;

architecture Behavioral of matrix32x32 is
	type state is (SHIFT, DELAY, ROW_SELECT, ROW_DELAY);
	signal s : state := ROW_DELAY;
	signal oe_state : std_logic := '1';
	signal le_state : std_logic := '0';
	signal RS       : std_logic_vector(1 downto 0) := B"00";
	signal GS       : std_logic_vector(1 downto 0) := B"00";
	signal BS       : std_logic_vector(1 downto 0) := B"00";
	signal ROWS     : std_logic_vector(3 downto 0) := B"0000";
	signal clks     : std_logic := '0';
	signal row_nexts : std_logic;
	
begin
	R <= RS;
	G <= GS;
	B <= BS;
	ROW <= ROWS;
	CLK <= CLK_IN and clks;
	LAT <= le_state;
	OE  <= oe_state;
	ROW_NEXT <= row_nexts;

	process(CLK_IN)
		variable c : integer range 0 to 31  := 0;
		variable n : integer range 0 to 255 := 0;
		variable r : integer range 0 to 15  := 0;
	begin
		IF RISING_EDGE(CLK_IN) THEN
			case s is
			when SHIFT=>
				BS(0) <= SHIFT_TOP(c);
				BS(1) <= SHIFT_BOT(c);
				GS(0) <= SHIFT_TOP(c);
				GS(1) <= SHIFT_BOT(c);
				if r=POS_Y and c=POS_X then
					RS <= B"01";
				elsif r=(POS_Y-16) and c=POS_X then
					RS <= B"10";
				else
					RS <= B"00";
				end if;
			
				if c < 31 then
					c := c+1;
					s <= SHIFT;	
					oe_state <= '0';
					le_state <= '0';
					clks <= '1';
				else
					c := 0;
					s <= DELAY;
					oe_state <= '1';
					le_state <= '1';
					clks <= '1';
				end if;
				
			when DELAY=>
				clks <= '0';
				row_nexts <= '0';
				oe_state <= '1';
				le_state <= '0';
				if n < 255 then
					n := n+1;
					s <= SHIFT;
				else
					n := 0;
					s <= ROW_SELECT;
				end if;
			when ROW_SELECT=>
				oe_state <= '1';
				le_state <= '0';
				r := (r+1) mod 16;
				ROWS <= std_logic_vector(to_unsigned(r, 4));
				s <= ROW_DELAY;
				row_nexts <= '1';
			when ROW_DELAY=>
				row_nexts <= '0';
				if n < 31 then
					n := n+1;
					s <= ROW_DELAY;
					oe_state <= '1';
					le_state <= '0';
				else
					n := 0;
					s <= SHIFT;
					oe_state <= '0';
					le_state <= '0';
				end if;
			when others=>
				NULL;
			end case;
		END IF;
		
	end process;

end Behavioral;