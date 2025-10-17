// example-gatt-server-wrapper.c
#include <stdint.h>
#include <stddef.h>
#include "ble-gatt-server.c"

// This function is defined in Zig and called from here
extern void zig_write_handler(const uint8_t *data, size_t length);

// Called from BlueZ GATT server when a client writes to the characteristic
void on_characteristic_write(const uint8_t *data, size_t length) {
    // Forward to Zig
    zig_write_handler(data, length);
}

void start_gatt_server(void) {
    main_loop_run();
}
