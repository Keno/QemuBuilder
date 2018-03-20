using BinaryBuilder

# Collection of sources required to build libffi
sources = [
    "https://github.com/Keno/qemu.git" =>
    "d50ad0140fa674b0553ce63203a3eb9e56472e18",
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/qemu

patch -p1 <<END
diff --git a/hw/9pfs/9p-local.c b/hw/9pfs/9p-local.c
index f49288f..5b8d6e6 100644
--- a/hw/9pfs/9p-local.c
+++ b/hw/9pfs/9p-local.c
@@ -1075,6 +1075,8 @@ out:
 static int local_utimensat(FsContext *s, V9fsPath *fs_path,
                            const struct timespec *buf)
 {
+    return -EOPNOTSUPP;
+#if 0
     char *dirpath = g_path_get_dirname(fs_path->data);
     char *name = g_path_get_basename(fs_path->data);
     int dirfd, ret = -1;
@@ -1090,6 +1092,7 @@ out:
     g_free(dirpath);
     g_free(name);
     return ret;
+#endif
 }
 static int local_unlinkat_common(FsContext *ctx, int dirfd, const char *name,

diff --git a/hw/9pfs/9p.c b/hw/9pfs/9p.c
index daa8519..dea55e4 100644
--- a/hw/9pfs/9p.c
+++ b/hw/9pfs/9p.c
@@ -1227,6 +1227,9 @@ static void coroutine_fn v9fs_setattr(void *opaque)
         }
     }
     if (v9iattr.valid & (P9_ATTR_ATIME | P9_ATTR_MTIME)) {
+        err = -EOPNOTSUPP;
+        goto out;
+#if 0
         struct timespec times[2];
         if (v9iattr.valid & P9_ATTR_ATIME) {
             if (v9iattr.valid & P9_ATTR_ATIME_SET) {
@@ -1252,6 +1255,7 @@ static void coroutine_fn v9fs_setattr(void *opaque)
         if (err < 0) {
             goto out;
         }
+#endif
     }
     /*
      * If the only valid entry in iattr is ctime we can call
@@ -2906,6 +2910,9 @@ static void coroutine_fn v9fs_wstat(void *opaque)
         }
     }
     if (v9stat.mtime != -1 || v9stat.atime != -1) {
+        err = -EOPNOTSUPP;
+        goto out;
+#if 0
         struct timespec times[2];
         if (v9stat.atime != -1) {
             times[0].tv_sec = v9stat.atime;
@@ -2923,6 +2930,7 @@ static void coroutine_fn v9fs_wstat(void *opaque)
         if (err < 0) {
             goto out;
         }
+#endif
     }
     if (v9stat.n_gid != -1 || v9stat.n_uid != -1) {
         err = v9fs_co_chown(pdu, &fidp->path, v9stat.n_uid, v9stat.n_gid);
END

./configure --extra-cflags="-target $target" --target-list=x86_64-softmmu --disable-cocoa --prefix=$prefix
echo '#!/bin/true ' > /usr/bin/SetFile
echo '#!/bin/true ' > /usr/bin/Rez
chmod +x /usr/bin/Rez
chmod +x /usr/bin/SetFile
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    # For now, only build for MacOS
    BinaryProvider.MacOS(),
]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "x86_64-softmmu/qemu-system-x86_64", :qemu_x86_64)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    # We need Pixman
    "https://github.com/staticfloat/PixmanBuilder/releases/download/v0.34.0-0/build.jl",
    # We need Glib
    "https://github.com/staticfloat/GlibBuilder/releases/download/v2.54.2-2/build.jl",
    # We need Pcre
    "https://github.com/staticfloat/PcreBuilder/releases/download/v8.41-0/build.jl",
    # We need gettext
    "https://github.com/staticfloat/GettextBuilder/releases/download/v0.19.8-0/build.jl",
    # .....which needs libffi
    "https://github.com/staticfloat/libffiBuilder/releases/download/v3.2.1-0/build.jl",
    # .....which needs zlib
    "https://github.com/staticfloat/ZlibBuilder/releases/download/v1.2.11-3/build.jl",
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, "Qemu", sources, script, platforms, products, dependencies)
