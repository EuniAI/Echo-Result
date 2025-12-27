#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d89f976bddb49fb168334960acc8979c3de991fa >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d89f976bddb49fb168334960acc8979c3de991fa
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/db/backends/postgresql/test_operations.py b/tests/db/backends/postgresql/test_operations.py
new file mode 100644
index 0000000000..e82a51d4b5
--- /dev/null
+++ b/tests/db/backends/postgresql/test_operations.py
@@ -0,0 +1,15 @@
+import unittest
+
+from django.db import connection
+from django.test import SimpleTestCase
+
+
+@unittest.skipUnless(connection.vendor == 'postgresql', 'PostgreSQL tests.')
+class OperationsTests(SimpleTestCase):
+
+    def test_prepare_tzname_delta(self):
+        """
+        _prepare_tzname_delta() should not flip the sign of named time zones.
+        """
+        ops = connection.ops
+        self.assertEqual(ops._prepare_tzname_delta('Etc/GMT-10'), 'Etc/GMT-10')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/timezone\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 db.backends.postgresql.test_operations
cat coverage.cover
git checkout d89f976bddb49fb168334960acc8979c3de991fa
git apply /root/pre_state.patch
