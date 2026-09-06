-- =====================================================================
--  "Калина" (ДСТУ 7624:2014) - пакет перетворень
--  Автор: CleverBot
--
--  SP-мережа. Стан - матриця 8 рядків x Nb стовпців байтів, де кожен
--  стовпець і є одним 64-бітним словом: байт (row, col) лежить у
--  state(col)(8*row+7 downto 8*row). Саме так стан подано і в
--  еталонній реалізації, тому порівняння векторів однозначне.
--
--  Nb = 2 / 4 / 8 слів (блок 128 / 256 / 512 біт)
--  Nk = 2 / 4 / 8 слів (ключ 128 / 256 / 512 біт)
--
--  Особливість Калини: раундовий ключ додається за модулем 2^64
--  (а не XOR, як в AES) на першому та останньому раундах. Через це
--  розшифрування потребує справжнього віднімання.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;

package kalyna_package is

    subtype word64_t is unsigned(63 downto 0);

    -- Неконстрейнений тип: одні й ті самі функції обслуговують Nb = 2, 4, 8
    type state_t is array (natural range <>) of word64_t;

    -- Таблиці записані як 4 x 256 (читабельно), але у синтез ідуть
    -- ПЛОСКИМИ: sbox(256*k + b). Вкладений масив змушує синтезатор
    -- бачити частковий доступ до пам'яті замість звичайного ПЗП.
    type kbox_t   is array (0 to 255) of byte_t;
    type kboxes_t is array (0 to 3)   of kbox_t;
    type sbox_flat_t is array (0 to 1023) of byte_t;
    type mds_row_t is array (0 to 7)  of byte_t;
    type mds_t     is array (0 to 7, 0 to 7) of byte_t;

    constant SBOX_ENC : sbox_flat_t;   -- pi_0 .. pi_3, склеєні
    constant SBOX_DEC : sbox_flat_t;   -- обернені (будуються на елаборації)

    -- Обидві MDS-матриці циркулянтні, тож задано лише перший рядок
    constant MDS_ROW0     : mds_row_t := (x"01", x"01", x"05", x"01",
                                          x"08", x"06", x"07", x"04");
    constant MDS_INV_ROW0 : mds_row_t := (x"ad", x"95", x"76", x"a8",
                                          x"2f", x"49", x"d7", x"ca");
    constant MDS     : mds_t;
    constant MDS_INV : mds_t;

    -- Кількість раундів визначається довжиною ключа
    function rounds_for(nk : natural) return natural;

    -- Базові перетворення
    function sub_bytes      (s : state_t) return state_t;
    function inv_sub_bytes  (s : state_t) return state_t;
    function shift_rows     (s : state_t) return state_t;
    function inv_shift_rows (s : state_t) return state_t;
    function mix_columns    (s : state_t) return state_t;
    function inv_mix_columns(s : state_t) return state_t;

    function encipher_round (s : state_t) return state_t;
    function decipher_round (s : state_t) return state_t;

    -- Накладання ключа
    function add_mod (a, b : state_t) return state_t;   -- за модулем 2^64
    function sub_mod (a, b : state_t) return state_t;
    function xor_st  (a, b : state_t) return state_t;

    -- Допоміжні для розгортання ключа
    function rotate_words     (s : state_t) return state_t;  -- {w1..wn-1, w0}
    function shift_left_words (s : state_t) return state_t;  -- кожне слово << 1
    function rotate_left_bytes(s : state_t) return state_t;  -- на 2*Nb+3 байти

    -- Перетворення між шиною та станом (слово i - біти 64i+63 .. 64i)
    function to_state(v : unsigned; n : natural) return state_t;
    function to_bus  (s : state_t) return unsigned;

end package kalyna_package;


package body kalyna_package is

    constant SBOX_ENC_TAB : kboxes_t := (
        -- pi_0
        (
        x"a8", x"43", x"5f", x"06", x"6b", x"75", x"6c", x"59",
        x"71", x"df", x"87", x"95", x"17", x"f0", x"d8", x"09",
        x"6d", x"f3", x"1d", x"cb", x"c9", x"4d", x"2c", x"af",
        x"79", x"e0", x"97", x"fd", x"6f", x"4b", x"45", x"39",
        x"3e", x"dd", x"a3", x"4f", x"b4", x"b6", x"9a", x"0e",
        x"1f", x"bf", x"15", x"e1", x"49", x"d2", x"93", x"c6",
        x"92", x"72", x"9e", x"61", x"d1", x"63", x"fa", x"ee",
        x"f4", x"19", x"d5", x"ad", x"58", x"a4", x"bb", x"a1",
        x"dc", x"f2", x"83", x"37", x"42", x"e4", x"7a", x"32",
        x"9c", x"cc", x"ab", x"4a", x"8f", x"6e", x"04", x"27",
        x"2e", x"e7", x"e2", x"5a", x"96", x"16", x"23", x"2b",
        x"c2", x"65", x"66", x"0f", x"bc", x"a9", x"47", x"41",
        x"34", x"48", x"fc", x"b7", x"6a", x"88", x"a5", x"53",
        x"86", x"f9", x"5b", x"db", x"38", x"7b", x"c3", x"1e",
        x"22", x"33", x"24", x"28", x"36", x"c7", x"b2", x"3b",
        x"8e", x"77", x"ba", x"f5", x"14", x"9f", x"08", x"55",
        x"9b", x"4c", x"fe", x"60", x"5c", x"da", x"18", x"46",
        x"cd", x"7d", x"21", x"b0", x"3f", x"1b", x"89", x"ff",
        x"eb", x"84", x"69", x"3a", x"9d", x"d7", x"d3", x"70",
        x"67", x"40", x"b5", x"de", x"5d", x"30", x"91", x"b1",
        x"78", x"11", x"01", x"e5", x"00", x"68", x"98", x"a0",
        x"c5", x"02", x"a6", x"74", x"2d", x"0b", x"a2", x"76",
        x"b3", x"be", x"ce", x"bd", x"ae", x"e9", x"8a", x"31",
        x"1c", x"ec", x"f1", x"99", x"94", x"aa", x"f6", x"26",
        x"2f", x"ef", x"e8", x"8c", x"35", x"03", x"d4", x"7f",
        x"fb", x"05", x"c1", x"5e", x"90", x"20", x"3d", x"82",
        x"f7", x"ea", x"0a", x"0d", x"7e", x"f8", x"50", x"1a",
        x"c4", x"07", x"57", x"b8", x"3c", x"62", x"e3", x"c8",
        x"ac", x"52", x"64", x"10", x"d0", x"d9", x"13", x"0c",
        x"12", x"29", x"51", x"b9", x"cf", x"d6", x"73", x"8d",
        x"81", x"54", x"c0", x"ed", x"4e", x"44", x"a7", x"2a",
        x"85", x"25", x"e6", x"ca", x"7c", x"8b", x"56", x"80"
        ),
        -- pi_1
        (
        x"ce", x"bb", x"eb", x"92", x"ea", x"cb", x"13", x"c1",
        x"e9", x"3a", x"d6", x"b2", x"d2", x"90", x"17", x"f8",
        x"42", x"15", x"56", x"b4", x"65", x"1c", x"88", x"43",
        x"c5", x"5c", x"36", x"ba", x"f5", x"57", x"67", x"8d",
        x"31", x"f6", x"64", x"58", x"9e", x"f4", x"22", x"aa",
        x"75", x"0f", x"02", x"b1", x"df", x"6d", x"73", x"4d",
        x"7c", x"26", x"2e", x"f7", x"08", x"5d", x"44", x"3e",
        x"9f", x"14", x"c8", x"ae", x"54", x"10", x"d8", x"bc",
        x"1a", x"6b", x"69", x"f3", x"bd", x"33", x"ab", x"fa",
        x"d1", x"9b", x"68", x"4e", x"16", x"95", x"91", x"ee",
        x"4c", x"63", x"8e", x"5b", x"cc", x"3c", x"19", x"a1",
        x"81", x"49", x"7b", x"d9", x"6f", x"37", x"60", x"ca",
        x"e7", x"2b", x"48", x"fd", x"96", x"45", x"fc", x"41",
        x"12", x"0d", x"79", x"e5", x"89", x"8c", x"e3", x"20",
        x"30", x"dc", x"b7", x"6c", x"4a", x"b5", x"3f", x"97",
        x"d4", x"62", x"2d", x"06", x"a4", x"a5", x"83", x"5f",
        x"2a", x"da", x"c9", x"00", x"7e", x"a2", x"55", x"bf",
        x"11", x"d5", x"9c", x"cf", x"0e", x"0a", x"3d", x"51",
        x"7d", x"93", x"1b", x"fe", x"c4", x"47", x"09", x"86",
        x"0b", x"8f", x"9d", x"6a", x"07", x"b9", x"b0", x"98",
        x"18", x"32", x"71", x"4b", x"ef", x"3b", x"70", x"a0",
        x"e4", x"40", x"ff", x"c3", x"a9", x"e6", x"78", x"f9",
        x"8b", x"46", x"80", x"1e", x"38", x"e1", x"b8", x"a8",
        x"e0", x"0c", x"23", x"76", x"1d", x"25", x"24", x"05",
        x"f1", x"6e", x"94", x"28", x"9a", x"84", x"e8", x"a3",
        x"4f", x"77", x"d3", x"85", x"e2", x"52", x"f2", x"82",
        x"50", x"7a", x"2f", x"74", x"53", x"b3", x"61", x"af",
        x"39", x"35", x"de", x"cd", x"1f", x"99", x"ac", x"ad",
        x"72", x"2c", x"dd", x"d0", x"87", x"be", x"5e", x"a6",
        x"ec", x"04", x"c6", x"03", x"34", x"fb", x"db", x"59",
        x"b6", x"c2", x"01", x"f0", x"5a", x"ed", x"a7", x"66",
        x"21", x"7f", x"8a", x"27", x"c7", x"c0", x"29", x"d7"
        ),
        -- pi_2
        (
        x"93", x"d9", x"9a", x"b5", x"98", x"22", x"45", x"fc",
        x"ba", x"6a", x"df", x"02", x"9f", x"dc", x"51", x"59",
        x"4a", x"17", x"2b", x"c2", x"94", x"f4", x"bb", x"a3",
        x"62", x"e4", x"71", x"d4", x"cd", x"70", x"16", x"e1",
        x"49", x"3c", x"c0", x"d8", x"5c", x"9b", x"ad", x"85",
        x"53", x"a1", x"7a", x"c8", x"2d", x"e0", x"d1", x"72",
        x"a6", x"2c", x"c4", x"e3", x"76", x"78", x"b7", x"b4",
        x"09", x"3b", x"0e", x"41", x"4c", x"de", x"b2", x"90",
        x"25", x"a5", x"d7", x"03", x"11", x"00", x"c3", x"2e",
        x"92", x"ef", x"4e", x"12", x"9d", x"7d", x"cb", x"35",
        x"10", x"d5", x"4f", x"9e", x"4d", x"a9", x"55", x"c6",
        x"d0", x"7b", x"18", x"97", x"d3", x"36", x"e6", x"48",
        x"56", x"81", x"8f", x"77", x"cc", x"9c", x"b9", x"e2",
        x"ac", x"b8", x"2f", x"15", x"a4", x"7c", x"da", x"38",
        x"1e", x"0b", x"05", x"d6", x"14", x"6e", x"6c", x"7e",
        x"66", x"fd", x"b1", x"e5", x"60", x"af", x"5e", x"33",
        x"87", x"c9", x"f0", x"5d", x"6d", x"3f", x"88", x"8d",
        x"c7", x"f7", x"1d", x"e9", x"ec", x"ed", x"80", x"29",
        x"27", x"cf", x"99", x"a8", x"50", x"0f", x"37", x"24",
        x"28", x"30", x"95", x"d2", x"3e", x"5b", x"40", x"83",
        x"b3", x"69", x"57", x"1f", x"07", x"1c", x"8a", x"bc",
        x"20", x"eb", x"ce", x"8e", x"ab", x"ee", x"31", x"a2",
        x"73", x"f9", x"ca", x"3a", x"1a", x"fb", x"0d", x"c1",
        x"fe", x"fa", x"f2", x"6f", x"bd", x"96", x"dd", x"43",
        x"52", x"b6", x"08", x"f3", x"ae", x"be", x"19", x"89",
        x"32", x"26", x"b0", x"ea", x"4b", x"64", x"84", x"82",
        x"6b", x"f5", x"79", x"bf", x"01", x"5f", x"75", x"63",
        x"1b", x"23", x"3d", x"68", x"2a", x"65", x"e8", x"91",
        x"f6", x"ff", x"13", x"58", x"f1", x"47", x"0a", x"7f",
        x"c5", x"a7", x"e7", x"61", x"5a", x"06", x"46", x"44",
        x"42", x"04", x"a0", x"db", x"39", x"86", x"54", x"aa",
        x"8c", x"34", x"21", x"8b", x"f8", x"0c", x"74", x"67"
        ),
        -- pi_3
        (
        x"68", x"8d", x"ca", x"4d", x"73", x"4b", x"4e", x"2a",
        x"d4", x"52", x"26", x"b3", x"54", x"1e", x"19", x"1f",
        x"22", x"03", x"46", x"3d", x"2d", x"4a", x"53", x"83",
        x"13", x"8a", x"b7", x"d5", x"25", x"79", x"f5", x"bd",
        x"58", x"2f", x"0d", x"02", x"ed", x"51", x"9e", x"11",
        x"f2", x"3e", x"55", x"5e", x"d1", x"16", x"3c", x"66",
        x"70", x"5d", x"f3", x"45", x"40", x"cc", x"e8", x"94",
        x"56", x"08", x"ce", x"1a", x"3a", x"d2", x"e1", x"df",
        x"b5", x"38", x"6e", x"0e", x"e5", x"f4", x"f9", x"86",
        x"e9", x"4f", x"d6", x"85", x"23", x"cf", x"32", x"99",
        x"31", x"14", x"ae", x"ee", x"c8", x"48", x"d3", x"30",
        x"a1", x"92", x"41", x"b1", x"18", x"c4", x"2c", x"71",
        x"72", x"44", x"15", x"fd", x"37", x"be", x"5f", x"aa",
        x"9b", x"88", x"d8", x"ab", x"89", x"9c", x"fa", x"60",
        x"ea", x"bc", x"62", x"0c", x"24", x"a6", x"a8", x"ec",
        x"67", x"20", x"db", x"7c", x"28", x"dd", x"ac", x"5b",
        x"34", x"7e", x"10", x"f1", x"7b", x"8f", x"63", x"a0",
        x"05", x"9a", x"43", x"77", x"21", x"bf", x"27", x"09",
        x"c3", x"9f", x"b6", x"d7", x"29", x"c2", x"eb", x"c0",
        x"a4", x"8b", x"8c", x"1d", x"fb", x"ff", x"c1", x"b2",
        x"97", x"2e", x"f8", x"65", x"f6", x"75", x"07", x"04",
        x"49", x"33", x"e4", x"d9", x"b9", x"d0", x"42", x"c7",
        x"6c", x"90", x"00", x"8e", x"6f", x"50", x"01", x"c5",
        x"da", x"47", x"3f", x"cd", x"69", x"a2", x"e2", x"7a",
        x"a7", x"c6", x"93", x"0f", x"0a", x"06", x"e6", x"2b",
        x"96", x"a3", x"1c", x"af", x"6a", x"12", x"84", x"39",
        x"e7", x"b0", x"82", x"f7", x"fe", x"9d", x"87", x"5c",
        x"81", x"35", x"de", x"b4", x"a5", x"fc", x"80", x"ef",
        x"cb", x"bb", x"6b", x"76", x"ba", x"5a", x"7d", x"78",
        x"0b", x"95", x"e3", x"ad", x"74", x"98", x"3b", x"36",
        x"64", x"6d", x"dc", x"f0", x"59", x"a9", x"4c", x"17",
        x"7f", x"91", x"b8", x"c9", x"57", x"1b", x"e0", x"61"
        ));

    function flatten(t : kboxes_t) return sbox_flat_t is
        variable f : sbox_flat_t;
    begin
        for k in 0 to 3 loop
            for b in 0 to 255 loop
                f(256*k + b) := t(k)(b);
            end loop;
        end loop;
        return f;
    end function flatten;

    constant SBOX_ENC : sbox_flat_t := flatten(SBOX_ENC_TAB);

    function build_sbox_dec return sbox_flat_t is
        variable d : sbox_flat_t := (others => (others => '0'));
    begin
        for k in 0 to 3 loop
            for b in 0 to 255 loop
                d(256*k + to_integer(SBOX_ENC(256*k + b))) := to_unsigned(b, 8);
            end loop;
        end loop;
        return d;
    end function build_sbox_dec;

    constant SBOX_DEC : sbox_flat_t := build_sbox_dec;

    -- m(row, col) = row0((col - row) mod 8)
    function circulant(r0 : mds_row_t) return mds_t is
        variable m : mds_t;
    begin
        for row in 0 to 7 loop
            for col in 0 to 7 loop
                m(row, col) := r0((col - row) mod 8);
            end loop;
        end loop;
        return m;
    end function circulant;

    constant MDS     : mds_t := circulant(MDS_ROW0);
    constant MDS_INV : mds_t := circulant(MDS_INV_ROW0);

    function rounds_for(nk : natural) return natural is
    begin
        case nk is
            when 2      => return 10;
            when 4      => return 14;
            when others => return 18;
        end case;
    end function rounds_for;

    -- Байт row стовпця col
    function get_byte(s : state_t; row, col : natural) return byte_t is
    begin
        return s(col)(8*row+7 downto 8*row);
    end function get_byte;

    function sub_bytes(s : state_t) return state_t is
        variable r : state_t(s'range);
        variable w : word64_t;
    begin
        for col in s'range loop
            for row in 0 to 7 loop
                w(8*row+7 downto 8*row) :=
                    SBOX_ENC(256*(row mod 4) + to_integer(get_byte(s, row, col)));
            end loop;
            r(col) := w;                       -- запис цілим словом
        end loop;
        return r;
    end function sub_bytes;

    function inv_sub_bytes(s : state_t) return state_t is
        variable r : state_t(s'range);
        variable w : word64_t;
    begin
        for col in s'range loop
            for row in 0 to 7 loop
                w(8*row+7 downto 8*row) :=
                    SBOX_DEC(256*(row mod 4) + to_integer(get_byte(s, row, col)));
            end loop;
            r(col) := w;
        end loop;
        return r;
    end function inv_sub_bytes;

    -- Рядок row зсувається на (row / (8/Nb)) позицій управо по стовпцях
    function shift_rows(s : state_t) return state_t is
        constant nb : natural := s'length;
        variable r  : state_t(s'range);
        variable w  : word64_t;
        variable sh : integer;
    begin
        -- Ітеруємо по стовпцю-ПРИЙМАЧУ: джерело для рядка row - це
        -- стовпець (col - sh) mod nb. Так кожен запис іде цілим словом.
        -- (VHDL "mod" дає невід'ємний результат для додатного nb.)
        for col in 0 to nb-1 loop
            sh := -1;
            for row in 0 to 7 loop
                if row mod (8 / nb) = 0 then
                    sh := sh + 1;
                end if;
                w(8*row+7 downto 8*row) := get_byte(s, row, (col - sh) mod nb);
            end loop;
            r(col) := w;
        end loop;
        return r;
    end function shift_rows;

    function inv_shift_rows(s : state_t) return state_t is
        constant nb : natural := s'length;
        variable r  : state_t(s'range);
        variable w  : word64_t;
        variable sh : integer;
    begin
        for col in 0 to nb-1 loop
            sh := -1;
            for row in 0 to 7 loop
                if row mod (8 / nb) = 0 then
                    sh := sh + 1;
                end if;
                w(8*row+7 downto 8*row) := get_byte(s, row, (col + sh) mod nb);
            end loop;
            r(col) := w;
        end loop;
        return r;
    end function inv_shift_rows;

    function matrix_multiply(s : state_t; m : mds_t) return state_t is
        variable r : state_t(s'range);
        variable w : word64_t;
        variable p : byte_t;
    begin
        for col in s'range loop
            for row in 0 to 7 loop
                p := (others => '0');
                for b in 0 to 7 loop
                    p := p xor gf_mul(get_byte(s, b, col), m(row, b), POLY_KALYNA);
                end loop;
                w(8*row+7 downto 8*row) := p;
            end loop;
            r(col) := w;
        end loop;
        return r;
    end function matrix_multiply;

    function mix_columns(s : state_t) return state_t is
    begin
        return matrix_multiply(s, MDS);
    end function mix_columns;

    function inv_mix_columns(s : state_t) return state_t is
    begin
        return matrix_multiply(s, MDS_INV);
    end function inv_mix_columns;

    function encipher_round(s : state_t) return state_t is
    begin
        return mix_columns(shift_rows(sub_bytes(s)));
    end function encipher_round;

    function decipher_round(s : state_t) return state_t is
    begin
        return inv_sub_bytes(inv_shift_rows(inv_mix_columns(s)));
    end function decipher_round;

    function add_mod(a, b : state_t) return state_t is
        variable r : state_t(a'range);
    begin
        for i in a'range loop
            r(i) := a(i) + b(i);
        end loop;
        return r;
    end function add_mod;

    function sub_mod(a, b : state_t) return state_t is
        variable r : state_t(a'range);
    begin
        for i in a'range loop
            r(i) := a(i) - b(i);
        end loop;
        return r;
    end function sub_mod;

    function xor_st(a, b : state_t) return state_t is
        variable r : state_t(a'range);
    begin
        for i in a'range loop
            r(i) := a(i) xor b(i);
        end loop;
        return r;
    end function xor_st;

    function rotate_words(s : state_t) return state_t is
        variable r : state_t(s'range);
    begin
        for i in 0 to s'length-2 loop
            r(i) := s(i+1);
        end loop;
        r(s'length-1) := s(0);
        return r;
    end function rotate_words;

    function shift_left_words(s : state_t) return state_t is
        variable r : state_t(s'range);
    begin
        for i in s'range loop
            r(i) := shift_left(s(i), 1);
        end loop;
        return r;
    end function shift_left_words;

    -- Стан трактується як рядок байтів (little-endian усередині слова)
    -- і циклічно зсувається вліво на 2*Nb+3 байти.
    function rotate_left_bytes(s : state_t) return state_t is
        constant nb     : natural := s'length;
        constant nbytes : natural := nb * 8;
        constant rot    : natural := 2*nb + 3;
        variable r      : state_t(s'range);
        variable w      : word64_t;
        variable src    : natural;
    begin
        for i in 0 to nb-1 loop                -- слово-приймач
            for j in 0 to 7 loop               -- байт усередині слова
                src := (8*i + j + rot) mod nbytes;
                w(8*j+7 downto 8*j) := get_byte(s, src mod 8, src/8);
            end loop;
            r(i) := w;
        end loop;
        return r;
    end function rotate_left_bytes;

    function to_state(v : unsigned; n : natural) return state_t is
        variable s : state_t(0 to n-1);
    begin
        for i in 0 to n-1 loop
            s(i) := v(64*i+63 downto 64*i);
        end loop;
        return s;
    end function to_state;

    function to_bus(s : state_t) return unsigned is
        variable v : unsigned(64*s'length-1 downto 0);
    begin
        for i in 0 to s'length-1 loop
            v(64*i+63 downto 64*i) := s(i);
        end loop;
        return v;
    end function to_bus;

end package body kalyna_package;
