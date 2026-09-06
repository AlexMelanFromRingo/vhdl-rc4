-- =====================================================================
--  "Струмок" (ДСТУ 8845:2019) - пакет перетворень
--  Автор: CleverBot
--
--  Потоковий шифр на базі SNOW 2.0: РЗЗЗ із 16 комірок по 64 біти над
--  GF(2^64) плюс кінцевий автомат із двох 64-бітних регістрів R1, R2.
--
--  ГОЛОВНЕ СПОСТЕРЕЖЕННЯ: перетворення T у Струмку - це в точності
--  MixColumns(SubBytes(.)) з Калини, застосоване до одного 64-бітного
--  стовпця. Тому тут не потрібні власні таблиці T0..T7 (8 x 256 x 64
--  біти) - ми просто викликаємо функції kalyna_package. Так само
--  таблиці множення на alpha будуються з однієї константи, бо
--  відображення b -> ALPHA_MUL(b) лінійне над GF(2^8).
--
--  Разом це прибирає ~2560 64-бітних констант із вихідного коду.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.kalyna_package.all;

package strumok_package is

    subtype word64_t is unsigned(63 downto 0);

    constant LFSR_LEN : natural := 16;
    type lfsr_t is array (0 to LFSR_LEN-1) of word64_t;

    -- Незвідний поліном GF(2^64) над GF(2^8) заданий редукційними
    -- константами: alpha^8 та (alpha^-1)^8 у байтовому представленні.
    constant ALPHA_C     : word64_t := x"d73f04125e000004";
    constant ALPHA_INV_C : word64_t := x"47fcc6018a990000";

    type alpha_tab_t is array (0 to 255) of word64_t;
    constant ALPHA_MUL     : alpha_tab_t;
    constant ALPHA_MUL_INV : alpha_tab_t;

    function a_mul   (w : word64_t) return word64_t;   -- множення на alpha
    function ainv_mul(w : word64_t) return word64_t;   -- множення на alpha^-1
    function t_transform(w : word64_t) return word64_t; -- T (через Калину)

    -- Слово i, рахуючи від старших бітів шини (як читається hex-рядок)
    function word_of(v : unsigned; i : natural) return word64_t;

end package strumok_package;


package body strumok_package is

    -- Побайтове множення 64-бітної константи на скаляр у GF(2^8)
    function scalar_mul64(b : byte_t; c : word64_t) return word64_t is
        variable r : word64_t;
    begin
        for i in 0 to 7 loop
            r(8*i+7 downto 8*i) := gf_mul(c(8*i+7 downto 8*i), b, POLY_KALYNA);
        end loop;
        return r;
    end function scalar_mul64;

    function build_alpha(c : word64_t) return alpha_tab_t is
        variable t : alpha_tab_t;
    begin
        for b in 0 to 255 loop
            t(b) := scalar_mul64(to_unsigned(b, 8), c);
        end loop;
        return t;
    end function build_alpha;

    constant ALPHA_MUL     : alpha_tab_t := build_alpha(ALPHA_C);
    constant ALPHA_MUL_INV : alpha_tab_t := build_alpha(ALPHA_INV_C);

    function a_mul(w : word64_t) return word64_t is
    begin
        return shift_left(w, 8) xor ALPHA_MUL(to_integer(w(63 downto 56)));
    end function a_mul;

    function ainv_mul(w : word64_t) return word64_t is
    begin
        return shift_right(w, 8) xor ALPHA_MUL_INV(to_integer(w(7 downto 0)));
    end function ainv_mul;

    -- T(w) = MixColumns(SubBytes(w)) з Калини на стані з одного стовпця
    function t_transform(w : word64_t) return word64_t is
        variable s : state_t(0 to 0);
    begin
        s(0) := w;
        return mix_columns(sub_bytes(s))(0);
    end function t_transform;

    function word_of(v : unsigned; i : natural) return word64_t is
        constant n : natural := v'length / 64;
    begin
        return v(64*(n-1-i)+63 downto 64*(n-1-i));
    end function word_of;

end package body strumok_package;
