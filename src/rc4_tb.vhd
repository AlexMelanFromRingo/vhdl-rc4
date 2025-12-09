--------------------------------------------------------------------------------
-- RC4 Testbench (OPTIMIZED)
-- Compatible with Xilinx ISE 8.1i (VHDL-93)
--
-- TIMING: KSA ~1024 cycles = ~10240 ns, Total test ~15000 ns per test
-- Run: "run 40 us" or just let it complete automatically
--
-- Test Vectors from RFC 6229:
--   Key="Key", Plain="Plaintext" -> Cipher=BB F3 16 E8 D9 40 AF 0A D3
--   Key="Wiki", Plain="pedia"    -> Cipher=10 21 BF 04 20
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.rc4_pkg.ALL;

entity rc4_tb is
end entity rc4_tb;

architecture sim of rc4_tb is
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals (all initialized)
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal start        : std_logic := '0';
    signal key_len      : std_logic_vector(7 downto 0) := x"00";
    signal key_data     : byte_t := x"00";
    signal key_addr     : std_logic_vector(7 downto 0);
    signal data_in      : byte_t := x"00";
    signal data_valid   : std_logic := '0';
    signal data_out     : byte_t;
    signal data_ready   : std_logic;
    signal busy         : std_logic;
    signal ready        : std_logic;

    -- Test data
    type key1_t is array (0 to 2) of byte_t;
    constant KEY1 : key1_t := (x"4B", x"65", x"79");  -- "Key"
    constant KEY1_LEN : integer := 3;

    type plain1_t is array (0 to 8) of byte_t;
    constant PLAIN1 : plain1_t := (x"50", x"6C", x"61", x"69", x"6E", x"74", x"65", x"78", x"74");
    constant CIPHER1 : plain1_t := (x"BB", x"F3", x"16", x"E8", x"D9", x"40", x"AF", x"0A", x"D3");

    type key2_t is array (0 to 3) of byte_t;
    constant KEY2 : key2_t := (x"57", x"69", x"6B", x"69");  -- "Wiki"
    constant KEY2_LEN : integer := 4;

    type plain2_t is array (0 to 4) of byte_t;
    constant PLAIN2 : plain2_t := (x"70", x"65", x"64", x"69", x"61");  -- "pedia"
    constant CIPHER2 : plain2_t := (x"10", x"21", x"BF", x"04", x"20");

    signal test_done    : boolean := false;
    signal current_test : integer := 0;

begin

    -- Clock (stops when test_done)
    clk <= not clk after CLK_PERIOD/2 when not test_done else '0';

    -- DUT
    dut : entity work.rc4
        port map (
            clk => clk, rst => rst, start => start,
            key_len => key_len, key_data => key_data, key_addr => key_addr,
            data_in => data_in, data_valid => data_valid,
            data_out => data_out, data_ready => data_ready,
            busy => busy, ready => ready
        );

    -- Key ROM (directly uses key_addr)
    process(key_addr, current_test)
        variable idx : integer;
    begin
        -- Safe conversion
        if is_x(key_addr) then
            idx := 0;
        else
            idx := conv_integer(key_addr);
        end if;

        if current_test = 1 then
            if idx < KEY1_LEN then
                key_data <= KEY1(idx);
            else
                key_data <= x"00";
            end if;
        elsif current_test = 2 then
            if idx < KEY2_LEN then
                key_data <= KEY2(idx);
            else
                key_data <= x"00";
            end if;
        else
            key_data <= x"00";
        end if;
    end process;

    -- Main test
    process
        variable pass1, pass2 : integer := 0;
        variable fail1, fail2 : integer := 0;
    begin
        report "==========================================================";
        report "RC4 TESTBENCH - Optimized Version";
        report "KSA: ~1024 cycles (~10 us), Total: ~15 us per test";
        report "==========================================================";

        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        --------------------------------------------------------------------
        -- TEST 1
        --------------------------------------------------------------------
        report "=== TEST 1: Key='Key', Plaintext='Plaintext' ===";
        report "    Expected ciphertext: BB F3 16 E8 D9 40 AF 0A D3";

        current_test <= 1;
        wait for CLK_PERIOD;
        key_len <= conv_std_logic_vector(KEY1_LEN, 8);
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        report "    KSA started, waiting for completion...";
        wait until ready = '1';
        report "    KSA complete! Encrypting...";

        for i in 0 to 8 loop
            data_in <= PLAIN1(i);
            data_valid <= '1';
            wait for CLK_PERIOD;
            data_valid <= '0';
            wait until data_ready = '1';

            if data_out = CIPHER1(i) then
                report "    [" & integer'image(i) & "] " & byte_to_hex(PLAIN1(i)) &
                       " -> " & byte_to_hex(data_out) & " = " & byte_to_hex(CIPHER1(i)) & " OK";
                pass1 := pass1 + 1;
            else
                report "    [" & integer'image(i) & "] " & byte_to_hex(PLAIN1(i)) &
                       " -> " & byte_to_hex(data_out) & " != " & byte_to_hex(CIPHER1(i)) & " FAIL!" severity error;
                fail1 := fail1 + 1;
            end if;
            wait for CLK_PERIOD;
        end loop;

        report "    Test 1 Result: " & integer'image(pass1) & " PASS, " & integer'image(fail1) & " FAIL";

        -- Reset for test 2
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        --------------------------------------------------------------------
        -- TEST 2
        --------------------------------------------------------------------
        report "=== TEST 2: Key='Wiki', Plaintext='pedia' ===";
        report "    Expected ciphertext: 10 21 BF 04 20";

        current_test <= 2;
        wait for CLK_PERIOD;
        key_len <= conv_std_logic_vector(KEY2_LEN, 8);
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        report "    KSA started, waiting for completion...";
        wait until ready = '1';
        report "    KSA complete! Encrypting...";

        for i in 0 to 4 loop
            data_in <= PLAIN2(i);
            data_valid <= '1';
            wait for CLK_PERIOD;
            data_valid <= '0';
            wait until data_ready = '1';

            if data_out = CIPHER2(i) then
                report "    [" & integer'image(i) & "] " & byte_to_hex(PLAIN2(i)) &
                       " -> " & byte_to_hex(data_out) & " = " & byte_to_hex(CIPHER2(i)) & " OK";
                pass2 := pass2 + 1;
            else
                report "    [" & integer'image(i) & "] " & byte_to_hex(PLAIN2(i)) &
                       " -> " & byte_to_hex(data_out) & " != " & byte_to_hex(CIPHER2(i)) & " FAIL!" severity error;
                fail2 := fail2 + 1;
            end if;
            wait for CLK_PERIOD;
        end loop;

        report "    Test 2 Result: " & integer'image(pass2) & " PASS, " & integer'image(fail2) & " FAIL";

        --------------------------------------------------------------------
        -- FINAL
        --------------------------------------------------------------------
        report "==========================================================";
        if (fail1 = 0) and (fail2 = 0) then
            report ">>> ALL TESTS PASSED! RC4 is working correctly. <<<";
        else
            report ">>> TESTS FAILED! Total failures: " & integer'image(fail1 + fail2) & " <<<" severity error;
        end if;
        report "==========================================================";

        test_done <= true;
        wait;
    end process;

end architecture sim;
