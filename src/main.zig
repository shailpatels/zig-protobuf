const std = @import("std");
const time = std.time;

const ProtobufMessage = @import("protobuf.zig").ProtobufMessage;
const PrintDebugString = @import("protobuf.zig").PrintDebugString;

const expect = std.testing.expect;

test "Decode simple.Test1.1.bin" {
    std.debug.print("\n", .{});
    const message = @import("generated/simple.pb.zig");

    const data = try readFile("generated/simple.Test1.1.bin");
    defer std.testing.allocator.free(data);

    try expect(std.mem.eql(u8, data, @embedFile("generated/simple.Test1.1.bin")));

    var timer = try time.Timer.start();
    const time_0 = timer.read();
    const msg = try ProtobufMessage(message.Test1).ParseFromString(data, std.testing.allocator);
    const time_1 = timer.lap();

    std.debug.print("time : {}\n", .{time_1 - time_0});

    try std.testing.expectEqual(@as(i32, 150), msg.a);

    const msg_2 = try message.Test1.ParseFromString(@embedFile("generated/simple.Test1.1.bin"), std.testing.allocator);
    try std.testing.expectEqual(@as(i32, 150), msg_2.a);
}

test "Decode message.SearchRequest.1.bin" {
    std.debug.print("\n", .{});
    const message = @import("generated/message.pb.zig");

    const msg = try ProtobufMessage(message.SearchRequest).ParseFromString(@embedFile("generated/message.SearchRequest.1.bin"), std.testing.allocator);

    try std.testing.expectEqual(msg.page_number, 5);
    try expect(msg.result_per_page == 10);
    try expect(std.mem.eql(u8, msg.query, "testing"));

    const msg_2 = try message.SearchRequest.ParseFromString(@embedFile("generated/message.SearchRequest.1.bin"), std.testing.allocator);

    try expect(msg_2.page_number == 5);
    try expect(msg_2.result_per_page == 10);
    try expect(std.mem.eql(u8, msg_2.query, "testing"));
}

test "Decode test.Foo.1.bin" {
    const message = @import("generated/test.pb.zig");

    const data = @embedFile("generated/test.Foo.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.Foo).ParseFromString(data, std.testing.allocator);

    try std.testing.expectEqual(@as(f64, 100), msg.a);
    try std.testing.expectEqual(@as(f32, 3.14), msg.b);
    try std.testing.expectEqual(@as(i32, -23), msg.c);
    try std.testing.expectEqual(@as(bool, true), msg.o);
    try std.testing.expectEqual(@as(usize, 4), msg.e.items.len);
    try std.testing.expectEqual(@as(u32, 5), msg.e.items[0]);
    try std.testing.expectEqual(@as(u32, 4), msg.e.items[1]);
    try std.testing.expectEqual(@as(u32, 2), msg.e.items[2]);
    try std.testing.expectEqual(@as(u32, 1), msg.e.items[3]);
    try std.testing.expectEqual(@as(u64, 150), msg.f);
    try std.testing.expectEqual(@as(i32, -20), msg.g);
    try std.testing.expectEqual(@as(u64, 200), msg.h);
    msg.e.deinit();
    msg.p.deinit();

    //_ = PrintDebugString(message.Foo, msg);
}

test "Decode simple.BasicRepeated.1.bin" {
    const message = @import("generated/simple.pb.zig");

    const data = @embedFile("generated/simple.BasicRepeated.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.BasicRepeated).ParseFromString(data, std.testing.allocator);

    try std.testing.expectEqual(@as(bool, false), msg.a.items[0]);
    try std.testing.expectEqual(@as(bool, true), msg.a.items[1]);
    try std.testing.expectEqual(@as(i32, 25), msg.b);
    try std.testing.expectEqual(@as(f32, 3.14), msg.c.items[0]);
    try std.testing.expectEqual(@as(f32, 3.20), msg.c.items[1]);
    msg.a.deinit();
    msg.c.deinit();
}

test "Decode simple.NestedMessage.1.bin" {
    const message = @import("generated/simple.pb.zig");

    const data = @embedFile("generated/simple.NestedMessage.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.NestedMessage).ParseFromString(data, std.testing.allocator);

    try expect(std.mem.eql(u8, "hello", msg.a.b));
}

test "Decode simple.RepeatedStrings.1.bin" {
    const message = @import("generated/simple.pb.zig");

    const data = @embedFile("generated/simple.RepeatedStrings.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.RepeatedStrings).ParseFromString(data, std.testing.allocator);

    try expect(std.mem.eql(u8, "first", msg.a.items[0]));
    try expect(std.mem.eql(u8, "second", msg.a.items[1]));
    try std.testing.expectEqual(@as(i32, 25), msg.b);
    msg.a.deinit();
}

test "Decode simple.BasicMap.1.bin" {
    const message = @import("generated/simple.pb.zig");

    const data = @embedFile("generated/simple.BasicMap.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.BasicMap).ParseFromString(data, std.testing.allocator);

    try expect(std.mem.eql(u8, "A", msg.map_field.items[0].key));
    try expect(std.mem.eql(u8, "B", msg.map_field.items[1].key));
    try expect(std.mem.eql(u8, "C", msg.map_field.items[2].key));
    try std.testing.expectEqual(@as(i32, 1), msg.map_field.items[0].value);
    try std.testing.expectEqual(@as(i32, 2), msg.map_field.items[1].value);
    try std.testing.expectEqual(@as(i32, 3), msg.map_field.items[2].value);
    msg.map_field.deinit();
}

test "Decode test.one_of.1.bin" {
    const message = @import("generated/test.pb.zig");

    const data = @embedFile("generated/test.one_of.1.bin");
    std.debug.print("{x}\n", .{std.fmt.fmtSliceHexLower(data)});
    const msg = try ProtobufMessage(message.OneOfTest).ParseFromString(data, std.testing.allocator);

    try expect(std.mem.eql(u8, "string is set", msg.test_oneof.name)); 
}

test "Handle empty message" {
    const message = @import("generated/simple.pb.zig");
    const msg = try ProtobufMessage(message.EmptyMessage).ParseFromString("", std.testing.allocator);
    _ = msg;
}

test "Encode simple.Test1.1.bin" {
    const message = @import("generated/simple.pb.zig");
    const msg_1 = message.Test1{ .a = 150 };

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    const expected_buffer = @embedFile("generated/simple.Test1.1.bin");
    defer buffer.deinit();

    try ProtobufMessage(message.Test1).SerializeToWriter(msg_1, buffer.writer());

    try std.testing.expectEqualSlices(u8, expected_buffer, buffer.items);
}

test "Encode oneof" {
    const conformance = @import("generated/conformance.pb.zig");
    var buffer = std.ArrayList(u8).init(std.testing.allocator);

    var msg = conformance.ConformanceResponse{};
    msg.result = .{ .skipped = "test" };
    try ProtobufMessage(conformance.ConformanceResponse).SerializeToWriter(msg, buffer.writer());
}

fn readFile(comptime tgt_filename: []const u8) ![]u8 {
    const file_ptr: std.fs.File = try (std.fs.cwd().openFile(tgt_filename, std.fs.File.OpenFlags{}));

    const stat = try file_ptr.stat();
    var buffer = try std.testing.allocator.alloc(u8, stat.size);

    _ = try file_ptr.reader().readAll(buffer);

    return buffer;
}
