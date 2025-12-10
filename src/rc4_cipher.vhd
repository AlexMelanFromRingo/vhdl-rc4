-- RC4 Cipher: Основна реалізація (виправлена версія)
-- Автор: CleverBot
-- Опис: Спрощена реалізація RC4 з правильною обробкою S-box

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_cipher is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Керуючі сигнали
        start       : in  std_logic;
        key_length  : in  unsigned(7 downto 0);

        -- Вхідні дані
        key_in      : in  unsigned(7 downto 0);
        key_valid   : in  std_logic;

        data_in     : in  unsigned(7 downto 0);
        data_valid  : in  std_logic;

        -- Вихідні дані
        data_out    : out unsigned(7 downto 0);
        data_ready  : out std_logic;

        -- Статус
        busy        : out std_logic;
        ksa_done    : out std_logic
    );
end rc4_cipher;

architecture Behavioral of rc4_cipher is
    -- S-box пам'ять
    signal sbox : sbox_type;

    -- Ключ
    signal key_mem : key_type;
    signal key_len : unsigned(7 downto 0);
    signal key_idx : unsigned(7 downto 0);
    signal ksa_key_idx : unsigned(7 downto 0);  -- Індекс ключа для KSA (замість mod)

    -- Індекси та лічильники
    signal i, j : unsigned(7 downto 0);
    signal cnt : unsigned(7 downto 0);

    -- Тимчасові змінні
    signal si, sj : unsigned(7 downto 0);
    signal t_val : unsigned(7 downto 0);

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
            ksa_key_idx <= (others => '0');
            data_out <= (others => '0');
            data_ready <= '0';
            busy <= '0';
            ksa_done <= '0';

        elsif rising_edge(clk) then
            data_ready <= '0';

            case state is
                -- Стан очікування
                when IDLE =>
                    busy <= '0';
                    ksa_done <= '0';
                    cnt <= (others => '0');
                    i <= (others => '0');
                    j <= (others => '0');
                    key_idx <= (others => '0');
                    ksa_key_idx <= (others => '0');

                    if start = '1' then
                        key_len <= key_length;
                        busy <= '1';
                        state <= INIT_SBOX;
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

                    -- Обчислюємо новий j (використовуємо ksa_key_idx замість cnt mod key_len)
                    new_j := j + sbox(to_integer(cnt)) +
                             key_mem(to_integer(ksa_key_idx));

                    -- Читаємо S[new_j]
                    sj <= sbox(to_integer(new_j));

                    -- Записуємо swap: S[cnt] = S[new_j], S[new_j] = S[cnt]
                    sbox(to_integer(cnt)) <= sbox(to_integer(new_j));
                    sbox(to_integer(new_j)) <= sbox(to_integer(cnt));

                    j <= new_j;

                    -- Оновлення індексу ключа (циклічний лічильник замість mod)
                    if ksa_key_idx = key_len - 1 then
                        ksa_key_idx <= (others => '0');
                    else
                        ksa_key_idx <= ksa_key_idx + 1;
                    end if;

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
                    -- Читаємо S[t]
                    data_out <= data_in xor sbox(to_integer(t_val));
                    data_ready <= '1';
                    state <= PRGA_READY;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
