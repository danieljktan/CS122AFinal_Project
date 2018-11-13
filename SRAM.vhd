library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SRAM is
	port 
	(
	CLK     : in  std_logic;
	address : out std_logic_vector(18 downto 0);
	data    : inout std_logic_vector(7 downto 0);
	mem_ce  : out std_logic;
	mem_we  : out std_logic;
	mem_oe  : out std_logic
	);
end SRAM;

architecture Behavioral of SRAM is
	SIGNAL DATAS : std_logic_vector(7 downto 0);
	SIGNAL addr  : std_logic_vector(18 downto 0);
begin
	data <= DATAS when mem_we='0' else (others => 'Z');
	address <= addr;

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
					if ADDR(3 downto 0) /= B"1111" then
						s := INITIALIZE;
						DATAS <= B"00000000";
						ADDR <= STD_LOGIC_VECTOR(UNSIGNED(ADDR)+1);
						mem_we <= '0';
						mem_oe <= '1';
						mem_ce <= '0';
					else
						s := IDLE;
						DATAS <= B"00000000";
						ADDR <= (others => '0');
						mem_we <= '0';
						mem_oe <= '1';
						mem_ce <= '0';
					end if;
				when IDLE=>
					mem_we <= '1';
					mem_oe <= '0';
					mem_ce <= '0';
					ADDR <= std_logic_vector((unsigned(ADDR)+1) mod 16);
					s := READ_STATE;
					temp := 0;
				when READ_STATE=>
					mem_we <= '1';
					mem_oe <= '0';
					mem_ce <= '0';
					temp := TO_INTEGER(UNSIGNED(DATA));
					s := WRITE_STATE;
				when WRITE_STATE=>
					mem_we <= '0';
					mem_oe <= '1';
					mem_ce <= '0';
					--if ADDRESS(0)='1' then
					DATAS <= STD_LOGIC_VECTOR(TO_UNSIGNED(temp+1, 8));
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

end Behavioral;

