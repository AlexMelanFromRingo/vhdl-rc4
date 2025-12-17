-- RC4 Testbench: Cipher verification
-- Author: Alex Melan
-- Test vectors:
--   1. Key="Key", Plaintext="Plaintext" -> BB F3 16 E8 D9 40 AF 0A D3 (encryption)
--   2. Key="Wiki", Plaintext="pedia" -> 10 21 BF 04 20 (encryption)
--   3. Key="Secret", Plaintext="Attack at dawn" -> 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5 (encryption)
--   4. Key="Key", Ciphertext from test 1 -> "Plaintext" (decryption verification)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_tb is
end rc4_tb;

architecture Behavioral of rc4_tb is
    -- Component under test
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
            ksa_done    : out std_logic
        );
    end component;

    -- Test signals
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

    -- Clock period
    constant clk_period : time := 10 ns;

    -- to_hstring function for VHDL-93 compatibility
    function to_hstring(slv : std_logic_vector) return string is
        variable four_bit : std_logic_vector(3 downto 0);
        variable result : string(1 to (slv'length+3)/4);
        variable pad_slv : std_logic_vector(result'length*4-1 downto 0) := (others => '0');
        variable pointer : integer := 1;
    begin
        pad_slv(slv'length-1 downto 0) := slv;
        for i in result'length-1 downto 0 loop
            four_bit := pad_slv(i*4+3 downto i*4);
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

begin

    -- Unit Under Test instantiation
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
            ksa_done => ksa_done
        );

    -- Clock generation
    clk_process: process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Main test process
    stim_process: process
    begin
        -- Initial reset
        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        report "=== RC4 Test Start ===" severity note;
        report "Test Vector 1: Key='Key', Plaintext='Plaintext'" severity note;

        -- Set key length
        key_length <= to_unsigned(3, 8);
        wait for clk_period;

        -- Start initialization
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Load key "Key" = 0x4B 0x65 0x79
        wait for clk_period;
        key_in <= x"4B"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"65"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"79"; key_valid <= '1'; wait for clk_period; key_valid <= '0';

        -- Wait for KSA completion
        report "Waiting for KSA completion..." severity note;
        wait until ksa_done = '1';
        wait for clk_period * 10;
        report "KSA completed!" severity note;

        -- Encrypt "Plaintext" = 50 6C 61 69 6E 74 65 78 74
        -- Expected: BB F3 16 E8 D9 40 AF 0A D3
        report "Starting encryption..." severity note;

        -- Byte 0: P -> BB
        wait for clk_period;
        data_in <= x"50"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"BB" then
            report "Byte 0: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xBB)" severity note;
        else
            report "Byte 0: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xBB)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 1: l -> F3
        data_in <= x"6C"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"F3" then
            report "Byte 1: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xF3)" severity note;
        else
            report "Byte 1: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xF3)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 2: a -> 16
        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"16" then
            report "Byte 2: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x16)" severity note;
        else
            report "Byte 2: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x16)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 3: i -> E8
        data_in <= x"69"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"E8" then
            report "Byte 3: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xE8)" severity note;
        else
            report "Byte 3: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xE8)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 4: n -> D9
        data_in <= x"6E"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"D9" then
            report "Byte 4: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xD9)" severity note;
        else
            report "Byte 4: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xD9)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 5: t -> 40
        data_in <= x"74"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"40" then
            report "Byte 5: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x40)" severity note;
        else
            report "Byte 5: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x40)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 6: e -> AF
        data_in <= x"65"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"AF" then
            report "Byte 6: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xAF)" severity note;
        else
            report "Byte 6: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xAF)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 7: x -> 0A
        data_in <= x"78"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"0A" then
            report "Byte 7: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x0A)" severity note;
        else
            report "Byte 7: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x0A)" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 8: t -> D3
        data_in <= x"74"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"D3" then
            report "Byte 8: PASS - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xD3)" severity note;
        else
            report "Byte 8: FAIL - Output: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xD3)" severity warning;
        end if;

        report "=== Test Vector 1 Complete ===" severity note;
        wait for clk_period * 10;

        -----------------------------------------------------------------------
        -- TEST 2: Key="Wiki", Plaintext="pedia"
        -- Expected: 10 21 BF 04 20
        -----------------------------------------------------------------------
        report "=== Test Vector 2: Key='Wiki', Plaintext='pedia' ===" severity note;

        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        key_length <= to_unsigned(4, 8);
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Key "Wiki" = 57 69 6B 69
        wait for clk_period;
        key_in <= x"57"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"69"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"6B"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"69"; key_valid <= '1'; wait for clk_period; key_valid <= '0';

        wait until ksa_done = '1';
        wait for clk_period * 10;

        -- Plaintext "pedia" = 70 65 64 69 61
        -- Expected: 10 21 BF 04 20
        data_in <= x"70"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 0: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x10)" severity note;
        wait for clk_period * 5;

        data_in <= x"65"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 1: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x21)" severity note;
        wait for clk_period * 5;

        data_in <= x"64"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 2: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xBF)" severity note;
        wait for clk_period * 5;

        data_in <= x"69"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 3: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x04)" severity note;
        wait for clk_period * 5;

        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 4: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x20)" severity note;

        report "=== Test Vector 2 Complete ===" severity note;
        wait for clk_period * 10;

        -----------------------------------------------------------------------
        -- TEST 3: Key="Secret", Plaintext="Attack at dawn"
        -- Expected: 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5
        -----------------------------------------------------------------------
        report "=== Test Vector 3: Key='Secret', Plaintext='Attack at dawn' ===" severity note;

        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        key_length <= to_unsigned(6, 8);
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Key "Secret" = 53 65 63 72 65 74
        wait for clk_period;
        key_in <= x"53"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"65"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"63"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"72"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"65"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"74"; key_valid <= '1'; wait for clk_period; key_valid <= '0';

        wait until ksa_done = '1';
        wait for clk_period * 10;

        -- Plaintext "Attack at dawn" = 41 74 74 61 63 6B 20 61 74 20 64 61 77 6E
        -- Expected: 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5
        data_in <= x"41"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 0: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x45)" severity note;
        wait for clk_period * 5;

        data_in <= x"74"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 1: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xA0)" severity note;
        wait for clk_period * 5;

        data_in <= x"74"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 2: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x1F)" severity note;
        wait for clk_period * 5;

        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 3: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x64)" severity note;
        wait for clk_period * 5;

        data_in <= x"63"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 4: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x5F)" severity note;
        wait for clk_period * 5;

        data_in <= x"6B"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 5: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xC3)" severity note;
        wait for clk_period * 5;

        data_in <= x"20"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 6: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x5B)" severity note;
        wait for clk_period * 5;

        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 7: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x38)" severity note;
        wait for clk_period * 5;

        data_in <= x"74"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 8: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x35)" severity note;
        wait for clk_period * 5;

        data_in <= x"20"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 9: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x52)" severity note;
        wait for clk_period * 5;

        data_in <= x"64"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 10: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x54)" severity note;
        wait for clk_period * 5;

        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 11: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x4B)" severity note;
        wait for clk_period * 5;

        data_in <= x"77"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 12: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x9B)" severity note;
        wait for clk_period * 5;

        data_in <= x"6E"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Byte 13: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xF5)" severity note;

        report "=== Test Vector 3 Complete ===" severity note;
        wait for clk_period * 10;

        -----------------------------------------------------------------------
        -- TEST 4: Decryption verification
        -- Decrypt ciphertext from Test 1 back to plaintext
        -- Key="Key", Ciphertext=BB F3 16 E8 D9 40 AF 0A D3 -> "Plaintext"
        -----------------------------------------------------------------------
        report "=== Test Vector 4: DECRYPTION TEST ===" severity note;
        report "Decrypting ciphertext from Test 1 back to plaintext" severity note;

        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        key_length <= to_unsigned(3, 8);
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Load same key "Key" = 0x4B 0x65 0x79
        wait for clk_period;
        key_in <= x"4B"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"65"; key_valid <= '1'; wait for clk_period; key_valid <= '0';
        wait for clk_period;
        key_in <= x"79"; key_valid <= '1'; wait for clk_period; key_valid <= '0';

        wait until ksa_done = '1';
        wait for clk_period * 10;
        report "KSA completed, starting decryption..." severity note;

        -- Decrypt ciphertext BB F3 16 E8 D9 40 AF 0A D3
        -- Expected plaintext: "Plaintext" = 50 6C 61 69 6E 74 65 78 74

        -- Byte 0: BB -> 'P' (0x50)
        wait for clk_period;
        data_in <= x"BB"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"50" then
            report "Byte 0: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'P' (expected: 0x50)" severity note;
        else
            report "Byte 0: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x50 = 'P')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 1: F3 -> 'l' (0x6C)
        data_in <= x"F3"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"6C" then
            report "Byte 1: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'l' (expected: 0x6C)" severity note;
        else
            report "Byte 1: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x6C = 'l')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 2: 16 -> 'a' (0x61)
        data_in <= x"16"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"61" then
            report "Byte 2: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'a' (expected: 0x61)" severity note;
        else
            report "Byte 2: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x61 = 'a')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 3: E8 -> 'i' (0x69)
        data_in <= x"E8"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"69" then
            report "Byte 3: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'i' (expected: 0x69)" severity note;
        else
            report "Byte 3: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x69 = 'i')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 4: D9 -> 'n' (0x6E)
        data_in <= x"D9"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"6E" then
            report "Byte 4: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'n' (expected: 0x6E)" severity note;
        else
            report "Byte 4: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x6E = 'n')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 5: 40 -> 't' (0x74)
        data_in <= x"40"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"74" then
            report "Byte 5: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 't' (expected: 0x74)" severity note;
        else
            report "Byte 5: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x74 = 't')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 6: AF -> 'e' (0x65)
        data_in <= x"AF"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"65" then
            report "Byte 6: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'e' (expected: 0x65)" severity note;
        else
            report "Byte 6: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x65 = 'e')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 7: 0A -> 'x' (0x78)
        data_in <= x"0A"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"78" then
            report "Byte 7: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 'x' (expected: 0x78)" severity note;
        else
            report "Byte 7: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x78 = 'x')" severity warning;
        end if;
        wait for clk_period * 5;

        -- Byte 8: D3 -> 't' (0x74)
        data_in <= x"D3"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        if data_out = x"74" then
            report "Byte 8: PASS - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " = 't' (expected: 0x74)" severity note;
        else
            report "Byte 8: FAIL - Decrypted: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x74 = 't')" severity warning;
        end if;

        report "=== Test Vector 4 Complete ===" severity note;
        report "=== All Tests Complete ===" severity note;

        wait;
    end process;

end Behavioral;
