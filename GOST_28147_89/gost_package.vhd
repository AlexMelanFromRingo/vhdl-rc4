-- =====================================================================
--  ГОСТ 28147-89 - пакет: таблиці замін, типи, раундова функція
--  Автор: CleverBot
--  Стандарт: ГОСТ 28147-89 / RFC 5830; набір TC26-Z відповідає
--            "Магмі" з ГОСТ Р 34.12-2015 (RFC 8891).
--
--  Домовленість про порядок: S_BOX(0) застосовується до молодшого
--  півбайта, S_BOX(7) - до старшого.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package gost_package is

    subtype nibble_t  is unsigned(3 downto 0);
    subtype word32_t  is unsigned(31 downto 0);

    type sbox_row_t is array (0 to 15) of nibble_t;
    type sbox_t     is array (0 to 7)  of sbox_row_t;

    -- Ключ як вісім 32-бітних підключів X0..X7
    type gost_key_t is array (0 to 7) of word32_t;

    constant ROUNDS : natural := 32;

    -- Допоміжна функція побудови рядка таблиці з цілих
    type int_row_t is array (0 to 15) of integer;
    function make_row(v : int_row_t) return sbox_row_t;

    -- "Test parameters" з ГОСТ 28147-89
    constant S_TEST : sbox_t;
    -- id-Gost28147-89-CryptoPro-A-ParamSet (RFC 4357)
    constant S_CRYPTOPRO_A : sbox_t;
    -- id-tc26-gost-28147-param-Z, він же S-блок "Магми" (ГОСТ Р 34.12-2015)
    constant S_TC26_Z : sbox_t;

    -- Раундова функція: f(x,k) = ROL11( S( (x + k) mod 2^32 ) )
    function gost_f(x : word32_t; k : word32_t; sbox : sbox_t) return word32_t;

    -- Номер підключа для раунду r (0..31).
    -- Зашифрування: 0..7, 0..7, 0..7, потім 7..0.
    function key_index(r : natural; decrypting : boolean) return natural;

    -- Розбір 256-бітного ключа: старші 32 біти -> X0
    function slice_key(k : unsigned(255 downto 0)) return gost_key_t;

end package gost_package;


package body gost_package is

    function make_row(v : int_row_t) return sbox_row_t is
        variable r : sbox_row_t;
    begin
        for i in 0 to 15 loop
            r(i) := to_unsigned(v(i), 4);
        end loop;
        return r;
    end function make_row;

    constant S_TEST : sbox_t := (
        make_row(( 4,10, 9, 2,13, 8, 0,14, 6,11, 1,12, 7,15, 5, 3)),
        make_row((14,11, 4,12, 6,13,15,10, 2, 3, 8, 1, 0, 7, 5, 9)),
        make_row(( 5, 8, 1,13,10, 3, 4, 2,14,15,12, 7, 6, 0, 9,11)),
        make_row(( 7,13,10, 1, 0, 8, 9,15,14, 4, 6,12,11, 2, 5, 3)),
        make_row(( 6,12, 7, 1, 5,15,13, 8, 4,10, 9,14, 0, 3,11, 2)),
        make_row(( 4,11,10, 0, 7, 2, 1,13, 3, 6, 8, 5, 9,12,15,14)),
        make_row((13,11, 4, 1, 3,15, 5, 9, 0,10,14, 7, 6, 8, 2,12)),
        make_row(( 1,15,13, 0, 5, 7,10, 4, 9, 2, 3,14, 6,11, 8,12)));

    constant S_CRYPTOPRO_A : sbox_t := (
        make_row(( 9, 6, 3, 2, 8,11, 1, 7,10, 4,14,15,12, 0,13, 5)),
        make_row(( 3, 7,14, 9, 8,10,15, 0, 5, 2, 6,12,11, 4,13, 1)),
        make_row((14, 4, 6, 2,11, 3,13, 8,12,15, 5,10, 0, 7, 1, 9)),
        make_row((14, 7,10,12,13, 1, 3, 9, 0, 2,11, 4,15, 8, 5, 6)),
        make_row((11, 5, 1, 9, 8,13,15, 0,14, 4, 2, 3,12, 7,10, 6)),
        make_row(( 3,10,13,12, 1, 2, 0,11, 7, 5, 9, 4, 8,15,14, 6)),
        make_row(( 1,13, 2, 9, 7,10, 6, 0, 8,12, 4, 5,15, 3,11,14)),
        make_row((11,10,15, 5, 0,12,14, 8, 6, 2, 3, 9, 1, 7,13, 4)));

    constant S_TC26_Z : sbox_t := (
        make_row((12, 4, 6, 2,10, 5,11, 9,14, 8,13, 7, 0, 3,15, 1)),
        make_row(( 6, 8, 2, 3, 9,10, 5,12, 1,14, 4, 7,11,13, 0,15)),
        make_row((11, 3, 5, 8, 2,15,10,13,14, 1, 7, 4,12, 9, 6, 0)),
        make_row((12, 8, 2, 1,13, 4,15, 6, 7, 0,10, 5, 3,14, 9,11)),
        make_row(( 7,15, 5,10, 8, 1, 6,13, 0, 9, 3,14,11, 4, 2,12)),
        make_row(( 5,13,15, 6, 9, 2,12,10,11, 7, 8, 1, 4, 3,14, 0)),
        make_row(( 8,14, 2, 5, 6, 9, 1,12,15, 4,11, 0,13,10, 3, 7)),
        make_row(( 1, 7,14,13, 0, 5, 8, 3, 4,15,10, 6, 9,12,11, 2)));

    function gost_f(x : word32_t; k : word32_t; sbox : sbox_t) return word32_t is
        variable t : word32_t;
        variable v : word32_t := (others => '0');
    begin
        t := x + k;                                   -- додавання за модулем 2^32
        for i in 0 to 7 loop                          -- підстановка по півбайтах
            v(4*i+3 downto 4*i) := sbox(i)(to_integer(t(4*i+3 downto 4*i)));
        end loop;
        return rotate_left(v, 11);                    -- циклічний зсув вліво на 11
    end function gost_f;

    function key_index(r : natural; decrypting : boolean) return natural is
        variable rr : natural;
    begin
        rr := r;
        if decrypting then
            rr := ROUNDS - 1 - r;                     -- зворотний порядок раундів
        end if;
        if rr < 24 then
            return rr mod 8;
        else
            return 7 - (rr mod 8);
        end if;
    end function key_index;

    function slice_key(k : unsigned(255 downto 0)) return gost_key_t is
        variable x : gost_key_t;
    begin
        for i in 0 to 7 loop
            x(i) := k(255 - 32*i downto 224 - 32*i);  -- X0 - старші 32 біти
        end loop;
        return x;
    end function slice_key;

end package body gost_package;
