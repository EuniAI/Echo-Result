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
diff --git a/tests/files/test_locks.py b/tests/files/test_locks.py
new file mode 100644
index 0000000000..24d1d96c38
--- /dev/null
+++ b/tests/files/test_locks.py
@@ -0,0 +1,25 @@
+import os
+import tempfile
+import unittest
+
+try:
+    import fcntl
+except ImportError:
+    fcntl = None
+
+from django.core.files import locks
+
+
+@unittest.skipUnless(fcntl, "fcntl module not available.")
+class FileLockTests(unittest.TestCase):
+    def test_lock_return_value(self):
+        """
+        lock() should return True when a lock is acquired.
+        """
+        with tempfile.TemporaryFile() as f:
+            locked = locks.lock(f, locks.LOCK_EX | locks.LOCK_NB)
+            try:
+                self.assertTrue(locked)
+            finally:
+                if locked:
+                    locks.unlock(f)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/files/locks\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 files.test_locks
cat coverage.cover
git checkout 580a4341cb0b4cbfc215a70afc004875a7e815f4
git apply /root/pre_state.patch
