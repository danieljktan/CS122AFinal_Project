library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--matrix 32x32 entity
entity matrix32x32 is
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
end matrix32x32;

architecture Behavioral of matrix32x32 is
	signal oe_state : std_logic := '1';
	signal le_state : std_logic := '0';
	signal RS       : std_logic_vector(1 downto 0) := B"00";
	signal GS       : std_logic_vector(1 downto 0) := B"00";
	signal BS       : std_logic_vector(1 downto 0) := B"00";
	signal ROWS     : std_logic_vector(3 downto 0) := B"0000";
	signal clken    : std_logic := '0';
	--signal clks     : std_logic := '0';
	--signal GOL_BOARD  : std_logic_vector(1023 downto 0) := (others => '1');
	
begin
	R <= RS;
	G <= GS;
	B <= BS;
	ROW <= ROWS;
	CLK <= CLK_IN AND clken;
	LAT <= le_state;
	OE  <= oe_state;

	process(CLK_IN)
		type state is (SHIFT, DELAY, ROW_SELECT, ROW_DELAY);
		variable s : state := SHIFT;
		variable c : integer range 0 to 31  := 0;
		variable n : integer range 0 to 255 := 0;
		variable r : integer range 0 to 15  := 0;
	begin
		IF RISING_EDGE(CLK_IN) THEN
			--transitions
			case s is
			when SHIFT=>
				if c < 31 then
					s := SHIFT;	
				else
					s := DELAY;
				end if;
			when DELAY=>
				if n < 255 then
					n := n+1;
					s := SHIFT;
				else
					n := 0;
					s := ROW_SELECT;
				end if;
			when ROW_SELECT=>
				s := ROW_DELAY;
			when ROW_DELAY=>
				if n < 255 then
					n := n+1;
					s := ROW_DELAY;
				else
					n := 0;
					s := SHIFT;
				end if;
			when others=>
				NULL;
			end case;
			
			--states
			case s is
			when SHIFT=>
			
		if r mod 2 = c mod 2 then
			RS <= B"11";
			GS <= B"11";
		else
			RS <= B"11";
			GS <= B"00";
		end if;
		
		if POS_Y=r and POS_X=c then
			BS <= B"01";
		elsif POS_Y-16=r and POS_X=c then
			BS <= B"10";
		else
			BS <= B"00";
		end if;
			
			
			
			
				clken <= '1', '0' after 5 ns;
				oe_state <= '0';
				le_state <= '0';
				c := c+1;
			when DELAY=>
				c := 0;
				clken <= '0';
				oe_state <= '1';
				le_state <= '1';
			when ROW_SELECT=>
				c := 0;
				clken <= '0';
				oe_state <= '1';
				le_state <= '0';
				ROWS <= std_logic_vector(to_unsigned(r, 4));
				if r < 15 then
					r := r+1;
				else
					r := 0;
				end if;
				
			when ROW_DELAY=>
				clken <= '0';
				oe_state <= '1';
				le_state <= '0';
			when others=>
				NULL;
			end case;			
		END IF;
		--VARIABLE NEIGHBORS : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
		--VARIABLE POPCOUNT  : INTEGER RANGE 0 TO 8 := 0;
		--VARIABLE GOLBUFFER : STD_LOGIC_VECTOR(1023 downto 0) := (others => '0');
		--if RISING_EDGE(CLK_IN) then
			--case state is
		--	when SHIFT =>
		--		if POS_Y=row_select and POS_X=col_select and INSERT='1' then
		--			GOL_BOARD(0) <= not GOL_BOARD(0);
		--		elsif std_logic_vector(unsigned(POS_Y)-16)=row_select and POS_X=col_select and INSERT='1' then
		--			GOL_BOARD(512) <= not GOL_BOARD(512);
		--		end if;
				
		--		if unsigned(col_select) < 31 then
		--			GOL_BOARD(1022 downto 0) <= GOL_BOARD(1023 downto 1);
		--			GOL_BOARD(1023) <= GOL_BOARD(0);
		--			oe_state <= '0';
		--			le_state  <= '0';
		--			col_select <= std_logic_vector(unsigned(col_select) + 1);
		--			state <= SHIFT;
		--		else
		--			oe_state   <= '0';
		--			le_state   <= '1';
		--			col_select <= (others => '0');
		--			state      <= SHIFT_END;
		--		end if;
		--	
		--	when SHIFT_END =>
		--		le_state <= '0';
		--		if n < 255 then
		--			n := n + 1;
		--			state <= SHIFT_END;
		--			oe_state <= '0';
		--		else
		--			n := 0;
		--			state <= ROW_SEL;
		--			oe_state <= '1';
		--		end if;
		--		
		--	when ROW_SEL =>
		--		case n is
		--		when 0 =>
		--			n := n + 1;
		--			if row_select /= B"01111" then
		--				row_select <= std_logic_vector(unsigned(row_select) + 1);
		--			else
		--				row_select <= (others => '0');
		--			end if;
		--		when 255 =>
		--			n := 0;
		--			if row_select/=B"01111" then
		--				state <= SHIFT;
		--			else
		--				state <= LOAD_SHIFT;
		--			end if;
		--		when others =>
		--			n := n + 1;
		--		end case;
		--	
		--	when LOAD_SHIFT =>
		--		if n < 511 then
		--			n := n + 1;
		--			GOL_BOARD(1022 downto 0) <= GOL_BOARD(1023 downto 1);
		--			GOL_BOARD(1023) <= GOL_BOARD(0);
		--		else
		--			n := 0;
		--			state <= SHIFT;
		--		end if;
		--		
		--	when COMPUTE_NEIGHBORS =>
		--		NEIGHBORS(7) := GOL_BOARD(1023);
		--		NEIGHBORS(6) := GOL_BOARD(992);
		--		NEIGHBORS(5) := GOL_BOARD(993);
		--		NEIGHBORS(4) := GOL_BOARD(31);
		--		NEIGHBORS(3) := GOL_BOARD(1);
		--		NEIGHBORS(2) := GOL_BOARD(63);
		--		NEIGHBORS(1) := GOL_BOARD(32);
		--		NEIGHBORS(0) := GOL_BOARD(33);
		--		POPCOUNT := 0;
		--		FOR I IN 7 DOWNTO 0 LOOP
		--			IF NEIGHBORS(I)='1' THEN
		--				POPCOUNT := POPCOUNT + 1;
		--			END IF;
		--		END LOOP;
		--		if n < 1023 then
		--			--...changing the for loop to a parallel assignment solves the 
		--			--long compilation timing...
		--			GOLBUFFER(1022 downto 0) := GOLBUFFER(1023 downto 1);
		--			GOL_BOARD(1022 downto 0) <= GOL_BOARD(1023 downto 1);
		--			GOL_BOARD(1023) <= GOL_BOARD(0);
		--			n := n + 1;
		--			state <= COMPUTE_NEIGHBORS;
		--		else
		--			n := 0;
		--			state <= READ_NEXT;
		--		end if;
		--	
		--		--figure out whether cell lives or dies
		--		IF GOL_BOARD(0)='1' THEN
		--			IF POPCOUNT < 2 OR POPCOUNT > 3 THEN
		--				GOLBUFFER(1023) := '0';
		--			ELSE
		--				GOLBUFFER(1023) := '1';
		--			END IF;
		--		ELSE
		--			IF POPCOUNT=3 THEN
		--				GOLBUFFER(1023) := '1';
		--			ELSE
		--				GOLBUFFER(1023) := '0';
		--			END IF;
		--		END IF;
		--	WHEN READ_NEXT =>
		--		GOL_BOARD <= GOLBUFFER;
		--		state <= SHIFT;
		--	WHEN OTHERS =>
		--		NULL;
		--	end case;
		--end if;
		
	end process;

end Behavioral;