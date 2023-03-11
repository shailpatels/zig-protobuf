const std = @import("std");
const pb = @import("generated/conformance.pb.zig");
const ConformanceRequest = pb.ConformanceRequest;
const ConformanceResponse = pb.ConformanceResponse;

pub fn main() !void {
    var runner = TestRunner{};
    while(!runner.is_done)
    {
        try runner.serveTest();
        break;
    }
}

const TestRunner = struct { 
    is_done: bool = false,

    pub fn serveTest(self: *TestRunner) !void {
        //read first 4 bytes
        var in_len: u32 = undefined;
        var buffer: [@sizeOf(u32)]u8 = undefined;
        self.is_done = try readInStream(std.io.getStdIn().reader(), &buffer, @sizeOf(u32)); 

        in_len = try std.fmt.parseInt(u32, buffer[0..buffer.len-1], 10); 
        const allocator = std.heap.page_allocator;
        var input = try allocator.alloc(u8, in_len);
        defer allocator.free(input);

        self.is_done = try readInStream(std.io.getStdIn().reader(), input, in_len);
        
        var request = try ConformanceRequest.ParseFromString(input, allocator); 

           
        const reply = runTest(request);
        try reply.SerializeToWriter(std.io.getStdOut().writer());
        //_ = try std.io.getStdOut().writer().write(input);
    }

    pub fn runTest(_: ConformanceRequest) ConformanceResponse{
       var reply = ConformanceResponse{}; 
        
        return reply;
    }
};


fn readInStream(reader: anytype, buffer: []u8, expected_size: u32) !bool {
    const read_bytes = try reader.read(buffer);
    if(read_bytes != expected_size)
    {
        return true;
    }

    return false;
}

