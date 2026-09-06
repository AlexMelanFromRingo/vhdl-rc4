-- =====================================================================
--  "Струмок" (ДСТУ 8845:2019) - ядро потокового шифру
--  Автор: CleverBot
--
--  Один крок за такт:
--    * ініціалізація - 32 кроки (два повні проходи по 16 комірках),
--      під час яких вихід автомата заводиться назад у РЗЗЗ;
--    * робота - по одному 64-бітному слову гами за такт.
--
--  Зворотний зв'язок РЗЗЗ (з урахуванням того, що комірки з меншими
--  індексами вже оновлені на цьому проході):
--      S[i] = alpha*S[i] (+) S[(i+13) mod 16] (+) alpha^-1*S[(i+11) mod 16]
--  Автомат:
--      R1' = R2 + S[(i+13) mod 16],   R2' = T(R1)
--  Гама:
--      z_i = (R1' + S[i]) (+) R2' (+) S[(i+1) mod 16]
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.strumok_package.all;

entity strumok_cipher is
    generic (
        KEY_WORDS : natural := 4                  -- 4 -> ключ 256 біт, 8 -> 512 біт
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        key_in   : in  unsigned(64*KEY_WORDS-1 downto 0);  -- K0 у старших бітах
        iv_in    : in  unsigned(255 downto 0);             -- V0 у старших бітах
        init     : in  std_logic;
        ready    : out std_logic;

        en       : in  std_logic;                 -- запит наступного слова гами
        data_in  : in  unsigned(63 downto 0);     -- відкритий/шифрований текст
        ks_out   : out unsigned(63 downto 0);     -- сира гама
        data_out : out unsigned(63 downto 0);     -- data_in xor гама
        valid    : out std_logic
    );
end entity strumok_cipher;

architecture Behavioral of strumok_cipher is

    type state_type is (IDLE, INIT_STEP, RUN);

    signal state : state_type;

    signal S        : lfsr_t;
    signal r1, r2   : word64_t;                   -- у стандарті R1, R2
    signal idx      : natural range 0 to 15;
    signal init_cnt : natural range 0 to 32;
    signal rdy      : std_logic;

begin

    ready <= rdy;

    process(clk, reset)
        variable K       : lfsr_t;                -- слова ключа (використовуються перші KEY_WORDS)
        variable V       : lfsr_t;                -- слова IV (перші 4)
        variable i13,i11,i1 : natural range 0 to 15;
        variable fb      : word64_t;              -- новий вміст комірки
        variable z       : word64_t;              -- вихід автомата / гама
        variable nr1,nr2 : word64_t;
    begin
        if reset = '1' then
            state    <= IDLE;
            rdy      <= '0';
            idx      <= 0;
            init_cnt <= 0;
            r1       <= (others => '0');
            r2       <= (others => '0');
            valid    <= '0';
            ks_out   <= (others => '0');
            data_out <= (others => '0');

        elsif rising_edge(clk) then
            valid <= '0';

            -- init діє з будь-якого стану: це дозволяє перезапустити шифр
            -- на новому ключі чи новому IV, не смикаючи асинхронний reset.
            if init = '1' then
                for n in 0 to KEY_WORDS-1 loop
                    K(n) := word_of(key_in, n);
                end loop;
                for n in 0 to 3 loop
                    V(n) := word_of(iv_in, n);
                end loop;

                -- Початкове заповнення РЗЗЗ (ДСТУ 8845:2019)
                if KEY_WORDS = 4 then      -- Струмок-256
                    S(0)  <= K(3) xor V(0);  S(1)  <= K(2);
                    S(2)  <= K(1) xor V(1);  S(3)  <= K(0) xor V(2);
                    S(4)  <= K(3);           S(5)  <= K(2) xor V(3);
                    S(6)  <= not K(1);       S(7)  <= not K(0);
                    S(8)  <= K(3);           S(9)  <= K(2);
                    S(10) <= not K(1);       S(11) <= K(0);
                    S(12) <= K(3);           S(13) <= not K(2);
                    S(14) <= K(1);           S(15) <= not K(0);
                else                        -- Струмок-512
                    S(0)  <= K(7) xor V(0);  S(1)  <= K(6);
                    S(2)  <= K(5);           S(3)  <= K(4) xor V(1);
                    S(4)  <= K(3);           S(5)  <= K(2) xor V(2);
                    S(6)  <= K(1);           S(7)  <= not K(0);
                    S(8)  <= K(4) xor V(3);  S(9)  <= not K(6);
                    S(10) <= K(5);           S(11) <= not K(7);
                    S(12) <= K(3);           S(13) <= K(2);
                    S(14) <= not K(1);       S(15) <= K(0);
                end if;

                r1       <= (others => '0');
                r2       <= (others => '0');
                idx      <= 0;
                init_cnt <= 0;
                rdy      <= '0';
                state    <= INIT_STEP;

            else
              case state is

                when IDLE =>
                    null;                         -- чекаємо на init

                -- 32 кроки ініціалізації: вихід автомата йде у зворотний зв'язок
                when INIT_STEP =>
                    i13 := (idx + 13) mod 16;
                    i11 := (idx + 11) mod 16;

                    z   := (r1 + S((idx + 15) mod 16)) xor r2;
                    fb  := a_mul(S(idx)) xor S(i13) xor ainv_mul(S(i11)) xor z;

                    nr1 := r2 + S(i13);
                    nr2 := t_transform(r1);

                    S(idx) <= fb;
                    r1     <= nr1;
                    r2     <= nr2;
                    idx    <= (idx + 1) mod 16;

                    if init_cnt = 31 then
                        rdy   <= '1';
                        state <= RUN;
                    else
                        init_cnt <= init_cnt + 1;
                    end if;

                -- Робочий режим: одне слово гами за такт
                when RUN =>
                    if en = '1' then
                        i13 := (idx + 13) mod 16;
                        i11 := (idx + 11) mod 16;
                        i1  := (idx + 1)  mod 16;

                        fb  := a_mul(S(idx)) xor S(i13) xor ainv_mul(S(i11));

                        nr1 := r2 + S(i13);
                        nr2 := t_transform(r1);

                        -- Гама рахується вже на оновлених R1', R2' та S[i]
                        z := (nr1 + fb) xor nr2 xor S(i1);

                        S(idx)   <= fb;
                        r1       <= nr1;
                        r2       <= nr2;
                        idx      <= (idx + 1) mod 16;

                        ks_out   <= z;
                        data_out <= data_in xor z;
                        valid    <= '1';
                    end if;

              end case;
            end if;
        end if;
    end process;

end architecture Behavioral;
