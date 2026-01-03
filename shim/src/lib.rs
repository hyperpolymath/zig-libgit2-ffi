// SPDX-License-Identifier: AGPL-3.0-or-later
//! Rust shim for libgit2 - exposes git operations via C ABI
//!
//! This allows Zig to use libgit2 without @cImport by providing
//! stable wrapper functions.

use libc::{c_char, c_int, c_uint, size_t};
use std::ffi::CStr;
use std::ptr;

// Raw bindings to libgit2
mod raw {
    use libc::{c_char, c_int, c_uint, size_t};

    pub const GIT_OID_RAWSZ: usize = 20;

    #[repr(C)]
    pub struct git_oid {
        pub id: [u8; GIT_OID_RAWSZ],
    }

    #[repr(C)]
    pub struct git_strarray {
        pub strings: *mut *mut c_char,
        pub count: size_t,
    }

    #[repr(C)]
    pub struct git_status_options {
        pub version: c_uint,
        pub show: c_uint,
        pub flags: c_uint,
        pub pathspec: git_strarray,
        pub baseline: *mut std::ffi::c_void,
        pub rename_threshold: u16,
    }

    pub enum git_repository {}
    pub enum git_reference {}
    pub enum git_status_list {}

    #[link(name = "git2")]
    extern "C" {
        pub fn git_libgit2_init() -> c_int;
        pub fn git_libgit2_shutdown() -> c_int;
        pub fn git_repository_open(out: *mut *mut git_repository, path: *const c_char) -> c_int;
        pub fn git_repository_free(repo: *mut git_repository);
        pub fn git_repository_is_bare(repo: *mut git_repository) -> c_int;
        pub fn git_repository_workdir(repo: *mut git_repository) -> *const c_char;
        pub fn git_status_options_init(opts: *mut git_status_options, version: c_uint) -> c_int;
        pub fn git_status_list_new(
            out: *mut *mut git_status_list,
            repo: *mut git_repository,
            opts: *const git_status_options,
        ) -> c_int;
        pub fn git_status_list_free(list: *mut git_status_list);
        pub fn git_status_list_entrycount(list: *const git_status_list) -> size_t;
        pub fn git_repository_head(out: *mut *mut git_reference, repo: *mut git_repository)
            -> c_int;
        pub fn git_reference_free(ref_: *mut git_reference);
        pub fn git_reference_shorthand(ref_: *const git_reference) -> *const c_char;
        pub fn git_graph_ahead_behind(
            ahead: *mut size_t,
            behind: *mut size_t,
            repo: *mut git_repository,
            local: *const git_oid,
            upstream: *const git_oid,
        ) -> c_int;
    }
}

// =============================================================================
// Shim functions
// =============================================================================

#[no_mangle]
pub extern "C" fn git2_shim_init() -> c_int {
    unsafe { raw::git_libgit2_init() }
}

#[no_mangle]
pub extern "C" fn git2_shim_shutdown() -> c_int {
    unsafe { raw::git_libgit2_shutdown() }
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_repository_open(
    out: *mut *mut raw::git_repository,
    path: *const c_char,
) -> c_int {
    raw::git_repository_open(out, path)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_repository_free(repo: *mut raw::git_repository) {
    raw::git_repository_free(repo)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_repository_is_bare(repo: *mut raw::git_repository) -> c_int {
    raw::git_repository_is_bare(repo)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_repository_workdir(
    repo: *mut raw::git_repository,
) -> *const c_char {
    raw::git_repository_workdir(repo)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_status_options_init(
    opts: *mut raw::git_status_options,
    version: c_uint,
) -> c_int {
    raw::git_status_options_init(opts, version)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_status_list_new(
    out: *mut *mut raw::git_status_list,
    repo: *mut raw::git_repository,
    opts: *const raw::git_status_options,
) -> c_int {
    raw::git_status_list_new(out, repo, opts)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_status_list_free(list: *mut raw::git_status_list) {
    raw::git_status_list_free(list)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_status_list_entrycount(
    list: *const raw::git_status_list,
) -> size_t {
    raw::git_status_list_entrycount(list)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_repository_head(
    out: *mut *mut raw::git_reference,
    repo: *mut raw::git_repository,
) -> c_int {
    raw::git_repository_head(out, repo)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_reference_free(ref_: *mut raw::git_reference) {
    raw::git_reference_free(ref_)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_reference_shorthand(
    ref_: *const raw::git_reference,
) -> *const c_char {
    raw::git_reference_shorthand(ref_)
}

#[no_mangle]
pub unsafe extern "C" fn git2_shim_graph_ahead_behind(
    ahead: *mut size_t,
    behind: *mut size_t,
    repo: *mut raw::git_repository,
    local: *const raw::git_oid,
    upstream: *const raw::git_oid,
) -> c_int {
    raw::git_graph_ahead_behind(ahead, behind, repo, local, upstream)
}
