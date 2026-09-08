-- =====================================================================
--  "Калина" (ДСТУ 7624:2014) - ядро шифру, режим простої заміни
--  Автор: Alex Melan
--
--  Один generic-модуль покриває всі п'ять варіантів стандарту:
--     Nb=2 Nk=2 -> 128/128, 10 раундів
--     Nb=2 Nk=4 -> 128/256, 14 раундів
--     Nb=4 Nk=4 -> 256/256, 14 раундів
--     Nb=4 Nk=8 -> 256/512, 18 раундів
--     Nb=8 Nk=8 -> 512/512, 18 раундів
--
--  Розгортання ключа - мікросеквенсор: один EncipherRound за такт.
--  Парні раундові ключі рахуються, непарні - циклічний зсув попереднього
--  парного на 2*Nb+3 байти.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.kalyna_package.all;

entity kalyna_cipher is
    generic (
        NB : natural := 2;                   -- слів у блоці  (2, 4, 8)
        NK : natural := 2                    -- слів у ключі  (2, 4, 8), NK = NB або 2*NB
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;

        key_in    : in  unsigned(64*NK-1 downto 0);
        key_start : in  std_logic;
        key_ready : out std_logic;

        start     : in  std_logic;
        decrypt   : in  std_logic;
        data_in   : in  unsigned(64*NB-1 downto 0);

        data_out  : out unsigned(64*NB-1 downto 0);
        done      : out std_logic;
        busy      : out std_logic
    );
end entity kalyna_cipher;

architecture Behavioral of kalyna_cipher is

    constant NR : natural := rounds_for(NK);

    subtype blk_t is state_t(0 to NB-1);
    type rk_array_t is array (0 to NR) of blk_t;

    type state_type is (IDLE,
                        KE_KT_A, KE_KT_B, KE_KT_C,        -- допоміжний ключ Kt
                        KE_PRE, KE_A, KE_B, KE_C,         -- парні раундові ключі
                        KE_ODD,                           -- непарні (зсувом)
                        ENC_ROUND, DEC_ROUND, FINISH);

    signal state : state_type;

    signal rk       : rk_array_t;
    signal kt       : blk_t;
    signal tmv      : blk_t;
    signal kt_round : blk_t;
    signal st       : blk_t;
    signal ini      : state_t(0 to NK-1);       -- "initial_data": ключ, що обертається
    signal k0, k1   : blk_t;

    signal rnd_e    : natural range 0 to NR;    -- номер парного раундового ключа
    signal half     : natural range 0 to 1;     -- яка половина ключа йде в роботу
    signal odd_i    : natural range 1 to NR+1;
    signal rnd      : integer range -1 to NR;

    signal kr       : std_logic;

    -- Початкове значення tmv: 0x0001000100010001 у кожному слові
    constant TMV_INIT : blk_t := (others => x"0001000100010001");

    -- Стартовий стан для обчислення Kt: слово 0 = Nb + Nk + 1
    function kt_seed return blk_t is
        variable s : blk_t := (others => (others => '0'));
    begin
        s(0) := to_unsigned(NB + NK + 1, 64);
        return s;
    end function kt_seed;

begin

    key_ready <= kr;

    -- Спільний раундовий датапат ---------------------------------------
    -- encipher_round викликається у шести станах автомата. Якщо лишити
    -- виклики на місцях, синтезатор побудує ШІСТЬ окремих комбінаційних
    -- раундів (для Nb=2 це ~9 тис. комірок кожен). Тому вхід раунду
    -- обирається мультиплексором, а сам раунд інстанціюється рівно один
    -- раз - разом із одним оберненим раундом для розшифрування.
    process(clk, reset)
        variable rin  : blk_t;      -- вхід спільного прямого раунду
        variable rout : blk_t;      -- encipher_round(rin)
        variable dout : blk_t;      -- decipher_round(st)
    begin
        if reset = '1' then
            state    <= IDLE;
            kr       <= '0';
            rnd_e    <= 0;
            half     <= 0;
            odd_i    <= 1;
            rnd      <= 0;
            done     <= '0';
            busy     <= '0';
            data_out <= (others => '0');

        elsif rising_edge(clk) then
            done <= '0';

            -- Вибір операнда для єдиного прямого раунду
            case state is
                when KE_KT_A => rin := add_mod(kt_seed, k0);
                when KE_KT_B => rin := xor_st(st, k1);
                when KE_KT_C => rin := add_mod(st, k0);
                when KE_A    => rin := add_mod(st, kt_round);
                when KE_B    => rin := xor_st(st, kt_round);
                when others  => rin := st;            -- ENC_ROUND тощо
            end case;

            rout := encipher_round(rin);              -- один екземпляр
            dout := decipher_round(st);               -- один екземпляр

            case state is

                when IDLE =>
                    busy <= '0';
                    if key_start = '1' then
                        ini <= to_state(key_in, NK);
                        k0  <= to_state(key_in, NK)(0 to NB-1);
                        -- k1 - друга половина ключа (при Nk = Nb це та сама k0)
                        k1 <= to_state(key_in, NK)(NK-NB to NK-1);
                        tmv   <= TMV_INIT;
                        rnd_e <= 0;
                        half  <= 0;
                        odd_i <= 1;
                        kr    <= '0';
                        busy  <= '1';
                        state <= KE_KT_A;

                    elsif start = '1' and kr = '1' then
                        busy <= '1';
                        if decrypt = '1' then
                            st    <= sub_mod(to_state(data_in, NB), rk(NR));
                            rnd   <= NR - 1;
                            state <= DEC_ROUND;
                        else
                            st    <= add_mod(to_state(data_in, NB), rk(0));
                            rnd   <= 1;
                            state <= ENC_ROUND;
                        end if;
                    end if;

                -- ---------- допоміжний ключ Kt: три раунди ----------
                when KE_KT_A =>
                    st    <= rout;
                    state <= KE_KT_B;

                when KE_KT_B =>
                    st    <= rout;
                    state <= KE_KT_C;

                when KE_KT_C =>
                    kt    <= rout;
                    state <= KE_PRE;

                -- ---------- парні раундові ключі ----------
                when KE_PRE =>
                    kt_round <= add_mod(kt, tmv);
                    -- Друга половина ключа існує лише при Nk = 2*Nb. Індекс
                    -- записано як NK-NB, а не NB: при Nk = Nb він дорівнює 0,
                    -- тож зріз лишається в межах масиву. Інакше синтезатор
                    -- будує обидві гілки й падає на виході за межі, хоча в
                    -- симуляції half там ніколи не дорівнює 1.
                    if half = 0 then
                        st <= ini(0 to NB-1);
                    else
                        st <= ini(NK-NB to NK-1);
                    end if;
                    state <= KE_A;

                when KE_A =>
                    st    <= rout;
                    state <= KE_B;

                when KE_B =>
                    st    <= rout;
                    state <= KE_C;

                when KE_C =>
                    rk(rnd_e) <= add_mod(st, kt_round);

                    if rnd_e = NR then
                        odd_i <= 1;
                        state <= KE_ODD;
                    elsif (NK /= NB) and (half = 0) then
                        -- при Nk = 2*Nb друга половина ключа дає наступний ключ
                        rnd_e <= rnd_e + 2;
                        tmv   <= shift_left_words(tmv);
                        half  <= 1;
                        state <= KE_PRE;
                    else
                        rnd_e <= rnd_e + 2;
                        tmv   <= shift_left_words(tmv);
                        ini   <= rotate_words(ini);
                        half  <= 0;
                        state <= KE_PRE;
                    end if;

                -- ---------- непарні ключі: зсув попереднього парного ----------
                when KE_ODD =>
                    rk(odd_i) <= rotate_left_bytes(rk(odd_i - 1));
                    if odd_i >= NR - 1 then
                        kr    <= '1';
                        busy  <= '0';
                        state <= IDLE;
                    else
                        odd_i <= odd_i + 2;
                    end if;

                -- ---------- зашифрування ----------
                when ENC_ROUND =>
                    if rnd < NR then
                        st  <= xor_st(rout, rk(rnd));
                        rnd <= rnd + 1;
                    else
                        data_out <= to_bus(add_mod(rout, rk(NR)));
                        state    <= FINISH;
                    end if;

                -- ---------- розшифрування ----------
                when DEC_ROUND =>
                    if rnd > 0 then
                        st  <= xor_st(dout, rk(rnd));
                        rnd <= rnd - 1;
                    else
                        data_out <= to_bus(sub_mod(dout, rk(0)));
                        state    <= FINISH;
                    end if;

                when FINISH =>
                    done  <= '1';
                    busy  <= '0';
                    state <= IDLE;

            end case;
        end if;
    end process;

end architecture Behavioral;
