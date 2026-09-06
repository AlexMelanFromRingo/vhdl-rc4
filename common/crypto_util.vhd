-- =====================================================================
--  crypto_util - спільні примітиви для всіх шифрів проєкту
--  Автор: CleverBot
--  Опис:  форматування hex для звітів тестбенчів та множення у GF(2^8)
--         з параметризованим незвідним поліномом (Калина/Струмок 0x11D,
--         Кузнечик 0x1C3).
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package crypto_util is

    subtype byte_t is unsigned(7 downto 0);

    type byte_vector   is array (natural range <>) of byte_t;
    type word32_vector is array (natural range <>) of unsigned(31 downto 0);
    type word64_vector is array (natural range <>) of unsigned(63 downto 0);

    -- Незвідні поліноми GF(2^8), задані молодшим байтом
    constant POLY_KALYNA     : natural := 16#1D#;  -- x^8+x^4+x^3+x^2+1  (0x11D)
    constant POLY_KUZNYECHIK : natural := 16#C3#;  -- x^8+x^7+x^6+x+1    (0x1C3)

    -- Шістнадцятковий рядок довільної ширини (для report у тестбенчах)
    function to_hex(v : unsigned) return string;

    -- Множення у GF(2^8) за схемою "зсув-і-редукція"
    function gf_mul(a, b : byte_t; poly : natural) return byte_t;

end package crypto_util;


package body crypto_util is

    function to_hex(v : unsigned) return string is
        constant DIGITS : string(1 to 16) := "0123456789abcdef";
        constant N      : natural := (v'length + 3) / 4;
        variable padded : unsigned(N*4-1 downto 0) := (others => '0');
        variable s      : string(1 to N);
        variable nib    : natural;
    begin
        padded(v'length-1 downto 0) := v;
        for i in 0 to N-1 loop
            nib    := to_integer(padded(i*4+3 downto i*4));
            s(N-i) := DIGITS(nib+1);
        end loop;
        return s;
    end function to_hex;

    function gf_mul(a, b : byte_t; poly : natural) return byte_t is
        variable x   : byte_t := a;
        variable y   : byte_t := b;
        variable r   : byte_t := (others => '0');
        variable hi  : std_logic;
        constant RED : byte_t := to_unsigned(poly mod 256, 8);
    begin
        for i in 0 to 7 loop
            if y(0) = '1' then
                r := r xor x;
            end if;
            hi := x(7);
            x  := shift_left(x, 1);
            if hi = '1' then
                x := x xor RED;
            end if;
            y := shift_right(y, 1);
        end loop;
        return r;
    end function gf_mul;

end package body crypto_util;
