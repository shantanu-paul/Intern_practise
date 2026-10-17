// Code your testbench here
// or browse Examples
//systemverilog
module tb_chapter4;

    // 1. Declare and Initialize a reg
    reg [15:0] config_reg;
    initial config_reg = 16'hABCD;

    // 2. Connect a wire to a logic signal
    logic data_enable_logic;
    wire data_enable_wire;
    assign data_enable_wire = data_enable_logic;

    // 3. Perform Arithmetic with integer Types
    integer count_start = 50;
    integer count_end = 150;
    integer count_range; // Calculated inside the initial block below

    // 4. Declare and Assign a real Value
    real frequency_GHz = 2.4;

    // 5. Capture Simulation Time in a time Variable
    time event_timestamp;

    // 6. Perform Bitwise AND on logic Vectors
    logic [7:0] pattern = 8'b1011_0101;
    logic [7:0] mask_logic = 8'b1111_0000;
    logic [7:0] masked_pattern; // Assigned below

    // 7. Define and Instantiate a struct
    typedef struct packed { 
        logic [7:0] opcode; 
        logic [23:0] operand; 
    } instruction_t;
    instruction_t current_instruction;

    // 8. Use enum for State Machine States
    typedef enum {STATE_RESET, STATE_WAIT, STATE_PROCESS} control_state_t;
    control_state_t current_control_state = STATE_RESET;

    // 9. Initialize a Packed Array with Literal Values
    // Note: A [1:0][3:0] array has exactly 2 elements of 4 bits each (8 bits total). 
    // To match your literal, we provide 2 hex values (4'h3 and 4'h6).
    logic [1:0][3:0] nibble_matrix = '{4'h3, 4'h6};

    // 10. Iterate Through an Unpacked Array
    int data_values [5] = '{10, 20, 30, 40, 50};

    // --- Simulation & Execution Block ---
    initial begin
        // Let time advance slightly to demonstrate $time capture
        #5; 
        event_timestamp = $time;
        
        // Drive logic signal to see wire reflection
        data_enable_logic = 1'b1;

        // Perform evaluations
        count_range = count_end - count_start;
        masked_pattern = pattern & mask_logic;

        // Assign struct members procedurally
        current_instruction.opcode = 8'h01;
        current_instruction.operand = 24'hABC_123;

        // Display results to the console
        $display("--- SystemVerilog Syntaxes Demonstration ---");
        $display("1. config_reg       = %h", config_reg);
        $display("2. data_enable_wire = %b (reflects logic: %b)", data_enable_wire, data_enable_logic);
        $display("3. count_range      = %0d", count_range);
        $display("4. frequency_GHz    = %0f", frequency_GHz);
        $display("5. event_timestamp  = %0t", event_timestamp);
        $display("6. masked_pattern   = %b", masked_pattern);
        $display("7. struct opcode    = %h, operand = %h", current_instruction.opcode, current_instruction.operand);
        $display("8. control_state    = %s (%0d)", current_control_state.name(), current_control_state);
        $display("9. nibble_matrix    = %h", nibble_matrix);
        
        $display("\n10. Unpacked Array Elements:");
        foreach (data_values[i]) begin
            $display("    Element [%0d] = %0d", i, data_values[i]);
        end
        
        $finish; // End simulation
    end

endmodule