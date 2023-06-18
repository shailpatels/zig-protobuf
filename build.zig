const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const zigpb = b.addExecutable(.{
        .name = "zigpb",
        .target = target,
        .optimize = optimize,
    });

    zigpb.addIncludePath("protoc-zig/inc");
    zigpb.addIncludePath("/usr/local/include");
    zigpb.linkSystemLibrary("c++");
    zigpb.linkSystemLibrary("protobuf");
    zigpb.linkSystemLibrary("protoc");

    zigpb.addCSourceFiles(
        &.{ "protoc-zig/src/codeGenerator.cpp", "protoc-zig/src/formatter.cpp", "protoc-zig/src/main.cpp" },
        &.{ "-Wall", "-lprotobuf", "-lprotoc", "-pthread", "-std=c++17" },
    );

    zigpb.install();

    const build_zig_protobuf_step = b.step("zigprotobuf", "Compiles the zig-protobuf protoc plugin");
    build_zig_protobuf_step.dependOn(&zigpb.step);
}
