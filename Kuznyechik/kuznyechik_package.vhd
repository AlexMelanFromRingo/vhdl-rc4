-- =====================================================================
--  "Кузнечик" (ГОСТ Р 34.12-2015 / RFC 7801) - пакет перетворень
--  Автор: Alex Melan
--
--  SP-мережа, блок 128 біт, ключ 256 біт, 10 раундів.
--  Байти блока нумеруються як у стандарті: a(0) - найстарший (a15),
--  a(15) - наймолодший (a0).
--
--  Лінійне перетворення L = R^16, де R - зсув регістра з лінійним
--  зворотним зв'язком у GF(2^8) за поліномом x^8+x^7+x^6+x+1.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;

package kuznyechik_package is

    constant NR : natural := 10;                     -- раундів (10 раундових ключів)

    type block_t is array (0 to 15) of byte_t;       -- 128-бітний блок
    type rkeys_t is array (1 to NR) of block_t;      -- раундові ключі K1..K10
    type consts_t is array (1 to 32) of block_t;     -- ітераційні константи C1..C32

    type sbox_t is array (0 to 255) of byte_t;

    constant PI     : sbox_t;                        -- нелінійна бієкція "пі"
    constant PI_INV : sbox_t;                        -- обернена до неї

    -- Коефіцієнти лінійного зворотного зв'язку l(): множники при a15..a0
    constant LVEC : block_t := (
        x"94", x"20", x"85", x"10", x"c2", x"c0", x"01", x"fb",
        x"01", x"c0", x"c2", x"10", x"85", x"20", x"94", x"01");

    function to_block(v : unsigned(127 downto 0)) return block_t;
    function to_word (b : block_t) return unsigned;

    function s_layer     (a : block_t) return block_t;   -- S
    function s_layer_inv (a : block_t) return block_t;   -- S^-1
    function l_layer     (a : block_t) return block_t;   -- L  = R^16
    function l_layer_inv (a : block_t) return block_t;   -- L^-1
    function x_layer     (a, k : block_t) return block_t; -- X[k]

    constant C_ITER : consts_t;                      -- C(i) = L(Vec128(i))

end package kuznyechik_package;


package body kuznyechik_package is

    constant PI : sbox_t := (
        x"fc", x"ee", x"dd", x"11", x"cf", x"6e", x"31", x"16",
        x"fb", x"c4", x"fa", x"da", x"23", x"c5", x"04", x"4d",
        x"e9", x"77", x"f0", x"db", x"93", x"2e", x"99", x"ba",
        x"17", x"36", x"f1", x"bb", x"14", x"cd", x"5f", x"c1",
        x"f9", x"18", x"65", x"5a", x"e2", x"5c", x"ef", x"21",
        x"81", x"1c", x"3c", x"42", x"8b", x"01", x"8e", x"4f",
        x"05", x"84", x"02", x"ae", x"e3", x"6a", x"8f", x"a0",
        x"06", x"0b", x"ed", x"98", x"7f", x"d4", x"d3", x"1f",
        x"eb", x"34", x"2c", x"51", x"ea", x"c8", x"48", x"ab",
        x"f2", x"2a", x"68", x"a2", x"fd", x"3a", x"ce", x"cc",
        x"b5", x"70", x"0e", x"56", x"08", x"0c", x"76", x"12",
        x"bf", x"72", x"13", x"47", x"9c", x"b7", x"5d", x"87",
        x"15", x"a1", x"96", x"29", x"10", x"7b", x"9a", x"c7",
        x"f3", x"91", x"78", x"6f", x"9d", x"9e", x"b2", x"b1",
        x"32", x"75", x"19", x"3d", x"ff", x"35", x"8a", x"7e",
        x"6d", x"54", x"c6", x"80", x"c3", x"bd", x"0d", x"57",
        x"df", x"f5", x"24", x"a9", x"3e", x"a8", x"43", x"c9",
        x"d7", x"79", x"d6", x"f6", x"7c", x"22", x"b9", x"03",
        x"e0", x"0f", x"ec", x"de", x"7a", x"94", x"b0", x"bc",
        x"dc", x"e8", x"28", x"50", x"4e", x"33", x"0a", x"4a",
        x"a7", x"97", x"60", x"73", x"1e", x"00", x"62", x"44",
        x"1a", x"b8", x"38", x"82", x"64", x"9f", x"26", x"41",
        x"ad", x"45", x"46", x"92", x"27", x"5e", x"55", x"2f",
        x"8c", x"a3", x"a5", x"7d", x"69", x"d5", x"95", x"3b",
        x"07", x"58", x"b3", x"40", x"86", x"ac", x"1d", x"f7",
        x"30", x"37", x"6b", x"e4", x"88", x"d9", x"e7", x"89",
        x"e1", x"1b", x"83", x"49", x"4c", x"3f", x"f8", x"fe",
        x"8d", x"53", x"aa", x"90", x"ca", x"d8", x"85", x"61",
        x"20", x"71", x"67", x"a4", x"2d", x"2b", x"09", x"5b",
        x"cb", x"9b", x"25", x"d0", x"be", x"e5", x"6c", x"52",
        x"59", x"a6", x"74", x"d2", x"e6", x"f4", x"b4", x"c0",
        x"d1", x"66", x"af", x"c2", x"39", x"4b", x"63", x"b6");

    -- PI_INV будується на етапі елаборації: PI - бієкція, тож достатньо
    -- обернути відповідність індекс <-> значення.
    function build_pi_inv return sbox_t is
        variable inv : sbox_t := (others => (others => '0'));
    begin
        for i in 0 to 255 loop
            inv(to_integer(PI(i))) := to_unsigned(i, 8);
        end loop;
        return inv;
    end function build_pi_inv;

    constant PI_INV : sbox_t := build_pi_inv;

    function to_block(v : unsigned(127 downto 0)) return block_t is
        variable b : block_t;
    begin
        for i in 0 to 15 loop
            b(i) := v(127 - 8*i downto 120 - 8*i);   -- b(0) - найстарший байт
        end loop;
        return b;
    end function to_block;

    function to_word(b : block_t) return unsigned is
        variable v : unsigned(127 downto 0);
    begin
        for i in 0 to 15 loop
            v(127 - 8*i downto 120 - 8*i) := b(i);
        end loop;
        return v;
    end function to_word;

    function s_layer(a : block_t) return block_t is
        variable r : block_t;
    begin
        for i in 0 to 15 loop
            r(i) := PI(to_integer(a(i)));
        end loop;
        return r;
    end function s_layer;

    function s_layer_inv(a : block_t) return block_t is
        variable r : block_t;
    begin
        for i in 0 to 15 loop
            r(i) := PI_INV(to_integer(a(i)));
        end loop;
        return r;
    end function s_layer_inv;

    -- Лінійна функція зворотного зв'язку
    function lfsr_l(a : block_t) return byte_t is
        variable acc : byte_t := (others => '0');
    begin
        for i in 0 to 15 loop
            acc := acc xor gf_mul(a(i), LVEC(i), POLY_KUZNYECHIK);
        end loop;
        return acc;
    end function lfsr_l;

    -- R: зсув на байт "вниз", у звільнену старшу позицію - l(a)
    function r_step(a : block_t) return block_t is
        variable r : block_t;
    begin
        r(0) := lfsr_l(a);
        for i in 1 to 15 loop
            r(i) := a(i-1);
        end loop;
        return r;
    end function r_step;

    -- R^-1: відновлюємо наймолодший байт із збереженого значення l(a)
    function r_step_inv(b : block_t) return block_t is
        variable a   : block_t;
        variable acc : byte_t := (others => '0');
    begin
        for i in 0 to 14 loop
            a(i) := b(i+1);
        end loop;
        for i in 0 to 14 loop
            acc := acc xor gf_mul(a(i), LVEC(i), POLY_KUZNYECHIK);
        end loop;
        a(15) := b(0) xor acc;                       -- бо LVEC(15) = 1
        return a;
    end function r_step_inv;

    function l_layer(a : block_t) return block_t is
        variable v : block_t := a;
    begin
        for i in 1 to 16 loop
            v := r_step(v);
        end loop;
        return v;
    end function l_layer;

    function l_layer_inv(a : block_t) return block_t is
        variable v : block_t := a;
    begin
        for i in 1 to 16 loop
            v := r_step_inv(v);
        end loop;
        return v;
    end function l_layer_inv;

    function x_layer(a, k : block_t) return block_t is
        variable r : block_t;
    begin
        for i in 0 to 15 loop
            r(i) := a(i) xor k(i);
        end loop;
        return r;
    end function x_layer;

    -- Ітераційні константи рахуються один раз на етапі елаборації,
    -- тож у синтезованій схемі це ПЗП, а не окремий блок L.
    function build_consts return consts_t is
        variable c : consts_t;
        variable v : block_t;
    begin
        for i in 1 to 32 loop
            v      := (others => (others => '0'));
            v(15)  := to_unsigned(i, 8);             -- Vec128(i)
            c(i)   := l_layer(v);
        end loop;
        return c;
    end function build_consts;

    constant C_ITER : consts_t := build_consts;

end package body kuznyechik_package;
