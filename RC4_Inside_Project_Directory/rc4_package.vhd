-- RC4 Package: Типи та константи
-- Автор: CleverBot
-- Проект: Реалізація RC4 шифру

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package rc4_package is
    -- Константи
    constant SBOX_SIZE : integer := 256;
    constant MAX_KEY_LEN : integer := 256;
    
    -- Типи для S-box
    type sbox_type is array (0 to SBOX_SIZE-1) of unsigned(7 downto 0);
    
    -- Типи для ключа
    type key_type is array (0 to MAX_KEY_LEN-1) of unsigned(7 downto 0);
    
    -- Стани FSM
    type state_type is (
        IDLE,           -- Очікування
        INIT_SBOX,      -- Ініціалізація S-box (S[i] = i)
        KSA_PROCESS,    -- Key-Scheduling Algorithm
        PRGA_READY,     -- Готовність до шифрування
        PRGA_I_UPDATE,  -- Оновлення i
        PRGA_J_UPDATE,  -- Оновлення j
        PRGA_SWAP,      -- Обмін S[i] та S[j]
        PRGA_OUTPUT,    -- Генерація вихідного байту
        DONE            -- Завершення
    );
    
end package rc4_package;

package body rc4_package is
end package body rc4_package;
