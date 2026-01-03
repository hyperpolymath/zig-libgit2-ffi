# Provenance

## Inspired By

**Repository**: [hyperpolymath/personal-sysadmin](https://github.com/hyperpolymath/personal-sysadmin)

## Challenge

The personal-sysadmin daemon uses subprocess calls to git:

**Location**: Multiple files in `src/`

```rust
// Current approach - subprocess calls
Command::new("git")
    .args(["status", "--porcelain"])
    .output()

Command::new("git")
    .args(["log", "--oneline", "-n", "10"])
    .output()

Command::new("git")
    .args(["diff", "--stat"])
    .output()
```

## Problem

1. **Process spawn overhead**: Each git call spawns a new process
2. **Text parsing**: Git output must be parsed
3. **No incremental access**: Can't efficiently watch for changes
4. **Limited API**: Shell commands don't expose full git functionality

## Solution

This Zig FFI library provides direct bindings to libgit2, enabling:
- Repository open/clone operations
- Status queries without subprocess
- Commit history traversal
- Diff generation
- Reference management

## How It Helps

| Before (subprocess) | After (FFI) |
|---------------------|-------------|
| ~15ms per git call | ~0.5ms per libgit2 call |
| Text parsing required | Native struct access |
| Process spawn overhead | Single library load |
| Limited error info | Full libgit2 errors |
