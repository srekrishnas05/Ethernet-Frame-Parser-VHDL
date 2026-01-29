library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity crc32 is
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        in_byte : in std_logic_vector(7 downto 0);
        in_valid : in std_logic;
        in_sof : in std_logic;
        in_eof : in std_logic;
        
        crc_ok : out std_logic;
        crc_bad : out std_logic;
        
        crc_final : out std_logic_vector(31 downto 0);
        fcs_recv : out std_logic_vector(31 downto 0)
        );
end crc32;

architecture rtl of crc32 is
    function crc32next(crc_in : std_logic_vector(31 downto 0);
        d : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable crc : unsigned(31 downto 0) := unsigned(crc_in);
        variable b : unsigned(7 downto 0) := unsigned(d);
    begin
    crc := crc XOR resize(b, 32);
    for i in 0 to 7 loop
        if (crc(0)  = '1') then
            crc := shift_right(crc, 1) xor x"EDB88320";
        else 
            crc := shift_right(crc, 1);
        end if;
    end loop;
    return std_logic_vector(crc);    
    end function;
    
    signal crc_reg : std_logic_vector(31 downto 0) := (others => '1');
    signal tail0, tail1, tail2, tail3 : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_count : unsigned(15 downto 0) := (others => '0');
    signal crc_ok_r, crc_bad_r : std_logic := '0';
    signal crc_final_r : std_logic_vector(31 downto 0) := (others => '0');
    signal fcs_recv_r : std_logic_vector(31 downto 0) := (others => '0');
    
    begin
        crc_ok <= crc_ok_r;
        crc_bad <= crc_bad_r;
        crc_final <= crc_final_r;
        fcs_recv <= fcs_recv_r;
        
        process(clk)
            variable fcs_le : std_logic_vector(31 downto 0);
            variable final_crc : std_logic_vector(31 downto 0);
            variable crc_next_val : std_logic_vector(31 downto 0);
            variable t0, t1, t2, t3 : std_logic_vector(7 downto 0);
        begin   
            if (rising_edge(clk)) then
                if (rst = '1') then
                    crc_reg <= (others => '1');
                    tail0 <= (others => '0'); tail1 <= (others => '0'); tail2 <= (others => '0'); tail3 <= (others => '0');
                    byte_count <= (others => '0');
                    crc_ok_r <= '0';
                    crc_bad_r <= '0';
                    crc_final_r <= (others => '0');
                    fcs_recv_r <= (others => '0');
                else 
                    crc_ok_r <= '0';
                    crc_bad_r <= '0';
                    
                    if (in_valid = '1') then
                        crc_next_val := crc_reg;
                        if (in_sof = '1') then
                            crc_next_val := (others => '1');
                            crc_reg <= (others => '1');
                            byte_count <= (others => '0');
                            tail0 <= (others => '0'); tail1 <= (others => '0'); tail2 <= (others => '0'); tail3 <= (others => '0');
                        end if;
                    t3 := tail2;
                    t2 := tail1;
                    t1 := tail0;
                    t0 := in_byte;    
                    if ((in_sof = '0') and (byte_count >= 4)) then
                        crc_next_val := crc32next(crc_next_val, tail3);
                        crc_reg <= crc_next_val;
                    end if;
                    tail3 <= t3;
                    tail2 <= t2;
                    tail1 <= t1;
                    tail0 <= t0;
                    byte_count <= byte_count + 1;
                    if (in_eof = '1') then

                    fcs_le(7 downto 0) := t3;
                    fcs_le(15 downto 8) := t2;
                    fcs_le(23 downto 16) := t1;                                 
                    fcs_le(31 downto 24) := t0;
                    final_crc := not crc_next_val;
                    crc_final_r <= final_crc;
                    fcs_recv_r <= fcs_le;
                        if (final_crc = fcs_le) then
                            crc_ok_r <= '1';
                        else
                            crc_bad_r <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;                    
end architecture;
