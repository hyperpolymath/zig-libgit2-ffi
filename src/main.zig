// SPDX-License-Identifier: AGPL-3.0-or-later
//! Zig FFI bindings for libgit2
//!
//! Provides direct git repository access without subprocess calls.
//!
//! C-free: Uses extern "C" declarations linking to Rust shim.
//! No @cImport, no C headers at build time.

const std = @import("std");

// =============================================================================
// libgit2 extern declarations (C ABI via Rust shim)
// =============================================================================

// Opaque types
const git_repository = opaque {};
const git_reference = opaque {};
const git_status_list = opaque {};

const git_oid = extern struct {
    id: [20]u8,
};

const git_status_options = extern struct {
    version: c_uint,
    show: c_uint,
    flags: c_uint,
    pathspec: extern struct {
        strings: ?[*][*:0]u8,
        count: usize,
    },
    baseline: ?*anyopaque,
    rename_threshold: u16,
};

// Constants
const GIT_STATUS_OPTIONS_VERSION: c_uint = 1;
const GIT_STATUS_SHOW_INDEX_AND_WORKDIR: c_uint = 0;

// Rust shim functions (from libgit2_shim.so)
extern "C" fn git2_shim_init() c_int;
extern "C" fn git2_shim_shutdown() c_int;
extern "C" fn git2_shim_repository_open(out: *?*git_repository, path: [*:0]const u8) c_int;
extern "C" fn git2_shim_repository_free(repo: *git_repository) void;
extern "C" fn git2_shim_repository_is_bare(repo: *git_repository) c_int;
extern "C" fn git2_shim_repository_workdir(repo: *git_repository) ?[*:0]const u8;
extern "C" fn git2_shim_status_list_new(
    out: *?*git_status_list,
    repo: *git_repository,
    opts: *const git_status_options,
) c_int;
extern "C" fn git2_shim_status_list_free(list: *git_status_list) void;
extern "C" fn git2_shim_status_list_entrycount(list: *git_status_list) usize;
extern "C" fn git2_shim_repository_head(out: *?*git_reference, repo: *git_repository) c_int;
extern "C" fn git2_shim_reference_free(ref: *git_reference) void;
extern "C" fn git2_shim_reference_shorthand(ref: *git_reference) ?[*:0]const u8;
extern "C" fn git2_shim_graph_ahead_behind(
    ahead: *usize,
    behind: *usize,
    repo: *git_repository,
    local: *const git_oid,
    upstream: *const git_oid,
) c_int;
extern "C" fn git2_shim_status_options_init(opts: *git_status_options, version: c_uint) c_int;

// =============================================================================
// Zig API
// =============================================================================

pub const Error = error{
    InitFailed,
    OpenFailed,
    StatusFailed,
    CommitFailed,
    ReferenceFailed,
    AllocationFailed,
};

/// File status flags
pub const StatusFlags = struct {
    index_new: bool = false,
    index_modified: bool = false,
    index_deleted: bool = false,
    wt_new: bool = false,
    wt_modified: bool = false,
    wt_deleted: bool = false,

    pub fn isClean(self: StatusFlags) bool {
        return !self.index_new and !self.index_modified and !self.index_deleted and
            !self.wt_new and !self.wt_modified and !self.wt_deleted;
    }
};

/// Repository handle
pub const Repository = struct {
    repo: *git_repository,

    var initialized: bool = false;

    fn ensureInit() Error!void {
        if (!initialized) {
            if (git2_shim_init() < 0) {
                return Error.InitFailed;
            }
            initialized = true;
        }
    }

    pub fn open(allocator: std.mem.Allocator, path: []const u8) Error!Repository {
        try ensureInit();

        const path_z = allocator.dupeZ(u8, path) catch return Error.AllocationFailed;
        defer allocator.free(path_z);

        var repo: ?*git_repository = null;
        if (git2_shim_repository_open(&repo, path_z.ptr) < 0) {
            return Error.OpenFailed;
        }
        return Repository{ .repo = repo.? };
    }

    pub fn close(self: *Repository) void {
        git2_shim_repository_free(self.repo);
    }

    /// Check if repository is bare
    pub fn isBare(self: *Repository) bool {
        return git2_shim_repository_is_bare(self.repo) != 0;
    }

    /// Get repository workdir path
    pub fn workdir(self: *Repository) ?[]const u8 {
        const path = git2_shim_repository_workdir(self.repo);
        if (path == null) return null;
        return std.mem.span(path.?);
    }

    /// Check if working directory is clean
    pub fn isClean(self: *Repository) Error!bool {
        var opts: git_status_options = undefined;
        _ = git2_shim_status_options_init(&opts, GIT_STATUS_OPTIONS_VERSION);
        opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;

        var list: ?*git_status_list = null;
        if (git2_shim_status_list_new(&list, self.repo, &opts) < 0) {
            return Error.StatusFailed;
        }
        defer git2_shim_status_list_free(list.?);

        return git2_shim_status_list_entrycount(list.?) == 0;
    }

    /// Get HEAD reference name
    pub fn headName(self: *Repository, allocator: std.mem.Allocator) Error![]const u8 {
        var head: ?*git_reference = null;
        if (git2_shim_repository_head(&head, self.repo) < 0) {
            return Error.ReferenceFailed;
        }
        defer git2_shim_reference_free(head.?);

        const name = git2_shim_reference_shorthand(head.?);
        if (name == null) return Error.ReferenceFailed;

        return allocator.dupe(u8, std.mem.span(name.?)) catch return Error.AllocationFailed;
    }

    /// Count commits ahead/behind a remote branch
    pub fn aheadBehind(self: *Repository, local_oid: *const git_oid, remote_oid: *const git_oid) Error!struct { ahead: usize, behind: usize } {
        var ahead: usize = 0;
        var behind: usize = 0;
        if (git2_shim_graph_ahead_behind(&ahead, &behind, self.repo, local_oid, remote_oid) < 0) {
            return Error.CommitFailed;
        }
        return .{ .ahead = ahead, .behind = behind };
    }
};

// =============================================================================
// C FFI exports
// =============================================================================

var global_allocator: std.mem.Allocator = std.heap.c_allocator;

export fn git2_init() bool {
    _ = git2_shim_init();
    Repository.initialized = true;
    return true;
}

export fn git2_shutdown() void {
    _ = git2_shim_shutdown();
    Repository.initialized = false;
}

export fn git2_open(path: [*:0]const u8) ?*Repository {
    const repo = Repository.open(global_allocator, std.mem.span(path)) catch return null;
    const ptr = global_allocator.create(Repository) catch return null;
    ptr.* = repo;
    return ptr;
}

export fn git2_close(repo: *Repository) void {
    repo.close();
    global_allocator.destroy(repo);
}

export fn git2_is_clean(repo: *Repository) bool {
    return repo.isClean() catch false;
}

export fn git2_is_bare(repo: *Repository) bool {
    return repo.isBare();
}

export fn git2_workdir(repo: *Repository) ?[*:0]const u8 {
    const path = repo.workdir() orelse return null;
    return @ptrCast(path.ptr);
}

// =============================================================================
// Tests
// =============================================================================

test "Repository.open nonexistent" {
    const result = Repository.open(std.testing.allocator, "/nonexistent/path");
    try std.testing.expectError(Error.OpenFailed, result);
}
