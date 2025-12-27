#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e64c1d8055a3e476122633da141f16b50f0c4a2d >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e64c1d8055a3e476122633da141f16b50f0c4a2d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/backends/sqlite3/test_check_sqlite_version.py b/tests/backends/sqlite3/test_check_sqlite_version.py
new file mode 100644
index 0000000000..bd25c18cd4
--- /dev/null
+++ b/tests/backends/sqlite3/test_check_sqlite_version.py
@@ -0,0 +1,27 @@
+import unittest
+from unittest import mock
+
+from django.core.exceptions import ImproperlyConfigured
+from django.db import connection
+from django.test import TestCase
+from sqlite3 import dbapi2
+
+try:
+    from django.db.backends.sqlite3.base import check_sqlite_version
+except ImproperlyConfigured:
+    # Ignore "SQLite is too old" when running tests on another database.
+    pass
+
+
+@unittest.skipUnless(connection.vendor == 'sqlite', 'SQLite tests')
+class TestCheckSQLiteVersion(TestCase):
+
+    def test_check_sqlite_version(self):
+        """
+        Test that ImproperlyConfigured is raised for SQLite < 3.9.0.
+        """
+        msg = 'SQLite 3.9.0 or later is required (found 3.8.11).'
+        with mock.patch.object(dbapi2, 'sqlite_version_info', (3, 8, 11)), \
+                mock.patch.object(dbapi2, 'sqlite_version', '3.8.11'), \
+                self.assertRaisesMessage(ImproperlyConfigured, msg):
+            check_sqlite_version()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.sqlite3.test_check_sqlite_version
cat coverage.cover
git checkout e64c1d8055a3e476122633da141f16b50f0c4a2d
git apply /root/pre_state.patch
