const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("libdeflate", .{});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared = b.option(
        bool, "shared", "Build as a shared library, rather than a static one"
    ) orelse false;

    const support_compression = b.option(
        bool, "compression", "Support compression"
    ) orelse true;
    const support_decompression = b.option(
        bool, "decompression", "Support decompression"
    ) orelse true;
    const support_zlib = b.option(
        bool, "zlib", "Support zlib wrapper"
    ) orelse true;
    const support_gzip = b.option(
        bool, "gzip", "Support gzip wrapper"
    ) orelse true;

    const freestanding = if (target.result.os.tag == .freestanding) true else false;

    const lib = std.Build.Step.Compile.create(b, .{
        .name = "deflate",

        .kind = .lib,
        .linkage = if (shared) .dynamic else .static,

        .root_module = .{
            .target = target,
            .optimize = optimize,
        },
    });

    lib.linkLibC();

    const files = blk: {
        var files_al = std.ArrayList([]const u8).init(b.allocator);
        try files_al.appendSlice(&.{
            "lib/arm/cpu_features.c",
            "lib/utils.c",
            "lib/x86/cpu_features.c",
        });
        if (support_compression)
            try files_al.append("lib/deflate_compress.c");
        if (support_decompression)
            try files_al.append("lib/deflate_decompress.c");
        if (support_zlib) {
            try files_al.append("lib/adler32.c");
            if (support_compression)
                try files_al.append("lib/zlib_compress.c");
            if (support_decompression)
                try files_al.append("lib/zlib_decompress.c");
        }
        if (support_gzip) {
            try files_al.append("lib/crc32.c");
            if (support_compression)
                try files_al.append("lib/gzip_compress.c");
            if (support_decompression)
                try files_al.append("lib/gzip_decompress.c");
        }

        break :blk try files_al.toOwnedSlice();
    };

    const flags = blk: {
        var flags_al = std.ArrayList([]const u8).init(b.allocator);
        try flags_al.appendSlice(&.{
            "-std=c99",
            "-Wall",
            "-Wdeclaration-after-statement",
            "-Wimplicit-fallthrough",
            "-Wmissing-field-initializers",
            "-Wmissing-prototypes",
            "-Wpedantic",
            "-Wshadow",
            "-Wstrict-prototypes",
            "-Wundef",
            "-Wvla",
        });
        if (freestanding)
            try flags_al.append("-DFREESTANDING");

        break :blk try flags_al.toOwnedSlice();
    };

    lib.addIncludePath(upstream.path("."));
    lib.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = files,
        .flags = flags,
    });

    lib.installHeader(upstream.path("libdeflate.h"), "");

    b.installArtifact(lib);
}
