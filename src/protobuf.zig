const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const DecodeError = error{ InvalidField, InvalidWireType, OutOfMemory };
pub const EncodeError = error{OutOfMemory};

//https://protobuf.dev/programming-guides/encoding/#structure
const WireType = enum(u8) { VARINT, I64, LEN, SGROUP, EGROUP, I32 };

///Protobuf interface
pub fn ProtobufMessage(comptime T: type) type {
    return struct {
        const self = @This();

        var bytes_read: u64 = 0;

        pub fn ParseFromString(buffer: []const u8, allocator: Allocator) DecodeError!T {
            return try DecodeMessage(T, &self.bytes_read, buffer, allocator);
        }

        //Incomplete
        pub fn SerializeToString(message: T, _: Allocator) []u8 {
            var buffer = [_]u8{0};
            inline for (@typeInfo(T).Struct.fields) |f| {
                std.debug.print("field {s}\n", .{f.name});

                const tgt_field_name = @field(T.descriptor_pool, f.name);
                const tgt_field_number = @enumToInt(tgt_field_name);
                const wire_type = GetWireTypeFromField();

                const tag = (tgt_field_number << 3) | @enumToInt(wire_type);

                switch (wire_type) {
                    WireType.VARINT => {
                        AppendVarInt(&buffer, @intCast(u64, @field(message, f.name)));
                    },
                    else => {},
                }

                std.debug.print("reading from {} got tag {}\n", .{ tgt_field_name, tag });
            }

            return "";
        }
    };
}

fn DecodeMessage(comptime T: type, bytes_read: *u64, buffer: []const u8, allocator: Allocator) DecodeError!T {
    var message_result = T{};
    var position: u64 = 0;

    while (position < buffer.len) {
        if (position >= buffer.len) {
            break;
        }

        //the first byte is the tag, made of the field number and the wire type we're decoding
        //the last 3 bits of the decoded varint is the wire type and the rest of the bits right shifted 3 is the field number
        const tag = decodeVarint(u64, buffer[position..]);

        const wire_type = tag.value & 0b00000111;
        const field_number: u64 = @shrExact(tag.value & 0b11111000, 3);

        //std.debug.print("wire_type: {d}, field_number: {d} pos: {d}\n", .{ wire_type, field_number, position });

        if (field_number == 0) {
            //TODO: handle when a field_number doesn't exist in a msg
            return DecodeError.InvalidField;
        }

        if (wire_type > 5) {
            return DecodeError.InvalidWireType;
        }

        position += tag.bytes_read;

        switch (wire_type) {
            @enumToInt(WireType.VARINT) => {
                position += readVarintIntoStruct(T, &message_result, field_number, buffer[position..]);
            },
            @enumToInt(WireType.I64) => {
                position += readNumericIntoStruct(T, &message_result, field_number, buffer[position..]);
            },
            @enumToInt(WireType.LEN) => {
                const result = decodeVarint(u64, buffer[position..]);
                position += result.bytes_read;

                try injectLenIntoStruct(T, &message_result, field_number, []const u8, buffer[position .. position + result.value], allocator);
                position += result.value;
            },
            @enumToInt(WireType.I32) => {
                position += readNumericIntoStruct(T, &message_result, field_number, buffer[position..]);
            },
            else => {
                std.debug.print("received a wire type that cannot be handled: {}\n", .{wire_type});
                return DecodeError.InvalidWireType;
            },
        }
    }

    bytes_read.* += position;
    return message_result;
}

fn VarIntResult(comptime T: type) type {
    return struct { value: T, bytes_read: u32 };
}

fn GetWireTypeFromField() WireType {
    //TODO
    return WireType.VARINT;
}

///inject int32, int64, uint32, uint64, sint32, sint64, bool, enum into message, returns the bytes read from the buffer
fn readVarintIntoStruct(comptime T: type, msg: *T, field_number: u64, buffer: []const u8) u32 {
    const tgt_field_name = @tagName(@intToEnum(T.descriptor_pool, field_number));
    inline for (@typeInfo(T).Struct.fields) |f| {
        if (std.mem.eql(u8, f.name, tgt_field_name)) {
            var tgt_field = &@field(msg.*, f.name);
            if (comptime f.field_type == i64 or f.field_type == i32) {
                const result = decodeVarint(i64, buffer);
                tgt_field.* = @intCast(f.field_type, result.value);
                return result.bytes_read;
            } else if (comptime f.field_type == u64 or f.field_type == u32) {
                const result = decodeVarint(u64, buffer);
                tgt_field.* = @intCast(f.field_type, result.value);
                return result.bytes_read;
            } else if (comptime f.field_type == bool) {
                const result = decodeVarint(u64, buffer);
                @field(msg.*, f.name) = result.value == 1;
                return result.bytes_read;
            } else {
                std.debug.print("unhandled varint! {s}\n", .{@typeName(f.field_type)});
            }
        }
    }

    return 0;
}

///inject fixed32, sfixed32, float, fixed64, sfixed64, double into message, returns the bytes read from the buffer
fn readNumericIntoStruct(comptime T: type, msg: *T, field_number: u64, buffer: []const u8) u32 {
    const tgt_field_name = @tagName(@intToEnum(T.descriptor_pool, field_number));
    std.debug.print("adding value into {s} \n", .{tgt_field_name});
    inline for (@typeInfo(T).Struct.fields) |f| {
        if (std.mem.eql(u8, f.name, tgt_field_name)) {
            if (comptime f.field_type == f64 or f.field_type == f32 or f.field_type == i64 or f.field_type == i32) {
                const num_bytes = @sizeOf(f.field_type);
                var cpy_buffer = [_]u8{0} ** num_bytes;
                std.mem.copy(u8, &cpy_buffer, buffer[0..num_bytes]);
                var result: *f.field_type = @ptrCast(*f.field_type, @alignCast(num_bytes, &cpy_buffer));
                @field(msg.*, f.name) = result.*;

                return num_bytes;
            } else {
                std.debug.print("unhandled numeric! {s}\n", .{f.name});
            }
        }
    }

    return 0;
}

fn IsStruct(comptime T: type) bool {
    return @typeInfo(T) == @typeInfo(std.builtin.Type).Union.tag_type.?.Struct;
}

fn IsArray(comptime T: type) bool {
    return @hasField(T, "items");
}

///inject a type thats represented as a protobuf len, type should be strings, bytes, nested messages
fn injectLenIntoStruct(comptime T: type, msg: *T, field_number: u64, comptime V: type, value: V, allocator: Allocator) !void {
    const tgt_field_name = @tagName(@intToEnum(T.descriptor_pool, field_number));

    //std.debug.print("adding length of {} \n", .{value.len});
    inline for (@typeInfo(T).Struct.fields) |f| {
        //string
        if (std.mem.eql(u8, f.name, tgt_field_name)) {
            if (comptime V == []const u8 and f.field_type == V) {
                @field(msg.*, f.name) = value;
            } else if (comptime IsStruct(f.field_type)) {
                if (comptime IsArray(f.field_type)) {
                    //TODO get array_type at comptime
                    const array_type = @typeInfo(@TypeOf(@field(msg.*, f.name).items)).Pointer.child;
                    if (@field(msg.*, f.name).capacity == 0) {
                        @field(msg.*, f.name) = ArrayList(array_type).init(allocator);
                    }

                    var index: u64 = 0;
                    while (index < value.len) {
                        switch (array_type) {
                            bool => {
                                var result = decodeVarint(u32, value[index..]);
                                try @field(msg.*, f.name).append(result.value == 1);
                                index += result.bytes_read;
                            },
                            u32, u64, i32, i64 => {
                                var result = decodeVarint(u64, value[index..]);
                                try @field(msg.*, f.name).append(@intCast(array_type, result.value));
                                index += result.bytes_read;
                            },
                            f32, f64 => {
                                const num_bytes = @sizeOf(array_type);
                                var cpy_buffer = [_]u8{0} ** num_bytes;
                                std.mem.copy(u8, &cpy_buffer, value[index .. index + num_bytes]);
                                var result: *array_type = @ptrCast(*array_type, @alignCast(num_bytes, &cpy_buffer));
                                try @field(msg.*, f.name).append(@floatCast(array_type, result.*));
                                index += num_bytes;
                            },
                            []const u8 => {
                                try @field(msg.*, f.name).append(value[index..]);
                                index += @intCast(u32, value.len);
                            },
                            else => {
                                if (IsStruct(array_type)) {
                                    try @field(msg.*, f.name).append( try DecodeMessage(array_type, &index, value[index..], allocator) );
                                } else unreachable;
                            },
                        }
                    }
                } else {
                    var index: u64 = 0;
                    //assuming its a nested message
                    @field(msg.*, f.name) = try DecodeMessage(f.field_type, &index, value[index..], allocator);
                }
            } else {
                std.debug.print("unhandled len! {s}\n", .{@typeName(f.field_type)});
            }
        }
    }
}

///decode a varint and return its value and the bytes read to decode it, type should be i32,i64,u32,u64,bool,enum_t
fn decodeVarint(comptime T: type, buffer: []const u8) VarIntResult(T) {
    var index: u32 = 0;
    var byte: u8 = 0;
    var value: T = 0;

    //MSB represents if theres more data, not part of the encoded value
    while (buffer[index] & 0b10000000 != 0) : (index += 1) {
        //when we concat bytes, it is in reverse order between the previous sum and the current
        //need to shift the current byte to the left to make room for adding the existing value
        //e.g: 10110 ++ 1 -> 1 ++ 10110 -> 10000000 + 10110, ignoring the MSB

        //based on https://github.com/ziglang/zig/blob/972c0402411e19064139bc872a55fff55fbd95d6/lib/std/mem.zig#L1293
        byte = buffer[index] & 0b01111111;
        value = value | (@as(T, byte) << @intCast(std.math.Log2Int(T), index * 7));
    }

    byte = buffer[index] & 0b01111111;
    value = value | (@as(T, byte) << @intCast(std.math.Log2Int(T), index * 7));

    return VarIntResult(T){ .value = value, .bytes_read = index + 1 };
}

//TODO
fn AppendVarInt(buffer: []u8, new_val: u64) void {
    while (new_val > 0b1111111) {
        buffer[0] = 0b1000000;
        break;
    }
}

//TODO
pub fn PrintDebugString(comptime T: type, msg: T) []const u8 {
    inline for (@typeInfo(T).Struct.fields) |f| {
        std.debug.print("{any} {any}\n", .{ f.name, @field(msg, f.name) });
    }

    return "";
}
