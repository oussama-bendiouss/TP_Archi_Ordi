library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.PKG.all;


entity CPU_PC is
    generic(
        mutant: integer := 0
    );
    Port (
        -- Clock/Reset
        clk    : in  std_logic ;
        rst    : in  std_logic ;

        -- Interface PC to PO
        cmd    : out PO_cmd ;
        status : in  PO_status
    );
end entity;

architecture RTL of CPU_PC is
    type State_type is (
        S_Error,
        S_Init,
        S_Pre_Fetch,
        S_Fetch,
        S_Decode,
        S_LUI,
        S_ADDI,
	S_ADD,
	S_SLL,
	
	S_SUB,
	
	S_AND,
	S_OR,
	S_ORI,
	S_XOR,
	S_ANDI,
	S_XORI
	
    );

    signal state_d, state_q : State_type;
    signal cmd_cs : PO_cs_cmd;


    function arith_sel (IR : unsigned( 31 downto 0 ))
        return ALU_op_type is
        variable res : ALU_op_type;
    begin
        if IR(30) = '0' or IR(5) = '0' then
            res := ALU_plus;
        else
            res := ALU_minus;
        end if;
        return res;
    end arith_sel;

    function logical_sel (IR : unsigned( 31 downto 0 ))
        return LOGICAL_op_type is
        variable res : LOGICAL_op_type;
    begin
        if IR(12) = '1' then
            res := LOGICAL_and;
        else
            if IR(13) = '1' then
                res := LOGICAL_or;
            else
                res := LOGICAL_xor;
            end if;
        end if;
        return res;
    end logical_sel;

    function shifter_sel (IR : unsigned( 31 downto 0 ))
        return SHIFTER_op_type is
        variable res : SHIFTER_op_type;
    begin
        res := SHIFT_ll;
        if IR(14) = '1' then
            if IR(30) = '1' then
                res := SHIFT_ra;
            else
                res := SHIFT_rl;
            end if;
        end if;
        return res;
    end shifter_sel;

begin

    cmd.cs <= cmd_cs;

    FSM_synchrone : process(clk)
    begin
        if clk'event and clk='1' then
            if rst='1' then
                state_q <= S_Init;
            else
                state_q <= state_d;
            end if;
        end if;
    end process FSM_synchrone;

    FSM_comb : process (state_q, status)
    begin

        -- Valeurs par d??faut de cmd ?? d??finir selon les pr??f??rences de chacun
        cmd.rst               <= 'U';
        cmd.ALU_op            <= UNDEFINED;
        cmd.LOGICAL_op        <= UNDEFINED;
        cmd.ALU_Y_sel         <= ALU_Y_immI;

        cmd.SHIFTER_op        <= UNDEFINED;
        cmd.SHIFTER_Y_sel     <= UNDEFINED;

        cmd.RF_we             <= '0';
        cmd.RF_SIZE_sel       <= UNDEFINED;
        cmd.RF_SIGN_enable    <= 'U';
        cmd.DATA_sel          <= DATA_from_pc;


        cmd.PC_we             <= '0';
        cmd.PC_sel            <= PC_from_alu;

        cmd.PC_X_sel          <= PC_X_cst_x00;
        cmd.PC_Y_sel          <= PC_Y_immU;


        cmd.TO_PC_Y_sel       <= TO_PC_Y_cst_x04;

        cmd.AD_we             <= '0';
        cmd.AD_Y_sel          <= AD_Y_immI;

        cmd.IR_we             <= 'U';

        cmd.ADDR_sel          <= ADDR_from_pc;
        cmd.mem_we            <= '0';
        cmd.mem_ce            <= '0';

        cmd_cs.CSR_we            <= UNDEFINED;

        cmd_cs.TO_CSR_sel        <= UNDEFINED;
        cmd_cs.CSR_sel           <= UNDEFINED;
        cmd_cs.MEPC_sel          <= UNDEFINED;

        cmd_cs.MSTATUS_mie_set   <= 'U';
        cmd_cs.MSTATUS_mie_reset <= 'U';

        cmd_cs.CSR_WRITE_mode    <= UNDEFINED;

        state_d <= state_q;

        case state_q is
            when S_Error =>
                state_d <= S_Error;

            when S_Init =>
                -- PC <- RESET_VECTOR
                cmd.PC_we <= '1';
                cmd.PC_sel <= PC_rstvec;
                state_d <= S_Pre_Fetch;

            when S_Pre_Fetch =>
                -- mem[PC]
                cmd.mem_ce <= '1';
                state_d <= S_Fetch;

            when S_Fetch =>
                -- IR <- mem_datain
                cmd.IR_we <= '1';
                state_d <= S_Decode;

            when S_Decode =>
                 cmd.TO_PC_Y_sel <= TO_PC_Y_cst_x04;
 	         cmd.PC_sel <= PC_from_pc;
                 cmd.PC_we <= '1';
                 state_d <= S_Init;
-- On peut aussi utiliser un case, ...
-- et ne pas le faire juste pour les branchements et auipc
         if status.IR(6 downto 0) = "0110111" then
            state_d <= S_LUI;
            elsif status.IR(6 downto 0) = "0010011" and status.IR(14 downto 12) = "000" then
                  state_d <= S_ADDI;
            elsif status.IR(6 downto 0) = "0110011"  and status.IR(14 downto 12) = "000" and status.IR(31 downto 25) = "0000000" then
		    state_d <= S_ADD;
           elsif status.IR(6 downto 0) = "0110011"  and status.IR(31 downto 25) = "0100000" and status.IR(14 downto 12) = "000" then
		    state_d <= S_SUB;
            elsif status.IR(6 downto 0) = "0110011" and status.IR(14 downto 12) = "111" then 
		    state_d <= S_AND;
	    elsif status.IR(6 downto 0) = "0010011" and status.IR(14 downto 12) = "111" then 
		    state_d <= S_ANDI;
	    elsif status.IR(6 downto 0) = "0110011" and status.IR(31 downto 25) = "0000000" and status.IR(14 downto 12) = "110" then 
		    state_d <= S_OR;
	    elsif status.IR(6 downto 0) = "0010011" and status.IR(14 downto 12) = "110" then 
		    state_d <= S_ORI;
	    elsif status.IR(6 downto 0) = "0110011" and status.IR(14 downto 12) = "100" then 
		    state_d <= S_XOR;
	    elsif status.IR(6 downto 0) = "0010011" and status.IR(14 downto 12) = "100" then 
		    state_d <= S_XORI;
	 else
            state_d <= S_Error; 
-- Pour d ??etecter les rat ??es du d ??ecodage
         end if;
      
                -- D??codage effectif des instructions,
                -- ?? compl??ter par vos soins

---------- Instructions avec immediat de type U ----------
        when S_LUI =>
     -- rd <- ImmU + 0
         cmd.PC_X_sel <= PC_X_cst_x00;
         cmd.PC_Y_sel <= PC_Y_immU;
	 cmd.RF_we <= '1';
	 cmd.DATA_sel <= DATA_from_pc;-- lecture mem[PC]
	 cmd.ADDR_sel <= ADDR_from_pc;
	 cmd.mem_ce <= '1';
	 cmd.mem_we <= '0';-- next state
         state_d <= S_Fetch;
        when S_ADDI =>
     -- rd <- ImmU + 0
         cmd.ALU_Y_sel <= ALU_Y_immI;
         cmd.ALU_op <= ALU_plus;
        
         
	 cmd.RF_we <= '1';
	 cmd.DATA_sel <= DATA_from_alu;-- lecture mem[PC]
	 cmd.ADDR_sel <= ADDR_from_pc;
	 cmd.mem_ce <= '1';
	 cmd.mem_we <= '0';-- next state
         state_d <= S_Fetch;
        when S_ADD =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.ALU_op <= ALU_plus;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_alu;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;

---------- Instructions arithm??tiques et logiques ----------
           when S_ADD =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.ALU_op <= ALU_plus;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_alu;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_SUB =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.ALU_op <= ALU_minus;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_alu;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
            when S_AND =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.LOGICAL_op <= LOGICAL_and;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_OR =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.LOGICAL_op <= LOGICAL_or;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_XOR =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_rf_rs2;
		cmd.LOGICAL_op <= LOGICAL_xor;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_XORI =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_immI;
		cmd.LOGICAL_op <= LOGICAL_xor;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_ORI =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_immI;
		cmd.LOGICAL_op <= LOGICAL_or;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
	    when S_ANDI =>
		-- rd <- rs1 + rs2
		cmd.ALU_Y_SEL <= ALU_Y_immI;
		cmd.LOGICAL_op <= LOGICAL_and;
		cmd.RF_we <= '1';
		cmd.DATA_sel <= DATA_from_logical;
		-- lecture mem[PC]
		cmd.ADDR_sel <= ADDR_from_pc;
		cmd.mem_ce <= '1';
		cmd.mem_we <= '0';
		--next state
		state_d <= S_Fetch;
---------- Instructions de saut ----------

---------- Instructions de chargement ?? partir de la m??moire ----------

---------- Instructions de sauvegarde en m??moire ----------

---------- Instructions d'acc??s aux CSR ----------

            when others => null;
        end case;

    end process FSM_comb;

end architecture;
