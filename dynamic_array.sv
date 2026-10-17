module tb;
  int packet_buffer [];

  initial begin
    packet_buffer = new[10]; // Allocate initial buffer for 10 packets
    foreach (packet_buffer[i]) packet_buffer[i] = $random; // Fill with random data

    $display("Initial buffer size: %0d", packet_buffer.size()); // Size: 10

    packet_buffer = new[20] (packet_buffer); // Resize to 20, copy first 10 elements
    $display("Resized buffer size: %0d", packet_buffer.size()); // Size: 20

    packet_buffer.delete(); // Deallocate memory, size becomes 0
    $display("Buffer size after delete: %0d", packet_buffer.size()); // Size: 0
    $finish;
  end
endmodule
