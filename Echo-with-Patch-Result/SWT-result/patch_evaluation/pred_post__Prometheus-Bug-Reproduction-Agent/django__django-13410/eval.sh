#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 580a4341cb0b4cbfc215a70afc004875a7e815f4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 580a4341cb0b4cbfc215a70afc004875a7e815f4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/files/locks.py b/django/core/files/locks.py
--- a/django/core/files/locks.py
+++ b/django/core/files/locks.py
@@ -107,9 +107,12 @@ def unlock(f):
             return True
     else:
         def lock(f, flags):
-            ret = fcntl.flock(_fd(f), flags)
-            return ret == 0
+            try:
+                fcntl.flock(_fd(f), flags)
+                return True
+            except BlockingIOError:
+                return False
 
         def unlock(f):
-            ret = fcntl.flock(_fd(f), fcntl.LOCK_UN)
-            return ret == 0
+            fcntl.flock(_fd(f), fcntl.LOCK_UN)
+            return True

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_posix_file_lock.py b/tests/test_posix_file_lock.py
new file mode 100644
index 0000000000..618c71499e
--- /dev/null
+++ b/tests/test_posix_file_lock.py
@@ -0,0 +1,29 @@
+import os
+import tempfile
+import unittest
+
+from django.core.files import locks
+from django.test import SimpleTestCase
+
+try:
+    import fcntl
+except ImportError:
+    fcntl = None
+
+
+@unittest.skipIf(os.name != 'posix' or fcntl is None, 'POSIX-specific test')
+class PosixFileLockTests(SimpleTestCase):
+
+    def test_lock_unlock_return_value(self):
+        """
+        lock() and unlock() on POSIX systems should return True on success.
+        """
+        with tempfile.TemporaryFile() as f:
+            # The buggy version returns False on successful lock acquisition.
+            # The patched version should return True.
+            locked = locks.lock(f, locks.LOCK_EX)
+            self.assertTrue(locked, "locks.lock() should return True on success")
+
+            # The unlock function has the same bug and should also be tested.
+            unlocked = locks.unlock(f)
+            self.assertTrue(unlocked, "locks.unlock() should return True on success")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/files/locks\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_posix_file_lock
cat coverage.cover
git checkout 580a4341cb0b4cbfc215a70afc004875a7e815f4
git apply /root/pre_state.patch
