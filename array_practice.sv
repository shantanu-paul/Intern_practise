module tb;

  initial begin
    $display("\n========================================");
    $display("  SystemVerilog Array Concepts Practice ");
    $display("========================================\n");

    // -----------------------------------------------------------
    // Exercise 1: Packed Array Initialization
    // -----------------------------------------------------------
    $display("--- [Exercise 1] Packed Array ---");
    begin
      automatic logic [11:0] config_bits = 12'hA3C;
      $display("config_bits (hex): 12'h%0h", config_bits);
      $display("config_bits (bin): 12'b%012b", config_bits);
    end

    // -----------------------------------------------------------
    // Exercise 2: Unpacked Array of Strings
    // -----------------------------------------------------------
    $display("\n--- [Exercise 2] Unpacked Array of Strings ---");
    begin
      automatic string name_list [4] = '{"Alice", "Bob", "Charlie", "Dana"};
      foreach (name_list[i]) begin
        $display("name_list[%0d] = %s", i, name_list[i]);
      end
    end

    // -----------------------------------------------------------
    // Exercise 3: Fixed-Size Array Summation
    // -----------------------------------------------------------
    $display("\n--- [Exercise 3] Fixed-Size Array Summation ---");
    begin
      automatic int value_array [5] = '{10, 20, 30, 40, 50};
      $display("Array values: %p", value_array);
      $display("Sum of array elements: %0d", value_array.sum());
    end

    // -----------------------------------------------------------
    // Exercise 4: Dynamic Array with Even Numbers
    // -----------------------------------------------------------
    $display("\n--- [Exercise 4] Dynamic Array with Even Numbers ---");
    begin
      int even_numbers [];
      even_numbers = new[8];
      foreach (even_numbers[i]) begin
        even_numbers[i] = i * 2;
      end
      $display("even_numbers size: %0d", even_numbers.size());
      $display("even_numbers content: %p", even_numbers);
    end

    // -----------------------------------------------------------
    // Exercise 5: Associative Array for Age Lookup
    // -----------------------------------------------------------
    $display("\n--- [Exercise 5] Associative Array (Age Lookup) ---");
    begin
      int age_map [string];
      age_map["Alice"]   = 30;
      age_map["Bob"]     = 25;
      age_map["Charlie"] = 35;

      $display("Total entries in age_map: %0d", age_map.num());
      $display("Alice's age: %0d", age_map["Alice"]);

      if (!age_map.exists("John")) begin
        $display("Checking 'John': John not found!");
      end else begin
        $display("John's age: %0d", age_map["John"]);
      end
    end

    // -----------------------------------------------------------
    // Exercise 6: Queue Operations (Reverse and Pop)
    // -----------------------------------------------------------
    $display("\n--- [Exercise 6] Queue Operations ---");
    begin
      automatic int data_queue [$] = '{1, 2, 3};
      $display("Initial queue: %p", data_queue);

      data_queue.reverse();
      $display("Queue after .reverse(): %p", data_queue);

      begin
        int popped_val;
        popped_val = data_queue.pop_front();
        $display("Popped front element: %0d", popped_val);
      end
      $display("Queue after .pop_front(): %p", data_queue);
    end

    $display("\n========================================");
    $display("       All Exercises Completed!         ");
    $display("========================================\n");
    $finish;
  end

endmodule
