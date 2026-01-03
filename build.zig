// SPDX-License-Identifier: AGPL-3.0-or-later
//! Build configuration for zig-libgit2-ffi
//!
//! Requires libgit2 development libraries:
//! - Fedora: sudo dnf install libgit2-devel
//! - Ubuntu: sudo apt install libgit2-dev
//! - Arch: sudo pacman -S libgit2

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig-libgit2-ffi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkSystemLibrary("git2");
    lib.linkLibC();

    b.installArtifact(lib);

    // Shared library for FFI consumers
    const shared_lib = b.addSharedLibrary(.{
        .name = "git2_ffi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    shared_lib.linkSystemLibrary("git2");
    shared_lib.linkLibC();

    b.installArtifact(shared_lib);

    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.linkSystemLibrary("git2");
    unit_tests.linkLibC();

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
