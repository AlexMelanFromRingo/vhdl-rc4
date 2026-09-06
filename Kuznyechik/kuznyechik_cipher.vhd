-- =====================================================================
--  "Кузнечик" (ГОСТ Р 34.12-2015) - ядро шифру, режим простої заміни
--  Автор: CleverBot
--
--  Дві незалежні фази:
--    key_start -> розгортання ключа (32 такти, мережа Фейстеля на
--                 ітераційних константах C1..C32), піднімає key_ready;
--    start     -> обробка одного блока (10 тактів, раунд за такт).
--  Раундові ключі зберігаються, тож наступні блоки не платять за
--  повторне розгортання - саме так і робить реальний ECB/CTR-конвеєр.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.kuznyechik_package.all;

entity kuznyechik_cipher is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;

        key_in    : in  unsigned(255 downto 0);   -- K1 у старших 128 бітах
        key_start : in  std_logic;
        key_ready : out std_logic;

        start     : in  std_logic;
        decrypt   : in  std_logic;
        data_in   : in  unsigned(127 downto 0);

        data_out  : out unsigned(127 downto 0);
        done      : out std_logic;
        busy      : out std_logic
    );
end entity kuznyechik_cipher;

architecture Behavioral of kuznyechik_cipher is

    type state_type is (IDLE, KS_STEP, ENC_ROUND, DEC_ROUND, FINISH);

    signal state : state_type;

    signal rk        : rkeys_t;                    -- раундові ключі K1..K10
    signal ks_a      : block_t;                    -- половини Фейстеля розгортки
    signal ks_b      : block_t;
    signal ks_i      : natural range 1 to 33;      -- номер ітераційної константи

    signal blk       : block_t;                    -- поточний стан шифрування
    signal rnd       : natural range 0 to NR;

    signal kr        : std_logic;

begin

    key_ready <= kr;

    process(clk, reset)
        variable tmp : block_t;
    begin
        if reset = '1' then
            state    <= IDLE;
            kr       <= '0';
            ks_i     <= 1;
            rnd      <= 0;
            done     <= '0';
            busy     <= '0';
            data_out <= (others => '0');

        elsif rising_edge(clk) then
            done <= '0';

            case state is

                when IDLE =>
                    busy <= '0';
                    if key_start = '1' then
                        -- K1, K2 - це просто дві половини вихідного ключа
                        rk(1) <= to_block(key_in(255 downto 128));
                        rk(2) <= to_block(key_in(127 downto 0));
                        ks_a  <= to_block(key_in(255 downto 128));
                        ks_b  <= to_block(key_in(127 downto 0));
                        ks_i  <= 1;
                        kr    <= '0';
                        busy  <= '1';
                        state <= KS_STEP;

                    elsif start = '1' and kr = '1' then
                        busy <= '1';
                        if decrypt = '1' then
                            -- Розшифрування починається зі зняття K10
                            blk   <= x_layer(to_block(data_in), rk(NR));
                            rnd   <= NR - 1;                   -- далі K9..K1
                            state <= DEC_ROUND;
                        else
                            blk   <= to_block(data_in);
                            rnd   <= 1;                        -- раунди K1..K9
                            state <= ENC_ROUND;
                        end if;
                    end if;

                -- Розгортання ключа: 32 кроки мережі Фейстеля
                when KS_STEP =>
                    tmp := x_layer(l_layer(s_layer(x_layer(ks_a, C_ITER(ks_i)))), ks_b);
                    ks_a <= tmp;
                    ks_b <= ks_a;

                    -- Кожні 8 кроків народжується пара раундових ключів
                    if ks_i mod 8 = 0 then
                        rk(3 + 2*(ks_i/8 - 1)) <= tmp;
                        rk(4 + 2*(ks_i/8 - 1)) <= ks_a;
                    end if;

                    if ks_i = 32 then
                        kr    <= '1';
                        busy  <= '0';
                        state <= IDLE;
                    else
                        ks_i <= ks_i + 1;
                    end if;

                -- Зашифрування: 9 раундів X-S-L, потім завершальне X[K10]
                when ENC_ROUND =>
                    if rnd < NR then
                        blk <= l_layer(s_layer(x_layer(blk, rk(rnd))));
                        rnd <= rnd + 1;
                    else
                        data_out <= to_word(x_layer(blk, rk(NR)));
                        state    <= FINISH;
                    end if;

                -- Розшифрування: 9 раундів X-(L^-1)-(S^-1)
                when DEC_ROUND =>
                    tmp := x_layer(s_layer_inv(l_layer_inv(blk)), rk(rnd));
                    if rnd = 1 then
                        data_out <= to_word(tmp);
                        state    <= FINISH;
                    else
                        blk <= tmp;
                        rnd <= rnd - 1;
                    end if;

                when FINISH =>
                    done  <= '1';
                    busy  <= '0';
                    state <= IDLE;

            end case;
        end if;
    end process;

end architecture Behavioral;
