library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gol.all;

entity SRAM is
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
end SRAM;

architecture Behavioral of SRAM is
	SIGNAL mem_ces : std_logic;
	SIGNAL mem_wes : std_logic;
	SIGNAL mem_oes : std_logic;
	SIGNAL DATAS   : std_logic_vector(7 downto 0);
	SIGNAL addr    : std_logic_vector(18 downto 0) := B"0000000000000000000"; 
begin
	--high impedance
	data <= DATAS when mem_wes='0' else (others => 'Z');
	address <= addr;
	mem_ce <= mem_ces;
	mem_we <= mem_wes;
	mem_oe <= mem_oes;

	process(CLK)
		type MEMSTATE is (INIT0, INIT1, IDLE, READ_TOP, READ_BOT, 
								READ_JOY, INSERT_JOY, WJOY, 
								RTOP, RMID, RBOT, COMPUTE_GOL, WRITE_GOL0, WRITE_GOL1,
								LDALL0, LDALL1, LDALL2, LDALL3);
		VARIABLE s : MEMSTATE := INIT0;
		VARIABLE byte : std_logic_vector(7 downto 0);
		VARIABLE row_nexts : std_logic := '0';
		VARIABLE in_joys : std_logic := '0';
		VARIABLE next_gens : std_logic := '0';
		VARIABLE row_top : std_logic_vector(31 downto 0);
		VARIABLE row_mid : std_logic_vector(31 downto 0);
		VARIABLE row_bot : std_logic_vector(31 downto 0);
		VARIABLE row_compute : std_logic_vector(31 downto 0);
		
		VARIABLE topi : std_logic_vector(4 downto 0) := B"11111";
		VARIABLE midi : std_logic_vector(4 downto 0) := B"00000";
		VARIABLE boti : std_logic_vector(4 downto 0) := B"00001";
	begin	
		if RISING_EDGE(CLK) then
			if row_next='1' then
				row_nexts := '1';
			end if;
			
			if in_joy='1' then
				in_joys := '1';
				topi := B"11111";
				midi := B"00000";
				boti := B"00001";
			end if;
		
			if next_gen='1' then
				next_gens := '1';
			end if;
		
			case s is
			when INIT0=>
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				DATAS <= B"00000000";
				s := INIT1;
			when INIT1=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				if addr(7 downto 0) /= B"11111111" then
					addr <= std_logic_vector(unsigned(addr)+1);
					s := INIT0;
				else
					addr <= B"0000000000000000000";
					s := IDLE;
				end if;
				
			when IDLE=>
				if row_nexts='1' then
					mem_ces <= '0';
					mem_wes <= '1';
					mem_oes <= '0';
					s := READ_TOP;
					addr(6) <= '0';
					addr(5 downto 2) <= ROW;
					addr(1 downto 0) <= B"00";
				elsif next_gens='1' then
					mem_ces <= '0';
					mem_wes <= '1';
					mem_oes <= '0';
					s := RTOP;
					addr(7) <= '0';
					addr(6 downto 2) <= topi;
					addr(1 downto 0) <= B"00";
				elsif in_joys='1' then
					mem_ces <= '0';
					mem_wes <= '1';
					mem_oes <= '0';
					s := READ_JOY;
					case POS_X is
					when 0 to 7=>
						addr(1 downto 0) <= B"00";
					when 8 to 15=>
						addr(1 downto 0) <= B"01";
					when 16 to 23=>
						addr(1 downto 0) <= B"10";
					when 24 to 31=>
						addr(1 downto 0) <= B"11";
					when others=>
						NULL;
					end case;	
					addr(7 downto 2) <= std_logic_vector(to_unsigned(POS_Y, 6));
				else
					mem_ces <= '1';
					mem_wes <= '1';
					mem_oes <= '1';
					addr <= B"0000000000000000000";
					s := IDLE;
				end if;			
				
			when READ_TOP=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';

				case addr(1 downto 0) is
				when B"00"=> 
					SHIFT_TOP(7 downto 0) <= data;
					addr(1 downto 0) <= B"01";
					addr(5 downto 2) <= ROW;
					addr(6) <= '0';
					s := READ_TOP;
				when B"01"=>
					SHIFT_TOP(15 downto 8) <= data;
					addr(1 downto 0) <= B"10";
					addr(5 downto 2) <= ROW;
					addr(6) <= '0';
					s := READ_TOP;
				when B"10"=>
					SHIFT_TOP(23 downto 16) <= data;
					addr(1 downto 0) <= B"11";
					addr(5 downto 2) <= ROW;
					addr(6) <= '0';
					s := READ_TOP;
				when B"11"=>
					SHIFT_TOP(31 downto 24) <= data;
					addr(1 downto 0) <= B"00";
					addr(5 downto 2) <= ROW;
					addr(6) <= '1';
					s := READ_BOT;
				when others=>
					NULL;
				end case;
			
			when READ_BOT=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when B"00"=> 
					SHIFT_BOT(7 downto 0) <= data;
					addr(1 downto 0) <= B"01";
					addr(5 downto 2) <= ROW;
					addr(6) <= '1';
					s := READ_BOT;
				when B"01"=>
					SHIFT_BOT(15 downto 8) <= data;
					addr(1 downto 0) <= B"10";
					addr(5 downto 2) <= ROW;
					addr(6) <= '1';
					s := READ_BOT;
				when B"10"=>
					SHIFT_BOT(23 downto 16) <= data;
					addr(1 downto 0) <= B"11";
					addr(5 downto 2) <= ROW;
					addr(6) <= '1';
					s := READ_BOT;
				when B"11"=>
					SHIFT_BOT(31 downto 24) <= data;
					addr(1 downto 0) <= B"00";
					addr(5 downto 2) <= ROW;
					addr(6) <= '1';
					s := IDLE;
					row_nexts := '0';
				when others=>
					NULL;
				end case;
					
			when READ_JOY=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				s := INSERT_JOY;
				
			when INSERT_JOY=>
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				byte := data;
				byte(POS_X mod 8) := not byte(POS_X mod 8);
				s := WJOY;
				
			when WJOY=>
				--same address...no need to change it...
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				DATAS <= byte;
				s := IDLE;
				in_joys := '0';
			
			when RTOP=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when b"00"=>
					row_top(7 downto 0) := data;
					addr(1 downto 0) <= b"01";
					addr(6 downto 2) <= topi;
					addr(7) <= '0';
					s := RTOP;
				when b"01"=>
					row_top(15 downto 8) := data;
					addr(1 downto 0) <= b"10";
					addr(6 downto 2) <= topi;
					addr(7) <= '0';
					s := RTOP;
				when b"10"=>
					row_top(23 downto 16) := data;
					addr(1 downto 0) <= b"11";
					addr(6 downto 2) <= topi;
					addr(7) <= '0';
					s := RTOP;
				when b"11"=>
					row_top(31 downto 24) := data;
					addr(1 downto 0) <= b"00";
					addr(6 downto 2) <= midi;
					addr(7) <= '0';
					s := RMID;
				when others=> NULL;
				end case;
			when RMID=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when b"00"=>
					row_mid(7 downto 0) := data;
					addr(1 downto 0) <= b"01";
					addr(6 downto 2) <= midi;
					addr(7) <= '0';
					s := RMID;
				when b"01"=>
					row_mid(15 downto 8) := data;
					addr(1 downto 0) <= b"10";
					addr(6 downto 2) <= midi;
					addr(7) <= '0';
					s := RMID;
				when b"10"=>
					row_mid(23 downto 16) := data;
					addr(1 downto 0) <= b"11";
					addr(6 downto 2) <= midi;
					addr(7) <= '0';
					s := RMID;
				when b"11"=>
					row_mid(31 downto 24) := data;
					addr(1 downto 0) <= b"00";
					addr(6 downto 2) <= boti;
					addr(7) <= '0';
					s := RBOT;
				when others=> NULL;
				end case;
			when RBOT=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when b"00"=>
					row_bot(7 downto 0) := data;
					addr(1 downto 0) <= b"01";
					addr(6 downto 2) <= boti;
					addr(7) <= '0';
					s := RBOT;
				when b"01"=>
					row_bot(15 downto 8) := data;
					addr(1 downto 0) <= b"10";
					addr(6 downto 2) <= boti;
					addr(7) <= '0';
					s := RBOT;
				when b"10"=>
					row_bot(23 downto 16) := data;
					addr(1 downto 0) <= b"11";
					addr(6 downto 2) <= boti;
					addr(7) <= '0';
					s := RBOT;
				when b"11"=>
					row_bot(31 downto 24) := data;
					s := COMPUTE_GOL;
				when others=>NULL;
				end case;
			when COMPUTE_GOL=>
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				for i in 31 downto 0 loop
					row_compute(i) := nextgol(row_mid(i), row_top(i), row_bot(i),
					                          row_mid((i-1) mod 32), row_mid((i+1) mod 32), row_top((i-1) mod 32), 
						                       row_bot((i-1) mod 32), row_top((i+1) mod 32), row_bot((i+1) mod 32));
				end loop;
				s := WRITE_GOL0;
				addr(1 downto 0) <= b"00";
				addr(6 downto 2) <= midi;
				addr(7) <= '1';
				
			when WRITE_GOL0=>
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when b"00"=>
					DATAS <= row_compute(7 downto 0);
				when b"01"=>
					DATAS <= row_compute(15 downto 8);
				when b"10"=>
					DATAS <= row_compute(23 downto 16);
				when b"11"=>
					DATAS <= row_compute(31 downto 24);
				when others=>
					NULL;
				end case;
				s := WRITE_GOL1;
			when WRITE_GOL1=>
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				case addr(1 downto 0) is
				when B"00"=>
					addr(1 downto 0) <= B"01";
					addr(6 downto 2) <= midi;
					addr(7) <= '1';
					s := WRITE_GOL0;
				when B"01"=>
					addr(1 downto 0) <= B"10";
					addr(6 downto 2) <= midi;
					addr(7) <= '1';
					s := WRITE_GOL0;
				when B"10"=>
					addr(1 downto 0) <= B"11";
					addr(6 downto 2) <= midi;
					addr(7) <= '1';
					s := WRITE_GOL0;
				when B"11"=>
					addr(7 downto 0) <= B"11111111";
					if midi /= b"11111" then
						topi := std_logic_vector(unsigned(topi)+1);
						midi := std_logic_vector(unsigned(midi)+1);
						boti := std_logic_vector(unsigned(boti)+1);
						next_gens := '0';
						s := IDLE;
					else
						topi := b"11111";
						midi := b"00000";
						boti := b"00001";
						next_gens := '0';
						s := LDALL0;
					end if;
				when others=>
					NULL;
				end case;
			when LDALL0=>
				--read from address
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				byte := data;
				s := LDALL1;
			when LDALL1=>
				--set up write address
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				addr(7) <= '0';
				s := LDALL2;
				
			when LDALL2=>
				--write to the data.
				mem_ces <= '0';
				mem_wes <= '0';
				mem_oes <= '0';
				DATAS <= byte;--B"11111111";
				s := LDALL3;
				
			when LDALL3=>
				--set up next read address
				mem_ces <= '0';
				mem_wes <= '1';
				mem_oes <= '0';
				DATAS <= byte;--B"11111111";
				if addr(6 downto 0) /= b"0000000" then
					addr(7) <= '1';
					addr(6 downto 0) <= std_logic_vector(unsigned(addr(6 downto 0))-1);
					s := LDALL0;
				else
					s := IDLE;
					addr(7 downto 0) <= b"00000000";
					next_gens := '0';
				end if;
			
			when others=>
				NULL;
				
			end case;
		end if;
	end process;

end Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

package gol is 
	function nextgol(n: std_logic; 
						  x0: std_logic; x1: std_logic; x2: std_logic; x3: std_logic; 
						  x4: std_logic; x5: std_logic; x6: std_logic; x7: std_logic) return std_logic;
end gol;

package body gol is 
	function nextgol(n: std_logic; 
						  x0: std_logic; x1: std_logic; x2: std_logic;  x3: std_logic; 
						  x4: std_logic; x5: std_logic; x6: std_logic; x7: std_logic) return std_logic is
		VARIABLE sum : integer range 0 to 8 := 0;
	begin
		--calculate the hamming weight/popcount
		sum := conv_integer(x0) + conv_integer(x1) + conv_integer(x2) + conv_integer(x3) 
		     + conv_integer(x4) + conv_integer(x5) + conv_integer(x6) + conv_integer(x7);
		--alive cell
		if n='1' then
			case sum is
			when 2|3=>
				return '1'; --2 or 3 neighboring bits = alive
			when others=>
				return '0'; --dead from overpopulation|underpopulation
			end case;
		--dead cell
		else
			case sum is
			when 3=>
				return '1'; --3 neighboring bits = alive
			when others=>
				return '0'; --dead
			end case;
		end if;
	end nextgol;

end gol;












