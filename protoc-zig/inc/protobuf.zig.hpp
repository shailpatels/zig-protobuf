#ifndef PROTOBUF_ZIG_HPP
#define PROTOBUF_ZIG_HPP

#include <string>

static constexpr std::string_view zig_encoding_interface = R"(const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const DecodeError = error {
    InvalidField,
    InvalidWireType,
    OutOfMemory
};


///Protobuf interface
pub fn ProtobufMessage(comptime T: type) type {
    return struct {
        const self = @This();

        var position: u64 = 0;

        pub fn ParseFromString(buffer: []const u8, allocator: Allocator) DecodeError!T {
            var message_result = T{};

            while (self.position < buffer.len) : (self.position += 1) {
                if (self.position >= buffer.len) {
                    break;
                }

                //the first byte is the tag, made of the field number and the wire type we're decoding
                //the last 3 bits of the decoded varint is the wire type and the rest of the bits right shifted 3 is the field number
                const tag = decodeVarint(u64, buffer[self.position..]);

                const wire_type = tag.value & 0b00000111;
                const field_number : u64 = @shrExact(tag.value & 0b11111000, 3);

                if(field_number == 0)
                {
                    //TODO: handle when a field_number doesn't exist in a msg
                    return DecodeError.InvalidField;
                }

                //https://developers.google.com/protocol-buffers/docs/encoding#simple
                if(wire_type > 5)
                {
                    return DecodeError.InvalidWireType;
                }

                self.position += tag.bytes_read + 1;

                switch (wire_type) {
                    @enumToInt(WireType.VARINT) => {
                        const result = decodeVarint(u64, buffer[self.position..]);
                        injectNumericIntoStruct(T, &message_result, field_number, u64, result.value);

                        self.position += result.bytes_read;
                    },
                    @enumToInt(WireType.I64) => {
                        const num_bytes = 8;
                        var cpy_buffer  = [_]u8{0} ** num_bytes;
                        std.mem.copy(u8, &cpy_buffer, buffer[self.position..self.position+num_bytes]);

                        var result : *f64 = @ptrCast(*f64, @alignCast(8, &cpy_buffer));
                        injectNumericIntoStruct(T, &message_result, field_number, f64, result.*);
                        self.position += (num_bytes - 1);
                    },
                    @enumToInt(WireType.LEN) => {
                        const result = decodeVarint(u64, buffer[self.position..]);
                        self.position += 1;

                        try injectLenIntoStruct(T, &message_result, field_number, []const u8, buffer[self.position..self.position+result.value], allocator);
                        self.position += (result.value - 1);
                    },
                    @enumToInt(WireType.I32) => {
                        const num_bytes = 4;
                        var cpy_buffer  = [_]u8{0} ** num_bytes;
                        std.mem.copy(u8, &cpy_buffer, buffer[self.position..self.position+num_bytes]);

                        var result : *f32 = @ptrCast(*f32, @alignCast(4, &cpy_buffer));
                        injectNumericIntoStruct(T, &message_result, field_number, f32, result.*);
                        self.position += (num_bytes - 1);
                    },
                    else => {
                        std.debug.print("received a wire type that cannot be handled: {}\n", .{wire_type});
                        return DecodeError.InvalidWireType;
                    },
                }
            }

            return message_result;
        }


        //Incomplete
        pub fn SerializeToString(message : T, _: Allocator) []u8{
            var buffer = [_] u8 {0};
            inline for(@typeInfo(T).Struct.fields) | f |{
                std.debug.print("field {s}\n", .{f.name});

                const tgt_field_name =  @field(T.descriptor_pool, f.name);
                const tgt_field_number = @enumToInt(tgt_field_name);
                const wire_type = GetWireTypeFromField();

                const tag = (tgt_field_number << 3) | @enumToInt(wire_type);

                switch(wire_type)
                {
                    WireType.VARINT => {
                        AppendVarInt( &buffer, @intCast(u64, @field(message, f.name) ) );
                    },
                    else => {}
                }

                std.debug.print("reading from {} got tag {}\n", .{tgt_field_name, tag});
            }

            return "";
        }
    };
}


const WireType = enum(u8) { VARINT, I64, LEN, SGROUP, EGROUP, I32 };


fn VarIntResult(comptime T: type) type {
    return struct { value: T, bytes_read: u32 };
}


fn GetWireTypeFromField() WireType{
    //TODO
    return WireType.VARINT;
}


fn injectNumericIntoStruct(comptime T: type, msg: *T, field: u64, comptime V: type, value: V) void {
    const tgt_field_name =  @tagName(@intToEnum(T.descriptor_pool, field));
    //std.debug.print("adding value of {d} type {s} \n", .{value, @typeName(V)});
    inline for(@typeInfo(T).Struct.fields) | f |{
        
        if(comptime (V == f.field_type and (f.field_type == f64 or f.field_type == f32)))
        {
            if(std.mem.eql(u8, f.name, tgt_field_name)){
                @field(msg.*, f.name) = @floatCast(f.field_type, value);
            }
        }
        else if(comptime (V == u64  and (f.field_type == i32 or f.field_type == i64 or f.field_type == u32 or f.field_type == u64) )  )
        {   
            if(std.mem.eql(u8, f.name, tgt_field_name)){
                @field(msg.*, f.name) = @intCast( f.field_type ,  value);
            }
        }
        else if(comptime (f.field_type == bool))
        {
            if(std.mem.eql(u8, f.name, tgt_field_name)){
                @field(msg.*, f.name) = value == 1;
            }
        }
       
    }

}


///inject a type thats represented as a protobuf len, type should be strings, bytes, nested messages
fn injectLenIntoStruct(comptime T: type, msg: *T, field: u64, comptime V: type, value: V, allocator: Allocator) std.mem.Allocator.Error!void {
    const tgt_field_name =  @tagName(@intToEnum(T.descriptor_pool, field));

    std.debug.print("adding length of {} \n", .{ value.len });

    inline for(@typeInfo(T).Struct.fields) | f | {
        //string
        if(comptime V == []const u8 and f.field_type == V)
        {
            if(std.mem.eql(u8, f.name, tgt_field_name) )
            {
                @field(msg.*, f.name) = value;
            }
        }
        else if(comptime @typeInfo(f.field_type) == @typeInfo(std.builtin.Type).Union.tag_type.?.Struct )
        {
            if(@hasField(f.field_type, "items"))
            {
                //working with array
                std.debug.print("{s} :: {s} {}\n", .{f.name, @typeName(f.field_type), @hasField(f.field_type, "items")  });

                //TODO get array_type at comptime
                const array_type = @typeInfo(@TypeOf(@field(msg.*, f.name).items)).Pointer.child;
                @field(msg.*, f.name) = ArrayList(array_type).init(allocator);
                
                var index : u32 = 0;
                std.debug.print("arr {} {s}\n", .{value.len, @typeName(array_type)});
                while(index < value.len){
                    var result = decodeVarint(u32, value[index..]);

                    if(array_type == u32) try @field(msg.*, f.name).append(  result.value   );

                    index += result.bytes_read + 1;
                }
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
        value  = value | (@as(T, byte) << @intCast(std.math.Log2Int(T), index * 7));
    }

    byte = buffer[index] & 0b01111111;
    value  = value | (@as(T, byte) << @intCast(std.math.Log2Int(T), index * 7));

    return VarIntResult(T){ .value = value, .bytes_read = index };
}


fn AppendVarInt(buffer: [] u8, new_val: u64) void {
    while(new_val > 0b1111111)
    {
        buffer[0] = 0b1000000;
        break;
    }
}


pub fn PrintDebugString(comptime T: type, msg: T) []const u8{
    inline for(@typeInfo(T).Struct.fields) | f |{
        std.debug.print("{any} {any}\n", .{f.name, @field(msg, f.name) });
    }

    return "";
}
)";
#endif