const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const zigpb = b.addExecutable("zigpb", null);
    zigpb.setBuildMode(mode);
    zigpb.addIncludePath("protoc-zig/inc");
    zigpb.addIncludePath("/usr/local/include");
    zigpb.linkSystemLibrary("c++");
    zigpb.linkSystemLibrary("protobuf");
    zigpb.linkSystemLibrary("protoc");

    zigpb.addCSourceFiles(&.{
        "protoc-zig/src/codeGenerator.cpp",
        "protoc-zig/src/formatter.cpp",
        "protoc-zig/src/main.cpp"
    }, &.{
        "-Wall",
        "-lprotobuf",
        "-lprotoc",
        "-pthread",
        "-std=c++17"
    });

    zigpb.install();

    const build_zig_protobuf_step = b.step("zigprotobuf", "Compiles the zig-protobuf protoc plugin");
    build_zig_protobuf_step.dependOn(&zigpb.step);
}
