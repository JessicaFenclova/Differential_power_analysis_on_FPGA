library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

 entity ctrl_aes is
  port (
    i_clk         : in std_logic;
    i_rst         : in std_logic;
    i_rd_req      : in std_logic;
    i_data        : in std_logic_vector(7 downto 0);
    i_eval_result : in std_logic;
    i_wr_ack      : in std_logic;
    o_rd_ack      : out std_logic; -- do i want another signal out ready
    o_wr_req      : out std_logic;
    o_lsb         : out std_logic_vector(4 downto 0);
    o_msb         : out std_logic_vector(4 downto 0);
    o_lsb_en      : out std_logic;
    o_msb_en      : out std_logic;
    o_data        : out std_logic    
  
    );
 end ctrl_aes;
 
 architecture rtl of ctrl_aes is  
    
 
 type ctrl_state_type  is (wait_uart,fetch,exe_cmd,eval_res,send_res);   --state type for the controll state machine
 type active_sbox_type is (ready1, set_en, done1);                       --state type for the state machine for activating and deactivating sboxes
 type set_lfsr_type    is (ready2, set_lsb, set_msb, done2);             --state type for the state machine for setting the lfsr pseudo random generator
 
 
    signal state       : ctrl_state_type;
    signal  cmd_reg    : std_logic_vector(2 downto 0) := "000";
    signal param_reg   : std_logic_vector(4 downto 0) := "00000";
    --signal cmd_done    : std_logic :='0';  --cmd_done is the or of all cmd_done signals from state machines
    signal start_cmd   : std_logic :='0';
    
    signal state1_sbox    : active_sbox_type;
    signal en_sbox   : std_logic;
    signal cmd_done1 : std_logic;
    
    signal state2_lfsr    : set_lfsr_type;
    --signal lsb       : std_logic_vector(4 downto 0);
    --signal msb       : std_logic_vector(4 downto 0);
    signal cmd_done2 : std_logic;
    --signal random_data : std_logic_vector(7 downto 0);
    
 
       
  begin
  
    p_wait: process(i_clk, i_rst)    -- process for state machine controlling the aes measurement, data generation and sbox activation, deactivation
      begin
      
        if i_rst = '0' then
           state <= wait_uart;
           --start_cmd<='0';
           param_reg <="00000";
           cmd_reg <="000";
           --o_wr_req<='0';
           --o_rd_ack<='0';
           o_data <='0';
        elsif i_clk'event and (i_clk='1') then
               
            
            case state is
              when wait_uart =>
                 if (i_rd_req='1') then
                   state <= fetch;
                  --enable <='1';
                  else
                    state<=wait_uart;
                 end if; 
              when fetch =>
                 if (i_rd_req='1') then  
                   cmd_reg<=i_data(2 downto 0);
                   param_reg<=i_data(7 downto 3);
                   state <= exe_cmd;
                 else
                   state<=fetch;
                 end if;
              when exe_cmd =>
                 if (i_eval_result='1') then    --if change in eval result, the input from sbox, or just act as if the data from the xor are there all the time
                   state <= eval_res;
                 elsif (cmd_done1='1') or (cmd_done2='1') then
                   state <= wait_uart;
                 else
                   state<=exe_cmd;
                 end if;
              when eval_res =>
                 o_data <= i_eval_result;
                 if (i_wr_ack='1') then
                   state <= wait_uart;
                 else
                   state<=eval_res;
                 end if;
              when others =>
                   state <= wait_uart;
            end case;
            --testing 
            
                                           
            
                     
        end if;
    end process p_wait;
    
    
    p_state: process(state)
      begin
        case state is
            when wait_uart =>
                o_rd_ack <= '0';
                o_wr_req<='0'; 
            when fetch =>
                o_rd_ack <='1';
                start_cmd<='0';  
            when exe_cmd =>
                start_cmd <='1';
                o_rd_ack <= '0';
            when eval_res =>
               o_wr_req <='1';
               start_cmd<='0';
               --o_data <= i_eval_result;    --just for now, dont have the block that would xor the sbox outputs                
            when others =>
                    o_rd_ack <= '0';
                    o_wr_req<='0';
                    
        end case;

    end process p_state;
    
    p_ready1: process(i_clk, i_rst)   --process for the statemachine that activates/deactivvates sboxes
      begin
        if i_rst = '0' then
           state1_sbox <= ready1;

        elsif i_clk'event and (i_clk='1') then
            case state1_sbox is
              when ready1 =>
                 if (start_cmd='1') and (cmd_reg="010") then
                   state1_sbox <= set_en;
                  else
                    state1_sbox <=ready1;
                 end if; 
              when set_en =>
                 --if (i_rd_req='1') then  
                   state1_sbox <= done1;
                 --else
                   --state1<=;
                 --end if;
              
              when others =>
                   state1_sbox <= ready1;
            end case;
        end if; 
    end process p_ready1;
    
    p_state1: process(state1_sbox)
      begin
        case state1_sbox is
            when ready1 =>
                en_sbox <= '0';
                cmd_done1 <='0'; 
            when set_en =>
                en_sbox <='1';  
            when done1 =>
               cmd_done1 <='1';                
            when others =>
                    en_sbox <= '0';
                    
        end case;

    end process p_state1;
    
    
    p_ready2: process(i_clk, i_rst)     --process for state machine that sets the LFSR bits and generates random data for aes
      begin
         
        if i_rst = '0' then
           state2_lfsr <= ready2;
           --o_lsb<="00000";
           --o_msb<="00000";
        elsif i_clk'event and (i_clk='1') then
            case state2_lfsr is
              when ready2 =>
                
                 if (start_cmd='1') and (cmd_reg="000") then
                   state2_lfsr <= set_lsb;
                 elsif (start_cmd='1') and (cmd_reg="001") then
                   state2_lfsr <= set_msb;
                 else
                    state2_lfsr<=ready2;
                 end if; 
              when set_lsb =>
                 --if (i_rd_req='1') then  
                   state2_lfsr <= done2;
                 --else
                   --state1<=;
                 --end if;
              when set_msb =>  
                   state2_lfsr <= done2;           
              when others =>
                   state2_lfsr <= ready2;
            end case;
        end if; 
    end process p_ready2;
    
    p_state2: process(state2_lfsr)
      begin
         --o_lsb<="00000";
         --o_msb<="00000";
        case state2_lfsr is
            when ready2 =>
                o_lsb<="00000";
                o_msb<="00000";
                o_lsb_en<='0';
                o_msb_en<='0';
                cmd_done2 <= '0';
            when set_lsb =>
                o_lsb <= param_reg;
                o_lsb_en <='1';  
            when set_msb =>
                o_msb <= param_reg;
                o_lsb_en <='1';
            when done2 =>
               cmd_done2 <='1';               
            when others =>
                cmd_done2 <= '0';
                    
         end case;

    end process p_state2;
    
    

    
    
    
    
        
 end architecture rtl;