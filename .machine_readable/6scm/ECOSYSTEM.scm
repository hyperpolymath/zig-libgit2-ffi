;; SPDX-License-Identifier: MPL-2.0
;; ECOSYSTEM.scm - Project ecosystem positioning

(ecosystem
  ((version . "1.0.0")
   (name . "zig-libgit2-ffi")
   (type . "library")
   (purpose . "FFI bindings for libgit2 Git library")
   (position-in-ecosystem . "infrastructure")
   (related-projects
     ((zig-nickel-ffi . "sibling-ffi")))
   (what-this-is . ("Zig FFI bindings"))
   (what-this-is-not . ("A reimplementation"))))
