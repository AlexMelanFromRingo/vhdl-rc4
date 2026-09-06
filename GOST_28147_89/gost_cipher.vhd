-- =====================================================================
--  ГОСТ 28147-89 - ядро шифру, режим простої заміни (ECB)
--  Автор: CleverBot
--  Архітектура: збалансована сеть Фейстеля, 32 раунди, один раунд
--               за такт. Зашифрування та розшифрування відрізняються
--               лише порядком підключів, тож датапас спільний.
--
--  Домовленість про порти (як у RFC 8891 "Магма"):
--    key_in (255 downto 224) = X0 ... key_in(31 downto 0) = X7
--    data_in(63 downto 32)   = N2 (старша половина, a1)
--    data_in(31 downto 0)    = N1 (молодша половина, a0)
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gost_package.all;

entity gost_cipher is
    generic (
        SBOX : sbox_t := S_TC26_Z            -- набір таблиць замін
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        start    : in  std_logic;            -- запуск обробки блока
        decrypt  : in  std_logic;            -- '0' - зашифрувати, '1' - розшифрувати

        key_in   : in  unsigned(255 downto 0);
        data_in  : in  unsigned(63 downto 0);

        data_out : out unsigned(63 downto 0);
        done     : out std_logic;            -- один такт по завершенні
        busy     : out std_logic
    );
end entity gost_cipher;

architecture Behavioral of gost_cipher is

    type state_type is (IDLE, ROUND_STEP, FINISH);

    signal state    : state_type;
    signal n1, n2   : word32_t;              -- половини блока
    signal subkeys  : gost_key_t;
    signal rnd      : natural range 0 to ROUNDS;
    signal dec_reg  : boolean;

begin

    process(clk, reset)
        variable f_out  : word32_t;
        variable new_n1 : word32_t;
    begin
        if reset = '1' then
            state    <= IDLE;
            n1       <= (others => '0');
            n2       <= (others => '0');
            rnd      <= 0;
            dec_reg  <= false;
            data_out <= (others => '0');
            done     <= '0';
            busy     <= '0';

        elsif rising_edge(clk) then
            done <= '0';

            case state is

                when IDLE =>
                    busy <= '0';
                    if start = '1' then
                        subkeys <= slice_key(key_in);
                        n1      <= data_in(31 downto 0);
                        n2      <= data_in(63 downto 32);
                        dec_reg <= (decrypt = '1');
                        rnd     <= 0;
                        busy    <= '1';
                        state   <= ROUND_STEP;
                    end if;

                -- Один раунд Фейстеля за такт
                when ROUND_STEP =>
                    f_out  := gost_f(n1, subkeys(key_index(rnd, dec_reg)), SBOX);
                    new_n1 := n2 xor f_out;

                    if rnd = ROUNDS - 1 then
                        -- В останньому раунді половини НЕ міняються місцями:
                        -- результат = (N2 xor f) || N1
                        data_out <= new_n1 & n1;
                        state    <= FINISH;
                    else
                        n1  <= new_n1;
                        n2  <= n1;
                        rnd <= rnd + 1;
                    end if;

                when FINISH =>
                    done  <= '1';
                    busy  <= '0';
                    state <= IDLE;

            end case;
        end if;
    end process;

end architecture Behavioral;
