pub const struct_timeval = extern struct {
    tv_sec: c_long,
    tv_usec: c_long,
};
pub const struct_timespec = extern struct {
    tv_sec: c_long,
    tv_nsec: c_long,
};
pub const struct_gpiod_chip = opaque {};
pub const struct_gpiod_line = opaque {};
pub const struct_gpiod_chip_iter = opaque {};
pub const struct_gpiod_line_iter = opaque {};
pub const struct_gpiod_line_bulk = extern struct {
    lines: [64]?*struct_gpiod_line,
    num_lines: c_uint,
};
pub const GPIOD_CTXLESS_FLAG_OPEN_DRAIN: c_int = 1;
pub const GPIOD_CTXLESS_FLAG_OPEN_SOURCE: c_int = 2;
pub const GPIOD_CTXLESS_FLAG_BIAS_DISABLE: c_int = 4;
pub const GPIOD_CTXLESS_FLAG_BIAS_PULL_DOWN: c_int = 8;
pub const GPIOD_CTXLESS_FLAG_BIAS_PULL_UP: c_int = 16;
pub extern fn gpiod_ctxless_get_value(device: [*c]const u8, offset: c_uint, active_low: bool, consumer: [*c]const u8) c_int;
pub extern fn gpiod_ctxless_get_value_ext(device: [*c]const u8, offset: c_uint, active_low: bool, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_ctxless_get_value_multiple(device: [*c]const u8, offsets: [*c]const c_uint, values: [*c]c_int, num_lines: c_uint, active_low: bool, consumer: [*c]const u8) c_int;
pub extern fn gpiod_ctxless_get_value_multiple_ext(device: [*c]const u8, offsets: [*c]const c_uint, values: [*c]c_int, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, flags: c_int) c_int;
pub const gpiod_ctxless_set_value_cb = ?*const fn (?*anyopaque) callconv(.C) void;
pub extern fn gpiod_ctxless_set_value(device: [*c]const u8, offset: c_uint, value: c_int, active_low: bool, consumer: [*c]const u8, cb: gpiod_ctxless_set_value_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_set_value_ext(device: [*c]const u8, offset: c_uint, value: c_int, active_low: bool, consumer: [*c]const u8, cb: gpiod_ctxless_set_value_cb, data: ?*anyopaque, flags: c_int) c_int;
pub extern fn gpiod_ctxless_set_value_multiple(device: [*c]const u8, offsets: [*c]const c_uint, values: [*c]const c_int, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, cb: gpiod_ctxless_set_value_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_set_value_multiple_ext(device: [*c]const u8, offsets: [*c]const c_uint, values: [*c]const c_int, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, cb: gpiod_ctxless_set_value_cb, data: ?*anyopaque, flags: c_int) c_int;
pub const GPIOD_CTXLESS_EVENT_RISING_EDGE: c_int = 1;
pub const GPIOD_CTXLESS_EVENT_FALLING_EDGE: c_int = 2;
pub const GPIOD_CTXLESS_EVENT_BOTH_EDGES: c_int = 3;
pub const GPIOD_CTXLESS_EVENT_CB_TIMEOUT: c_int = 1;
pub const GPIOD_CTXLESS_EVENT_CB_RISING_EDGE: c_int = 2;
pub const GPIOD_CTXLESS_EVENT_CB_FALLING_EDGE: c_int = 3;
pub const GPIOD_CTXLESS_EVENT_CB_RET_ERR: c_int = -1;
pub const GPIOD_CTXLESS_EVENT_CB_RET_OK: c_int = 0;
pub const GPIOD_CTXLESS_EVENT_CB_RET_STOP: c_int = 1;
pub const gpiod_ctxless_event_handle_cb = ?*const fn (c_int, c_uint, [*c]const struct_timespec, ?*anyopaque) callconv(.C) c_int;
pub const GPIOD_CTXLESS_EVENT_POLL_RET_STOP: c_int = -2;
pub const GPIOD_CTXLESS_EVENT_POLL_RET_ERR: c_int = -1;
pub const GPIOD_CTXLESS_EVENT_POLL_RET_TIMEOUT: c_int = 0;
pub const struct_gpiod_ctxless_event_poll_fd = extern struct {
    fd: c_int,
    event: bool,
};
pub const gpiod_ctxless_event_poll_cb = ?*const fn (c_uint, [*c]struct_gpiod_ctxless_event_poll_fd, [*c]const struct_timespec, ?*anyopaque) callconv(.C) c_int;
pub extern fn gpiod_ctxless_event_loop(device: [*c]const u8, offset: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_event_loop_multiple(device: [*c]const u8, offsets: [*c]const c_uint, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_event_monitor(device: [*c]const u8, event_type: c_int, offset: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_event_monitor_ext(device: [*c]const u8, event_type: c_int, offset: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque, flags: c_int) c_int;
pub extern fn gpiod_ctxless_event_monitor_multiple(device: [*c]const u8, event_type: c_int, offsets: [*c]const c_uint, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque) c_int;
pub extern fn gpiod_ctxless_event_monitor_multiple_ext(device: [*c]const u8, event_type: c_int, offsets: [*c]const c_uint, num_lines: c_uint, active_low: bool, consumer: [*c]const u8, timeout: [*c]const struct_timespec, poll_cb: gpiod_ctxless_event_poll_cb, event_cb: gpiod_ctxless_event_handle_cb, data: ?*anyopaque, flags: c_int) c_int;
pub extern fn gpiod_ctxless_find_line(name: [*c]const u8, chipname: [*c]u8, chipname_size: usize, offset: [*c]c_uint) c_int;
pub extern fn gpiod_chip_open(path: [*c]const u8) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_open_by_name(name: [*c]const u8) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_open_by_number(num: c_uint) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_open_by_label(label: [*c]const u8) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_open_lookup(descr: [*c]const u8) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_close(chip: ?*struct_gpiod_chip) void;
pub extern fn gpiod_chip_name(chip: ?*struct_gpiod_chip) [*c]const u8;
pub extern fn gpiod_chip_label(chip: ?*struct_gpiod_chip) [*c]const u8;
pub extern fn gpiod_chip_num_lines(chip: ?*struct_gpiod_chip) c_uint;
pub extern fn gpiod_chip_get_line(chip: ?*struct_gpiod_chip, offset: c_uint) ?*struct_gpiod_line;
pub extern fn gpiod_chip_get_lines(chip: ?*struct_gpiod_chip, offsets: [*c]c_uint, num_offsets: c_uint, bulk: [*c]struct_gpiod_line_bulk) c_int;
pub extern fn gpiod_chip_get_all_lines(chip: ?*struct_gpiod_chip, bulk: [*c]struct_gpiod_line_bulk) c_int;
pub extern fn gpiod_chip_find_line(chip: ?*struct_gpiod_chip, name: [*c]const u8) ?*struct_gpiod_line;
pub extern fn gpiod_chip_find_lines(chip: ?*struct_gpiod_chip, names: [*c][*c]const u8, bulk: [*c]struct_gpiod_line_bulk) c_int;

pub fn gpiod_line_bulk_init(arg_bulk: [*c]struct_gpiod_line_bulk) callconv(.C) void {
    const bulk = arg_bulk;
    bulk.*.num_lines = 0;
}
pub fn gpiod_line_bulk_add(arg_bulk: [*c]struct_gpiod_line_bulk, arg_line: ?*struct_gpiod_line) callconv(.C) void {
    const bulk = arg_bulk;
    const line = arg_line;
    bulk.*.lines[
        blk: {
            const ref = &bulk.*.num_lines;
            const tmp = ref.*;
            ref.* +%= 1;
            break :blk tmp;
        }
    ] = line;
}
pub fn gpiod_line_bulk_get_line(arg_bulk: [*c]struct_gpiod_line_bulk, arg_offset: c_uint) callconv(.C) ?*struct_gpiod_line {
    const bulk = arg_bulk;
    const offset = arg_offset;
    return bulk.*.lines[offset];
}
pub fn gpiod_line_bulk_num_lines(arg_bulk: [*c]struct_gpiod_line_bulk) callconv(.C) c_uint {
    const bulk = arg_bulk;
    return bulk.*.num_lines;
}
pub const GPIOD_LINE_DIRECTION_INPUT: c_int = 1;
pub const GPIOD_LINE_DIRECTION_OUTPUT: c_int = 2;
pub const GPIOD_LINE_ACTIVE_STATE_HIGH: c_int = 1;
pub const GPIOD_LINE_ACTIVE_STATE_LOW: c_int = 2;
pub const GPIOD_LINE_BIAS_AS_IS: c_int = 1;
pub const GPIOD_LINE_BIAS_DISABLE: c_int = 2;
pub const GPIOD_LINE_BIAS_PULL_UP: c_int = 3;
pub const GPIOD_LINE_BIAS_PULL_DOWN: c_int = 4;
pub extern fn gpiod_line_offset(line: ?*struct_gpiod_line) c_uint;
pub extern fn gpiod_line_name(line: ?*struct_gpiod_line) [*c]const u8;
pub extern fn gpiod_line_consumer(line: ?*struct_gpiod_line) [*c]const u8;
pub extern fn gpiod_line_direction(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_active_state(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_bias(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_is_used(line: ?*struct_gpiod_line) bool;
pub extern fn gpiod_line_is_open_drain(line: ?*struct_gpiod_line) bool;
pub extern fn gpiod_line_is_open_source(line: ?*struct_gpiod_line) bool;
pub extern fn gpiod_line_update(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_needs_update(line: ?*struct_gpiod_line) bool;
pub const GPIOD_LINE_REQUEST_DIRECTION_AS_IS: c_int = 1;
pub const GPIOD_LINE_REQUEST_DIRECTION_INPUT: c_int = 2;
pub const GPIOD_LINE_REQUEST_DIRECTION_OUTPUT: c_int = 3;
pub const GPIOD_LINE_REQUEST_EVENT_FALLING_EDGE: c_int = 4;
pub const GPIOD_LINE_REQUEST_EVENT_RISING_EDGE: c_int = 5;
pub const GPIOD_LINE_REQUEST_EVENT_BOTH_EDGES: c_int = 6;
pub const GPIOD_LINE_REQUEST_FLAG_OPEN_DRAIN: c_int = 1;
pub const GPIOD_LINE_REQUEST_FLAG_OPEN_SOURCE: c_int = 2;
pub const GPIOD_LINE_REQUEST_FLAG_ACTIVE_LOW: c_int = 4;
pub const GPIOD_LINE_REQUEST_FLAG_BIAS_DISABLE: c_int = 8;
pub const GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_DOWN: c_int = 16;
pub const GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP: c_int = 32;
pub const struct_gpiod_line_request_config = extern struct {
    consumer: [*c]const u8,
    request_type: c_int,
    flags: c_int,
};
pub extern fn gpiod_line_request(line: ?*struct_gpiod_line, config: [*c]const struct_gpiod_line_request_config, default_val: c_int) c_int;
pub extern fn gpiod_line_request_input(line: ?*struct_gpiod_line, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_output(line: ?*struct_gpiod_line, consumer: [*c]const u8, default_val: c_int) c_int;
pub extern fn gpiod_line_request_rising_edge_events(line: ?*struct_gpiod_line, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_falling_edge_events(line: ?*struct_gpiod_line, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_both_edges_events(line: ?*struct_gpiod_line, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_input_flags(line: ?*struct_gpiod_line, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_output_flags(line: ?*struct_gpiod_line, consumer: [*c]const u8, flags: c_int, default_val: c_int) c_int;
pub extern fn gpiod_line_request_rising_edge_events_flags(line: ?*struct_gpiod_line, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_falling_edge_events_flags(line: ?*struct_gpiod_line, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_both_edges_events_flags(line: ?*struct_gpiod_line, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_bulk(bulk: [*c]struct_gpiod_line_bulk, config: [*c]const struct_gpiod_line_request_config, default_vals: [*c]const c_int) c_int;
pub extern fn gpiod_line_request_bulk_input(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_bulk_output(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, default_vals: [*c]const c_int) c_int;
pub extern fn gpiod_line_request_bulk_rising_edge_events(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_bulk_falling_edge_events(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_bulk_both_edges_events(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8) c_int;
pub extern fn gpiod_line_request_bulk_input_flags(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_bulk_output_flags(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, flags: c_int, default_vals: [*c]const c_int) c_int;
pub extern fn gpiod_line_request_bulk_rising_edge_events_flags(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_bulk_falling_edge_events_flags(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_request_bulk_both_edges_events_flags(bulk: [*c]struct_gpiod_line_bulk, consumer: [*c]const u8, flags: c_int) c_int;
pub extern fn gpiod_line_release(line: ?*struct_gpiod_line) void;
pub extern fn gpiod_line_release_bulk(bulk: [*c]struct_gpiod_line_bulk) void;
pub extern fn gpiod_line_is_requested(line: ?*struct_gpiod_line) bool;
pub extern fn gpiod_line_is_free(line: ?*struct_gpiod_line) bool;
pub extern fn gpiod_line_get_value(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_get_value_bulk(bulk: [*c]struct_gpiod_line_bulk, values: [*c]c_int) c_int;
pub extern fn gpiod_line_set_value(line: ?*struct_gpiod_line, value: c_int) c_int;
pub extern fn gpiod_line_set_value_bulk(bulk: [*c]struct_gpiod_line_bulk, values: [*c]const c_int) c_int;
pub extern fn gpiod_line_set_config(line: ?*struct_gpiod_line, direction: c_int, flags: c_int, value: c_int) c_int;
pub extern fn gpiod_line_set_config_bulk(bulk: [*c]struct_gpiod_line_bulk, direction: c_int, flags: c_int, values: [*c]const c_int) c_int;
pub extern fn gpiod_line_set_flags(line: ?*struct_gpiod_line, flags: c_int) c_int;
pub extern fn gpiod_line_set_flags_bulk(bulk: [*c]struct_gpiod_line_bulk, flags: c_int) c_int;
pub extern fn gpiod_line_set_direction_input(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_set_direction_input_bulk(bulk: [*c]struct_gpiod_line_bulk) c_int;
pub extern fn gpiod_line_set_direction_output(line: ?*struct_gpiod_line, value: c_int) c_int;
pub extern fn gpiod_line_set_direction_output_bulk(bulk: [*c]struct_gpiod_line_bulk, values: [*c]const c_int) c_int;
pub const GPIOD_LINE_EVENT_RISING_EDGE: c_int = 1;
pub const GPIOD_LINE_EVENT_FALLING_EDGE: c_int = 2;
pub const struct_gpiod_line_event = extern struct {
    ts: struct_timespec,
    event_type: c_int,
};
pub extern fn gpiod_line_event_wait(line: ?*struct_gpiod_line, timeout: [*c]const struct_timespec) c_int;
pub extern fn gpiod_line_event_wait_bulk(bulk: [*c]struct_gpiod_line_bulk, timeout: [*c]const struct_timespec, event_bulk: [*c]struct_gpiod_line_bulk) c_int;
pub extern fn gpiod_line_event_read(line: ?*struct_gpiod_line, event: [*c]struct_gpiod_line_event) c_int;
pub extern fn gpiod_line_event_read_multiple(line: ?*struct_gpiod_line, events: [*c]struct_gpiod_line_event, num_events: c_uint) c_int;
pub extern fn gpiod_line_event_get_fd(line: ?*struct_gpiod_line) c_int;
pub extern fn gpiod_line_event_read_fd(fd: c_int, event: [*c]struct_gpiod_line_event) c_int;
pub extern fn gpiod_line_event_read_fd_multiple(fd: c_int, events: [*c]struct_gpiod_line_event, num_events: c_uint) c_int;
pub extern fn gpiod_line_get(device: [*c]const u8, offset: c_uint) ?*struct_gpiod_line;
pub extern fn gpiod_line_find(name: [*c]const u8) ?*struct_gpiod_line;
pub extern fn gpiod_line_close_chip(line: ?*struct_gpiod_line) void;
pub extern fn gpiod_line_get_chip(line: ?*struct_gpiod_line) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_iter_new() ?*struct_gpiod_chip_iter;
pub extern fn gpiod_chip_iter_free(iter: ?*struct_gpiod_chip_iter) void;
pub extern fn gpiod_chip_iter_free_noclose(iter: ?*struct_gpiod_chip_iter) void;
pub extern fn gpiod_chip_iter_next(iter: ?*struct_gpiod_chip_iter) ?*struct_gpiod_chip;
pub extern fn gpiod_chip_iter_next_noclose(iter: ?*struct_gpiod_chip_iter) ?*struct_gpiod_chip;
pub extern fn gpiod_line_iter_new(chip: ?*struct_gpiod_chip) ?*struct_gpiod_line_iter;
pub extern fn gpiod_line_iter_free(iter: ?*struct_gpiod_line_iter) void;
pub extern fn gpiod_line_iter_next(iter: ?*struct_gpiod_line_iter) ?*struct_gpiod_line;
pub extern fn gpiod_version_string() [*c]const u8;
pub const GPIOD_API = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // /usr/include/gpiod.h:62:9
pub const GPIOD_UNUSED = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // /usr/include/gpiod.h:67:9
pub const GPIOD_DEPRECATED = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // /usr/include/gpiod.h:79:9
pub const GPIOD_LINE_BULK_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/gpiod.h:734:9
pub const gpiod_line_bulk_foreach_line = @compileError("unable to translate C expr: unexpected token 'for'"); // /usr/include/gpiod.h:788:9
pub const gpiod_line_bulk_foreach_line_off = @compileError("unable to translate C expr: unexpected token 'for'"); // /usr/include/gpiod.h:806:9
pub const gpiod_foreach_chip = @compileError("unable to translate C expr: unexpected token 'for'"); // /usr/include/gpiod.h:1697:9
pub const gpiod_foreach_chip_noclose = @compileError("unable to translate C expr: unexpected token 'for'"); // /usr/include/gpiod.h:1712:9
pub const gpiod_foreach_line = @compileError("unable to translate C expr: unexpected token 'for'"); // /usr/include/gpiod.h:1747:9
pub inline fn GPIOD_BIT(nr: anytype) @TypeOf(@as(c_ulong, 1) << nr) {
    return @as(c_ulong, 1) << nr;
}
pub const GPIOD_LINE_BULK_MAX_LINES = @as(c_int, 64);
pub const gpiod_chip = struct_gpiod_chip;
pub const gpiod_line = struct_gpiod_line;
pub const gpiod_chip_iter = struct_gpiod_chip_iter;
pub const gpiod_line_iter = struct_gpiod_line_iter;
pub const gpiod_line_bulk = struct_gpiod_line_bulk;
pub const gpiod_ctxless_event_poll_fd = struct_gpiod_ctxless_event_poll_fd;
pub const gpiod_line_request_config = struct_gpiod_line_request_config;
pub const gpiod_line_event = struct_gpiod_line_event;
