library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_parser is
    port (
        clk : in std_logic;
        rst: in std_logic;
        
        in_byte : in std_logic_vector(7 downto 0);
        in_valid : in std_logic;
        in_sof : in std_logic;
        in_eof : in std_logic;
        in_err : in std_logic;
        
        dst_mac : out std_logic_vector(47 downto 0);
        src_mac : out std_logic_vector(47 downto 0);
        q_tag : out std_logic_vector(31 downto 0);
        ethertype : out std_logic_vector(15 downto 0);
        
        payload_byte : out std_logic_vector(7 downto 0);
        payload_valid : out std_logic;
        
        frame_start : out std_logic;
        frame_done : out std_logic;
        frame_error : out std_logic
        );
end entity;

architecture rtl of frame_parser is
    type state_t is (Idle, dst, src, type_or_tpid, qtag_tci, etherntype, payload);
    signal state : state_t := idle;
    signal dst_mac_r : std_logic_vector(47 downto 0) := (others => '0');
    signal src_mac_r : std_logic_vector(47 downto 0) := (others => '0');
    signal ethertype_r : std_logic_vector(15 downto 0) := (others => '0');
    signal q_tag_r : std_logic_vector(31 downto 0) := (others => '0');
    signal vlan_present : std_logic := '0';
    signal idx : unsigned(2 downto 0) := (others => '0');
    
begin
    dst_mac <= dst_mac_r;
    src_mac <= src_mac_r;
    ethertype <= ethertype_r;
    q_tag <= q_tag_r;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                state <= IDLE;
                idx <= (others => '0');
                dst_mac_r <= (others => '0');
                src_mac_r <= (others => '0');
                ethertype_r <= (others => '0');
                q_tag_r <= (others => '0');
                vlan_present <= '0';
                payload_byte <= (others => '0');
                payload_valid <= '0';
                frame_start <= '0';
                frame_done <= '0';
                frame_error <= '0';
                
                else
                    payload_valid <= '0';
                    frame_start <= '0';
                    frame_done <= '0';
                    
                    if ((in_valid = '1') AND (in_sof = '1')) then
                        frame_error <= '0';
                        q_tag_r <= (others => '0');
                        vlan_present <= '0';
                    end if;  
                    if (in_valid = '1') then
                        if (in_err = '1') then
                        frame_error <= '1';
                        end if;
                        
                    case state is
                        when idle =>
                            if in_sof = '1' then
                                frame_start <= '1';
                                state <= DST;
                                idx <= (others => '0');
                                dst_mac_r(47 downto 40) <= in_byte;
                                
                                if (in_eof = '1') then
                                    frame_error <= '1';
                                    frame_done <= '1';
                                    state <= IDLE;
                                    idx <= (others => '0');
                                else 
                                    idx <= to_unsigned(1, idx'length);
                                end if;
                            end if;
                        when dst =>
                            case to_integer(idx) is
                                when 1 => dst_mac_r(39 downto 32) <= in_byte;
                                when 2 => dst_mac_r(31 downto 24) <= in_byte;
                                when 3 => dst_mac_r(23 downto 16) <= in_byte;
                                when 4 => dst_mac_r(15 downto 8) <= in_byte;
                                when 5 => dst_mac_r(7 downto 0) <= in_byte;
                                when others => null;
                            end case;
                            if (in_eof = '1') then
                                frame_error <= '1';
                                frame_done <= '1';
                                state <= idle;
                                idx   <= (others => '0');
                            else 
                                if (idx = to_unsigned(5, idx'length)) then
                                    state <= SRC;
                                    idx <= (others => '0');
                                else 
                                    idx <= idx + 1;
                                end if;
                            end if;
                        when src =>
                            case to_integer(idx) is
                                when 0 => src_mac_r(47 downto 40) <= in_byte;
                                when 1 => src_mac_r(39 downto 32) <= in_byte;
                                when 2 => src_mac_r(31 downto 24) <= in_byte;
                                when 3 => src_mac_r(23 downto 16) <= in_byte;
                                when 4 => src_mac_r(15 downto  8) <= in_byte;
                                when 5 => src_mac_r( 7 downto  0) <= in_byte;
                                when others => null;
                            end case;
                            if (in_eof = '1') then
                                frame_error <= '1';
                                frame_done <= '1';
                                state <= idle;
                                idx   <= (others => '0');
                            else
                                if (idx = to_unsigned(5, idx'length)) then
                                    state <= type_or_tpid;
                                    idx <= (others => '0');
                                else 
                                    idx <= idx + 1;
                                end if;
                            end if;
                        when type_or_tpid =>
                            case to_integer(idx) is
                                when 0 => 
                                    q_tag_r(31 downto 24) <= in_byte;
                                    idx <= to_unsigned(1, idx'length);
                                    if (in_eof = '1') then
                                        frame_error <= '1';
                                        frame_done <= '1';
                                        state <= idle;
                                        idx <= (others => '0');
                                    end if;                                                                  
                                when 1 => 
                                    q_tag_r(23 downto 16) <= in_byte;
                                    if (in_eof = '1') then
                                        frame_error <= '1';
                                        frame_done <= '1';
                                        state <= idle;
                                        idx <= (others => '0');
                                    else
                                        if ((q_tag_r(31 downto 24) & in_byte) = x"8100") then
                                            vlan_present <= '1';
                                            state <= qtag_tci;
                                            idx <= (others => '0');
                                        else 
                                            vlan_present <= '0';
                                            ethertype_r <= q_tag_r(31 downto 24) & in_byte;
                                            state <= payload;
                                            idx <= (others => '0');
                                       end if; 
                                    end if;
                                when others =>
                                    null;
                            end case;                           
                        when qtag_tci => 
                            case to_integer(idx) is
                                when 0 => 
                                    q_tag_r(15 downto 8) <= in_byte;
                                    idx <= to_unsigned(1, idx'length);
                                    if (in_eof = '1') then
                                        frame_error <= '1';
                                        frame_done <= '1';
                                        state <= idle;
                                        idx <= (others => '0');
                                    end if;    
                                when 1 => 
                                    q_tag_r(7 downto 0) <= in_byte;
                                    if (in_eof = '1') then
                                        frame_error <= '1';
                                        frame_done <= '1';
                                        state <= idle;
                                        idx <= (others => '0');
                                    else
                                        state <= etherntype;
                                        idx <= (others => '0');
                                    end if;
                                when others =>
                                    null;
                            end case;
                        when etherntype =>
                            if idx = to_unsigned(0, idx'length) then
                                ethertype_r(15 downto 8) <= in_byte;
                                idx <= to_unsigned(1, idx'length);
                                if (in_eof = '1') then
                                    frame_error <= '1';
                                    frame_done <= '1';
                                    state <= idle;
                                    idx <= (others => '0');
                                end if;
                            else 
                                ethertype_r(7 downto 0) <= in_byte;
                                if (in_eof = '1') then
                                    frame_done <= '1';
                                    state <= idle;
                                else 
                                    state <= payload;
                                end if;
                            end if;
                        when payload =>
                            payload_byte <= in_byte;
                            payload_valid <= '1';
                            if (in_eof = '1') then
                                frame_done <= '1';
                                state <= idle;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;                                                                                                   