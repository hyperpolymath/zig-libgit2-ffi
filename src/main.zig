// SPDX-License-Identifier: AGPL-3.0-or-later
//! Zig FFI bindings for libgit2
//!
//! Provides direct git repository access without subprocess calls.
//!
//! Inspired by: hyperpolymath/personal-sysadmin daemon needs

const std = @import("std");
const c = @cImport({
    @cInclude("git2.h");
});

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
    repo: *c.git_repository,

    var initialized: bool = false;

    fn ensureInit() Error!void {
        if (!initialized) {
            if (c.git_libgit2_init() < 0) {
                return Error.InitFailed;
            }
            initialized = true;
        }
    }

    pub fn open(path: []const u8) Error!Repository {
        try ensureInit();

        var repo: ?*c.git_repository = null;
        if (c.git_repository_open(&repo, path.ptr) < 0) {
            return Error.OpenFailed;
        }
        return Repository{ .repo = repo.? };
    }

    pub fn close(self: *Repository) void {
        c.git_repository_free(self.repo);
    }

    /// Check if repository is bare
    pub fn isBare(self: *Repository) bool {
        return c.git_repository_is_bare(self.repo) != 0;
    }

    /// Get repository workdir path
    pub fn workdir(self: *Repository) ?[]const u8 {
        const path = c.git_repository_workdir(self.repo);
        if (path == null) return null;
        return std.mem.span(path);
    }

    /// Check if working directory is clean
    pub fn isClean(self: *Repository) Error!bool {
        var opts: c.git_status_options = undefined;
        _ = c.git_status_options_init(&opts, c.GIT_STATUS_OPTIONS_VERSION);
        opts.show = c.GIT_STATUS_SHOW_INDEX_AND_WORKDIR;

        var list: ?*c.git_status_list = null;
        if (c.git_status_list_new(&list, self.repo, &opts) < 0) {
            return Error.StatusFailed;
        }
        defer c.git_status_list_free(list);

        return c.git_status_list_entrycount(list) == 0;
    }

    /// Get HEAD reference name
    pub fn headName(self: *Repository, allocator: std.mem.Allocator) Error![]const u8 {
        var head: ?*c.git_reference = null;
        if (c.git_repository_head(&head, self.repo) < 0) {
            return Error.ReferenceFailed;
        }
        defer c.git_reference_free(head);

        const name = c.git_reference_shorthand(head);
        if (name == null) return Error.ReferenceFailed;

        return allocator.dupe(u8, std.mem.span(name)) catch return Error.AllocationFailed;
    }

    /// Count commits ahead/behind a remote branch
    pub fn aheadBehind(self: *Repository, local_oid: *const c.git_oid, remote_oid: *const c.git_oid) Error!struct { ahead: usize, behind: usize } {
        var ahead: usize = 0;
        var behind: usize = 0;
        if (c.git_graph_ahead_behind(&ahead, &behind, self.repo, local_oid, remote_oid) < 0) {
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
    _ = c.git_libgit2_init();
    Repository.initialized = true;
    return true;
}

export fn git2_shutdown() void {
    _ = c.git_libgit2_shutdown();
    Repository.initialized = false;
}

export fn git2_open(path: [*:0]const u8) ?*Repository {
    const repo = Repository.open(std.mem.span(path)) catch return null;
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
    const result = Repository.open("/nonexistent/path");
    try std.testing.expectError(Error.OpenFailed, result);
}
