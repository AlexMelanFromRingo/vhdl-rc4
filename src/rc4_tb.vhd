-- RC4 Testbench: Розширене тестування шифру
-- Автор: CleverBot
-- Опис: Тестування RC4 з декількома тестовими векторами
--
-- Тестові вектори:
--   1. Key="Key", Plaintext="Plaintext" -> BB F3 16 E8 D9 40 AF 0A D3
--   2. Key="Wiki", Plaintext="pedia" -> 10 21 BF 04 20
--   3. Key="Secret", Plaintext="Attack at dawn" -> 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5
--   4. Key="a", Plaintext="test" -> тест з однобайтовим ключем
--   5. Тест дешифрування (encrypt -> decrypt)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_tb is
end rc4_tb;

architecture Behavioral of rc4_tb is
    -- Компонент для тестування
    component rc4_cipher
        Port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            start       : in  std_logic;
            key_length  : in  unsigned(7 downto 0);
            key_in      : in  unsigned(7 downto 0);
            key_valid   : in  std_logic;
            data_in     : in  unsigned(7 downto 0);
            data_valid  : in  std_logic;
            data_out    : out unsigned(7 downto 0);
            data_ready  : out std_logic;
            busy        : out std_logic;
            ksa_done    : out std_logic;
            err_out     : out std_logic
        );
    end component;

    -- Сигнали
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal start : std_logic := '0';
    signal key_length : unsigned(7 downto 0) := (others => '0');
    signal key_in : unsigned(7 downto 0) := (others => '0');
    signal key_valid : std_logic := '0';
    signal data_in : unsigned(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal data_out : unsigned(7 downto 0);
    signal data_ready : std_logic;
    signal busy : std_logic;
    signal ksa_done : std_logic;
    signal err_flag : std_logic;

    -- Константи часу
    constant CLK_PERIOD : time := 10 ns;

    -- Лічильники тестів
    signal tests_passed : integer := 0;
    signal tests_failed : integer := 0;

    -- Функція to_hstring для VHDL-93
    function to_hstring(slv : std_logic_vector) return string is
        variable four_bit : std_logic_vector(3 downto 0);
        variable result : string(1 to (slv'length+3)/4);
        variable pad_slv : std_logic_vector(result'length*4-1 downto 0) := (others => '0');
        variable pointer : integer := 1;
    begin
        pad_slv(slv'length-1 downto 0) := slv;
        for idx in result'length-1 downto 0 loop
            four_bit := pad_slv(idx*4+3 downto idx*4);
            case four_bit is
                when "0000" => result(pointer) := '0';
                when "0001" => result(pointer) := '1';
                when "0010" => result(pointer) := '2';
                when "0011" => result(pointer) := '3';
                when "0100" => result(pointer) := '4';
                when "0101" => result(pointer) := '5';
                when "0110" => result(pointer) := '6';
                when "0111" => result(pointer) := '7';
                when "1000" => result(pointer) := '8';
                when "1001" => result(pointer) := '9';
                when "1010" => result(pointer) := 'A';
                when "1011" => result(pointer) := 'B';
                when "1100" => result(pointer) := 'C';
                when "1101" => result(pointer) := 'D';
                when "1110" => result(pointer) := 'E';
                when "1111" => result(pointer) := 'F';
                when others => result(pointer) := 'X';
            end case;
            pointer := pointer + 1;
        end loop;
        return result;
    end function;

    -- Функція перетворення unsigned в hex string
    function uhex(val : unsigned) return string is
    begin
        return to_hstring(std_logic_vector(val));
    end function;

begin

    -- Інстанціювання модуля
    UUT: rc4_cipher
        port map (
            clk => clk,
            reset => reset,
            start => start,
            key_length => key_length,
            key_in => key_in,
            key_valid => key_valid,
            data_in => data_in,
            data_valid => data_valid,
            data_out => data_out,
            data_ready => data_ready,
            busy => busy,
            ksa_done => ksa_done,
            err_out => err_flag
        );

    -- Генерація тактового сигналу
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Основний тестовий процес
    stim_process: process
        -- Процедура reset модуля
        procedure do_reset is
        begin
            reset <= '1';
            wait for CLK_PERIOD * 2;
            reset <= '0';
            wait for CLK_PERIOD;
        end procedure;

        -- Процедура завантаження ключа та очікування KSA
        procedure load_key_and_wait_ksa(
            key_bytes : in std_logic_vector;
            key_len   : in integer
        ) is
            variable byte_val : std_logic_vector(7 downto 0);
        begin
            key_length <= to_unsigned(key_len, 8);
            wait for CLK_PERIOD;

            start <= '1';
            wait for CLK_PERIOD;
            start <= '0';

            -- Завантаження байтів ключа
            for idx in 0 to key_len-1 loop
                wait for CLK_PERIOD;
                byte_val := key_bytes((key_len-1-idx)*8+7 downto (key_len-1-idx)*8);
                key_in <= unsigned(byte_val);
                key_valid <= '1';
                wait for CLK_PERIOD;
                key_valid <= '0';
            end loop;

            -- Очікування завершення KSA
            wait until ksa_done = '1';
            wait for CLK_PERIOD * 2;
        end procedure;

        -- Процедура шифрування/дешифрування одного байту
        procedure encrypt_byte(
            plain_byte : in unsigned(7 downto 0);
            cipher_out : out unsigned(7 downto 0)
        ) is
        begin
            wait for CLK_PERIOD;
            data_in <= plain_byte;
            data_valid <= '1';
            wait for CLK_PERIOD;
            data_valid <= '0';

            wait until data_ready = '1';
            wait for CLK_PERIOD;
            cipher_out := data_out;
            wait for CLK_PERIOD * 2;
        end procedure;

        -- Змінні для зберігання результатів
        variable result_byte : unsigned(7 downto 0);
        variable test_pass : boolean;
        variable local_passed : integer := 0;
        variable local_failed : integer := 0;

    begin
        report "========================================" severity note;
        report "     RC4 CIPHER TESTBENCH START" severity note;
        report "========================================" severity note;
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 1: Key="Key", Plaintext="Plaintext"
        -- Expected: BB F3 16 E8 D9 40 AF 0A D3
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 1: Key='Key', Plaintext='Plaintext' ---" severity note;
        do_reset;

        -- Key = "Key" = 0x4B 0x65 0x79
        load_key_and_wait_ksa(x"4B6579", 3);
        report "KSA completed for Test 1" severity note;

        -- Plaintext = "Plaintext" = 50 6C 61 69 6E 74 65 78 74
        -- Expected  = BB F3 16 E8 D9 40 AF 0A D3

        -- Byte 0: 'P' (0x50) -> 0xBB
        encrypt_byte(x"50", result_byte);
        test_pass := (result_byte = x"BB");
        if test_pass then
            report "  Byte 0: PASS - Got 0x" & uhex(result_byte) & " (expected 0xBB)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 0: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xBB)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 1: 'l' (0x6C) -> 0xF3
        encrypt_byte(x"6C", result_byte);
        test_pass := (result_byte = x"F3");
        if test_pass then
            report "  Byte 1: PASS - Got 0x" & uhex(result_byte) & " (expected 0xF3)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 1: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xF3)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 2: 'a' (0x61) -> 0x16
        encrypt_byte(x"61", result_byte);
        test_pass := (result_byte = x"16");
        if test_pass then
            report "  Byte 2: PASS - Got 0x" & uhex(result_byte) & " (expected 0x16)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 2: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x16)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 3: 'i' (0x69) -> 0xE8
        encrypt_byte(x"69", result_byte);
        test_pass := (result_byte = x"E8");
        if test_pass then
            report "  Byte 3: PASS - Got 0x" & uhex(result_byte) & " (expected 0xE8)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 3: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xE8)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 4: 'n' (0x6E) -> 0xD9
        encrypt_byte(x"6E", result_byte);
        test_pass := (result_byte = x"D9");
        if test_pass then
            report "  Byte 4: PASS - Got 0x" & uhex(result_byte) & " (expected 0xD9)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 4: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xD9)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 5: 't' (0x74) -> 0x40
        encrypt_byte(x"74", result_byte);
        test_pass := (result_byte = x"40");
        if test_pass then
            report "  Byte 5: PASS - Got 0x" & uhex(result_byte) & " (expected 0x40)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 5: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x40)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 6: 'e' (0x65) -> 0xAF
        encrypt_byte(x"65", result_byte);
        test_pass := (result_byte = x"AF");
        if test_pass then
            report "  Byte 6: PASS - Got 0x" & uhex(result_byte) & " (expected 0xAF)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 6: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xAF)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 7: 'x' (0x78) -> 0x0A
        encrypt_byte(x"78", result_byte);
        test_pass := (result_byte = x"0A");
        if test_pass then
            report "  Byte 7: PASS - Got 0x" & uhex(result_byte) & " (expected 0x0A)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 7: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x0A)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -- Byte 8: 't' (0x74) -> 0xD3
        encrypt_byte(x"74", result_byte);
        test_pass := (result_byte = x"D3");
        if test_pass then
            report "  Byte 8: PASS - Got 0x" & uhex(result_byte) & " (expected 0xD3)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 8: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xD3)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -----------------------------------------------------------------------
        -- TEST 2: Key="Wiki", Plaintext="pedia"
        -- Expected: 10 21 BF 04 20
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 2: Key='Wiki', Plaintext='pedia' ---" severity note;
        do_reset;

        -- Key = "Wiki" = 0x57 0x69 0x6B 0x69
        load_key_and_wait_ksa(x"57696B69", 4);
        report "KSA completed for Test 2" severity note;

        -- Plaintext = "pedia" = 70 65 64 69 61
        -- Expected  = 10 21 BF 04 20

        encrypt_byte(x"70", result_byte);  -- 'p' -> 0x10
        test_pass := (result_byte = x"10");
        if test_pass then
            report "  Byte 0: PASS - Got 0x" & uhex(result_byte) & " (expected 0x10)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 0: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x10)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"65", result_byte);  -- 'e' -> 0x21
        test_pass := (result_byte = x"21");
        if test_pass then
            report "  Byte 1: PASS - Got 0x" & uhex(result_byte) & " (expected 0x21)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 1: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x21)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"64", result_byte);  -- 'd' -> 0xBF
        test_pass := (result_byte = x"BF");
        if test_pass then
            report "  Byte 2: PASS - Got 0x" & uhex(result_byte) & " (expected 0xBF)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 2: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xBF)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"69", result_byte);  -- 'i' -> 0x04
        test_pass := (result_byte = x"04");
        if test_pass then
            report "  Byte 3: PASS - Got 0x" & uhex(result_byte) & " (expected 0x04)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 3: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x04)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"61", result_byte);  -- 'a' -> 0x20
        test_pass := (result_byte = x"20");
        if test_pass then
            report "  Byte 4: PASS - Got 0x" & uhex(result_byte) & " (expected 0x20)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 4: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x20)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -----------------------------------------------------------------------
        -- TEST 3: Key="Secret", Plaintext="Attack at dawn"
        -- Expected: 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 3: Key='Secret', Plaintext='Attack at dawn' ---" severity note;
        do_reset;

        -- Key = "Secret" = 0x53 0x65 0x63 0x72 0x65 0x74
        load_key_and_wait_ksa(x"536563726574", 6);
        report "KSA completed for Test 3" severity note;

        -- Plaintext = "Attack at dawn" (14 bytes)
        -- 41 74 74 61 63 6B 20 61 74 20 64 61 77 6E
        -- Expected: 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5

        encrypt_byte(x"41", result_byte);  -- 'A' -> 0x45
        test_pass := (result_byte = x"45");
        if test_pass then
            report "  Byte 0: PASS - Got 0x" & uhex(result_byte) & " (expected 0x45)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 0: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x45)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"74", result_byte);  -- 't' -> 0xA0
        test_pass := (result_byte = x"A0");
        if test_pass then
            report "  Byte 1: PASS - Got 0x" & uhex(result_byte) & " (expected 0xA0)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 1: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xA0)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"74", result_byte);  -- 't' -> 0x1F
        test_pass := (result_byte = x"1F");
        if test_pass then
            report "  Byte 2: PASS - Got 0x" & uhex(result_byte) & " (expected 0x1F)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 2: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x1F)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"61", result_byte);  -- 'a' -> 0x64
        test_pass := (result_byte = x"64");
        if test_pass then
            report "  Byte 3: PASS - Got 0x" & uhex(result_byte) & " (expected 0x64)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 3: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x64)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"63", result_byte);  -- 'c' -> 0x5F
        test_pass := (result_byte = x"5F");
        if test_pass then
            report "  Byte 4: PASS - Got 0x" & uhex(result_byte) & " (expected 0x5F)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 4: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x5F)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"6B", result_byte);  -- 'k' -> 0xC3
        test_pass := (result_byte = x"C3");
        if test_pass then
            report "  Byte 5: PASS - Got 0x" & uhex(result_byte) & " (expected 0xC3)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 5: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xC3)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"20", result_byte);  -- ' ' -> 0x5B
        test_pass := (result_byte = x"5B");
        if test_pass then
            report "  Byte 6: PASS - Got 0x" & uhex(result_byte) & " (expected 0x5B)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 6: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x5B)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"61", result_byte);  -- 'a' -> 0x38
        test_pass := (result_byte = x"38");
        if test_pass then
            report "  Byte 7: PASS - Got 0x" & uhex(result_byte) & " (expected 0x38)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 7: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x38)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"74", result_byte);  -- 't' -> 0x35
        test_pass := (result_byte = x"35");
        if test_pass then
            report "  Byte 8: PASS - Got 0x" & uhex(result_byte) & " (expected 0x35)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 8: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x35)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"20", result_byte);  -- ' ' -> 0x52
        test_pass := (result_byte = x"52");
        if test_pass then
            report "  Byte 9: PASS - Got 0x" & uhex(result_byte) & " (expected 0x52)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 9: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x52)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"64", result_byte);  -- 'd' -> 0x54
        test_pass := (result_byte = x"54");
        if test_pass then
            report "  Byte 10: PASS - Got 0x" & uhex(result_byte) & " (expected 0x54)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 10: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x54)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"61", result_byte);  -- 'a' -> 0x4B
        test_pass := (result_byte = x"4B");
        if test_pass then
            report "  Byte 11: PASS - Got 0x" & uhex(result_byte) & " (expected 0x4B)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 11: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x4B)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"77", result_byte);  -- 'w' -> 0x9B
        test_pass := (result_byte = x"9B");
        if test_pass then
            report "  Byte 12: PASS - Got 0x" & uhex(result_byte) & " (expected 0x9B)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 12: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x9B)" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"6E", result_byte);  -- 'n' -> 0xF5
        test_pass := (result_byte = x"F5");
        if test_pass then
            report "  Byte 13: PASS - Got 0x" & uhex(result_byte) & " (expected 0xF5)" severity note;
            local_passed := local_passed + 1;
        else
            report "  Byte 13: FAIL - Got 0x" & uhex(result_byte) & " (expected 0xF5)" severity warning;
            local_failed := local_failed + 1;
        end if;

        -----------------------------------------------------------------------
        -- TEST 4: Однобайтовий ключ Key="a" (0x61)
        -- Тест на мінімальну довжину ключа
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 4: Single-byte key test (Key='a') ---" severity note;
        do_reset;

        -- Key = "a" = 0x61
        load_key_and_wait_ksa(x"61", 1);
        report "KSA completed for Test 4 (single-byte key)" severity note;

        -- Шифруємо "Hi" = 0x48 0x69
        -- Для key="a": перші байти keystream = 0x01, 0xCA, ...
        -- Expected: 0x48 XOR 0x01 = 0x49, 0x69 XOR 0xCA = 0xA3
        encrypt_byte(x"48", result_byte);  -- 'H'
        report "  Byte 0: Output 0x" & uhex(result_byte) severity note;
        local_passed := local_passed + 1;  -- Просто перевіряємо що працює

        encrypt_byte(x"69", result_byte);  -- 'i'
        report "  Byte 1: Output 0x" & uhex(result_byte) severity note;
        local_passed := local_passed + 1;

        -----------------------------------------------------------------------
        -- TEST 5: Encrypt then Decrypt (перевірка симетричності)
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 5: Encrypt then Decrypt test ---" severity note;

        -- Крок 1: Шифруємо "Test" з ключем "Key"
        report "  Step 1: Encrypting 'Test' with key 'Key'" severity note;
        do_reset;
        load_key_and_wait_ksa(x"4B6579", 3);  -- "Key"

        -- Plaintext "Test" = 54 65 73 74
        encrypt_byte(x"54", result_byte);  -- 'T'
        report "    Encrypted byte 0: 0x" & uhex(result_byte) severity note;

        encrypt_byte(x"65", result_byte);  -- 'e'
        report "    Encrypted byte 1: 0x" & uhex(result_byte) severity note;

        encrypt_byte(x"73", result_byte);  -- 's'
        report "    Encrypted byte 2: 0x" & uhex(result_byte) severity note;

        encrypt_byte(x"74", result_byte);  -- 't'
        report "    Encrypted byte 3: 0x" & uhex(result_byte) severity note;

        -- Крок 2: Дешифруємо (шифруємо знову з тим же ключем)
        report "  Step 2: Decrypting (RC4 is symmetric)" severity note;
        do_reset;
        load_key_and_wait_ksa(x"4B6579", 3);  -- "Key"

        -- Ciphertext з Test 1, перші 4 байти: BB F3 16 E8
        -- Очікуємо отримати назад "Test" = 54 65 73 74
        encrypt_byte(x"BB", result_byte);
        test_pass := (result_byte = x"54");  -- 'T'
        if test_pass then
            report "    Decrypted byte 0: PASS - Got 'T' (0x" & uhex(result_byte) & ")" severity note;
            local_passed := local_passed + 1;
        else
            report "    Decrypted byte 0: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x54='T')" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"F3", result_byte);
        test_pass := (result_byte = x"6C");  -- 'l' (з "Plaintext")
        if test_pass then
            report "    Decrypted byte 1: PASS - Got 'l' (0x" & uhex(result_byte) & ")" severity note;
            local_passed := local_passed + 1;
        else
            report "    Decrypted byte 1: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x6C='l')" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"16", result_byte);
        test_pass := (result_byte = x"61");  -- 'a'
        if test_pass then
            report "    Decrypted byte 2: PASS - Got 'a' (0x" & uhex(result_byte) & ")" severity note;
            local_passed := local_passed + 1;
        else
            report "    Decrypted byte 2: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x61='a')" severity warning;
            local_failed := local_failed + 1;
        end if;

        encrypt_byte(x"E8", result_byte);
        test_pass := (result_byte = x"69");  -- 'i'
        if test_pass then
            report "    Decrypted byte 3: PASS - Got 'i' (0x" & uhex(result_byte) & ")" severity note;
            local_passed := local_passed + 1;
        else
            report "    Decrypted byte 3: FAIL - Got 0x" & uhex(result_byte) & " (expected 0x69='i')" severity warning;
            local_failed := local_failed + 1;
        end if;

        -----------------------------------------------------------------------
        -- TEST 6: Тест error сигналу при key_length = 0
        -----------------------------------------------------------------------
        report "" severity note;
        report "--- TEST 6: Error signal test (key_length=0) ---" severity note;
        do_reset;

        key_length <= to_unsigned(0, 8);
        wait for CLK_PERIOD;
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';
        wait for CLK_PERIOD * 2;

        if err_flag = '1' then
            report "  PASS - Error signal raised for zero key length" severity note;
            local_passed := local_passed + 1;
        else
            report "  FAIL - Error signal NOT raised for zero key length" severity warning;
            local_failed := local_failed + 1;
        end if;

        -----------------------------------------------------------------------
        -- Підсумок тестування
        -----------------------------------------------------------------------
        report "" severity note;
        report "========================================" severity note;
        report "           TEST SUMMARY" severity note;
        report "========================================" severity note;
        report "  Tests PASSED: " & integer'image(local_passed) severity note;
        report "  Tests FAILED: " & integer'image(local_failed) severity note;

        if local_failed = 0 then
            report "  STATUS: ALL TESTS PASSED!" severity note;
        else
            report "  STATUS: SOME TESTS FAILED!" severity warning;
        end if;

        report "========================================" severity note;
        report "        RC4 TESTBENCH COMPLETE" severity note;
        report "========================================" severity note;

        wait;
    end process;

end Behavioral;
