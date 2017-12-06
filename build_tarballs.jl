using BinaryBuilder

# These are the platforms built inside the wizard
platforms = [
    BinaryProvider.MacOS()
]


# If the user passed in a platform (or a few, comma-separated) on the
# command-line, use that instead of our default platforms
if length(ARGS) > 0
    platforms = platform_key.(split(ARGS[1], ","))
end
info("Building for $(join(triplet.(platforms), ", "))")

# Collection of sources required to build qemu
sources = [
    "https://ftp.gnome.org/pub/gnome/sources/glib/2.54/glib-2.54.2.tar.xz" =>
    "bb89e5c5aad33169a8c7f28b45671c7899c12f74caf707737f784d7102758e6c",
    "https://zlib.net/zlib-1.2.11.tar.gz" =>
    "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
    "https://github.com/libffi/libffi.git" =>
    "716bfd83177689e2244c4707bd513003cff92c68",
    "https://github.com/Keno/qemu.git" =>
    "d50ad0140fa674b0553ce63203a3eb9e56472e18",
]

script = raw"""
cd $WORKSPACE/srcdir
export PKG_CONFIG_PATH=$DESTDIR/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=$DESTDIR
apk add texinfo gettext
cd zlib-1.2.11/
./configure --prefix=/
make install
cd ../libffi
./autogen.sh 
./configure --prefix=/ --host=$target
make -j40
make install
./configure --prefix=/ --host=$target
cd ..
cd libffi/
make install
cd ..
curl -OL https://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.8.tar.xz
tar xof gettext-0.19.8.tar.xz 
cd gettext-0.19.8
./configure --prefix=/ --host=$target
make -j40
make install
cd ..
pwd
curl -OL ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.41.tar.gz
tar --no-same-owner -xzf pcre-8.41.tar.gz 
cd pcre-8.41
./configure --prefix=/ --host=$target
make -j4
make install
cd ..
cd glib-2.54.2/
cat > glib.cache <<END
glib_cv_stack_grows=no
glib_cv_uscore=no
END
./configure --prefix=/ --cache-file=glib.cache --host=$target CPPFLAGS="-I$DESTDIR/include" "LDFLAGS=-L$DESTDIR/lib"
make -j4
make install
curl -OL https://www.cairographics.org/releases/pixman-0.34.0.tar.gz
tar xof pixman-0.34.0.tar.gz 
cd pixman-0.34.0
cat > clang.patch <<END
diff --git a/configure.ac b/configure.ac
index e833e45..cbebc82 100644
--- a/configure.ac
+++ b/configure.ac
@@ -1101,7 +1101,7 @@ support_for_gcc_vector_extensions=no
 AC_MSG_CHECKING(for GCC vector extensions)
 AC_LINK_IFELSE([AC_LANG_SOURCE([[
 unsigned int __attribute__ ((vector_size(16))) e, a, b;
-int main (void) { e = a - ((b << 27) + (b >> (32 - 27))) + 1; return e[0]; }
+int main (void) { __builtin_shuffle(a,b);e = a - ((b << 27) + (b >> (32 - 27))) + 1; return e[0]; }
 ]])], support_for_gcc_vector_extensions=yes)
 
 if test x$support_for_gcc_vector_extensions = xyes; then
-- 
2.10.0
END

patch < clang.patch 
automake
./configure --prefix=/ --host=$target
make -j40
make install
cd $WORKSPACE/srcdir/qemu/
cat > osx.patch <<END
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

patch -p1 < osx.patch 
./configure --extra-cflags="-target x86_64-apple-macosx10.7" --target-list=x86_64-softmmu --disable-cocoa
echo '#!/bin/true ' > /usr/bin/SetFile
echo '#!/bin/true ' > /usr/bin/Rez
chmod +x /usr/bin/Rez
chmod +x /usr/bin/SetFile
make -j4
make install

"""

products = prefix -> Product[
    ExecutableProduct(prefix,"x86_64-softmmu/qemu-system-x86_64")
]

# Build the given platforms using the given sources
autobuild(pwd(), "qemu", platforms, sources, script, products)

