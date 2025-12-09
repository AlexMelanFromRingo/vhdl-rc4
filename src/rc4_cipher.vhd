-- RC4 Cipher: Основна реалізація
-- Автор: CleverBot
-- Опис: Реалізація RC4 для Xilinx ISE 8.1i / Spartan-3
--
-- Особливості:
--   - KSA виконується за 256 тактів (1 такт на ітерацію)
--   - PRGA виконується за 4 такти на байт
--   - Підтримка ключів від 1 до 256 байт
--   - Асинхронний reset

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_cipher is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Керуючі сигнали
        start       : in  std_logic;                    -- Старт ініціалізації
        key_length  : in  unsigned(7 downto 0);         -- Довжина ключа (1-256)

        -- Вхідні дані ключа
        key_in      : in  unsigned(7 downto 0);         -- Байт ключа
        key_valid   : in  std_logic;                    -- Валідність байту ключа

        -- Вхідні/вихідні дані
        data_in     : in  unsigned(7 downto 0);         -- Вхідний байт (plaintext/ciphertext)
        data_valid  : in  std_logic;                    -- Валідність вхідного байту
        data_out    : out unsigned(7 downto 0);         -- Вихідний байт (ciphertext/plaintext)
        data_ready  : out std_logic;                    -- Вихідний байт готовий

        -- Статус
        busy        : out std_logic;                    -- Модуль зайнятий
        ksa_done    : out std_logic;                    -- KSA завершено, готовий до шифрування
        err_out     : out std_logic                     -- Помилка (невірна довжина ключа)
    );
end rc4_cipher;

architecture Behavioral of rc4_cipher is
    -- S-box пам'ять
    signal sbox : sbox_type;

    -- Ключ
    signal key_mem : key_type;
    signal key_len : unsigned(7 downto 0);
    signal key_idx : unsigned(7 downto 0);

    -- Індекси та лічильники
    signal i, j : unsigned(7 downto 0);
    signal cnt : unsigned(7 downto 0);

    -- Тимчасові змінні для PRGA
    signal si, sj : unsigned(7 downto 0);
    signal t_val : unsigned(7 downto 0);

    -- Збереження вхідного байту для XOR
    signal data_in_reg : unsigned(7 downto 0);

    -- FSM
    signal state : state_type;

begin

    process(clk, reset)
        variable new_j : unsigned(7 downto 0);
    begin
        if reset = '1' then
            state <= IDLE;
            cnt <= (others => '0');
            i <= (others => '0');
            j <= (others => '0');
            key_idx <= (others => '0');
            key_len <= (others => '0');
            data_out <= (others => '0');
            data_in_reg <= (others => '0');
            data_ready <= '0';
            busy <= '0';
            ksa_done <= '0';
            err_out <= '0';
            si <= (others => '0');
            sj <= (others => '0');
            t_val <= (others => '0');

        elsif rising_edge(clk) then
            -- Скидання одноразових сигналів
            data_ready <= '0';

            case state is
                -- Стан очікування
                when IDLE =>
                    busy <= '0';
                    err_out <= '0';

                    if start = '1' then
                        -- Перевірка довжини ключа (1-255 байт)
                        if key_length = 0 then
                            -- Помилка: нульова довжина ключа
                            err_out <= '1';
                        else
                            key_len <= key_length;
                            -- Скидання ksa_done при новому запуску
                            ksa_done <= '0';
                            busy <= '1';
                            cnt <= (others => '0');
                            i <= (others => '0');
                            j <= (others => '0');
                            key_idx <= (others => '0');
                            state <= INIT_SBOX;
                        end if;
                    end if;

                -- Ініціалізація S-box
                when INIT_SBOX =>
                    sbox(to_integer(cnt)) <= cnt;

                    -- Паралельно завантажуємо ключ
                    if key_valid = '1' and key_idx < key_len then
                        key_mem(to_integer(key_idx)) <= key_in;
                        key_idx <= key_idx + 1;
                    end if;

                    if cnt = 255 then
                        cnt <= (others => '0');
                        j <= (others => '0');
                        state <= KSA_PROCESS;
                    else
                        cnt <= cnt + 1;
                    end if;

                -- Key Scheduling Algorithm
                when KSA_PROCESS =>
                    -- Читаємо S[cnt]
                    si <= sbox(to_integer(cnt));

                    -- Обчислюємо новий j
                    new_j := j + sbox(to_integer(cnt)) +
                             key_mem(to_integer(cnt mod key_len));

                    -- Читаємо S[new_j]
                    sj <= sbox(to_integer(new_j));

                    -- Записуємо swap: S[cnt] = S[new_j], S[new_j] = S[cnt]
                    sbox(to_integer(cnt)) <= sbox(to_integer(new_j));
                    sbox(to_integer(new_j)) <= sbox(to_integer(cnt));

                    j <= new_j;

                    if cnt = 255 then
                        ksa_done <= '1';
                        i <= (others => '0');
                        j <= (others => '0');
                        state <= PRGA_READY;
                    else
                        cnt <= cnt + 1;
                    end if;

                -- Готовність до шифрування
                when PRGA_READY =>
                    if data_valid = '1' then
                        -- Зберігаємо вхідний байт
                        data_in_reg <= data_in;
                        state <= PRGA_I_UPDATE;
                    end if;

                -- i = i + 1
                when PRGA_I_UPDATE =>
                    i <= i + 1;
                    si <= sbox(to_integer(i + 1));
                    state <= PRGA_J_UPDATE;

                -- j = j + S[i]
                when PRGA_J_UPDATE =>
                    j <= j + si;
                    sj <= sbox(to_integer(j + si));
                    state <= PRGA_SWAP;

                -- Swap S[i] та S[j]
                when PRGA_SWAP =>
                    sbox(to_integer(i)) <= sj;
                    sbox(to_integer(j)) <= si;

                    -- t = S[i] + S[j]
                    t_val <= si + sj;
                    state <= PRGA_OUTPUT;

                -- Генерація виходу
                when PRGA_OUTPUT =>
                    -- output = input XOR S[t]
                    data_out <= data_in_reg xor sbox(to_integer(t_val));
                    data_ready <= '1';
                    state <= PRGA_READY;

                -- Стан завершення (для явного завершення сесії)
                when DONE =>
                    busy <= '0';
                    -- Залишаємось у DONE до reset

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
