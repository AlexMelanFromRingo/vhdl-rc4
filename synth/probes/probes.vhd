-- =====================================================================
--  Зонди для витягування схем окремих блоків
--  Автор: CleverBot
--
--  Це НЕ частина шифрів. Кожна сутність відкриває один примітив як
--  окремий модуль, щоб Yosys/netlistsvg могли намалювати його схему.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;

-- Загальний множник у GF(2^8): обидва операнди змінні.
-- Це "атом" і Калини, і Кузнечика - різниця лише в поліномі.
entity probe_gf_mul is
    port (
        a : in  unsigned(7 downto 0);
        b : in  unsigned(7 downto 0);
        y : out unsigned(7 downto 0)
    );
end entity probe_gf_mul;

architecture rtl of probe_gf_mul is
begin
    y <= gf_mul(a, b, POLY_KALYNA);
end architecture rtl;

-- -------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;

-- Множення на КОНСТАНТУ 0x05 - саме так елементи MDS-матриці Калини
-- потрапляють у залізо. Вироджується в кілька XOR.
entity probe_gf_mul_const is
    port (
        a : in  unsigned(7 downto 0);
        y : out unsigned(7 downto 0)
    );
end entity probe_gf_mul_const;

architecture rtl of probe_gf_mul_const is
begin
    y <= gf_mul(a, x"05", POLY_KALYNA);
end architecture rtl;

-- -------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gost_package.all;

-- Раундова функція ГОСТ 28147-89: суматор mod 2^32, вісім S-блоків
-- по 4 біти, циклічний зсув на 11. Зсув - це просто перестановка
-- провідників, тому у вентилях його не видно.
entity probe_gost_f is
    port (
        x : in  unsigned(31 downto 0);
        k : in  unsigned(31 downto 0);
        y : out unsigned(31 downto 0)
    );
end entity probe_gost_f;

architecture rtl of probe_gost_f is
begin
    y <= gost_f(x, k, S_TC26_Z);
end architecture rtl;

-- -------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.kalyna_package.all;

-- Один раунд Калини для Nb=2: SubBytes -> ShiftRows -> MixColumns.
entity probe_kalyna_round is
    port (
        d : in  unsigned(127 downto 0);
        q : out unsigned(127 downto 0)
    );
end entity probe_kalyna_round;

architecture rtl of probe_kalyna_round is
begin
    q <= to_bus(encipher_round(to_state(d, 2)));
end architecture rtl;
