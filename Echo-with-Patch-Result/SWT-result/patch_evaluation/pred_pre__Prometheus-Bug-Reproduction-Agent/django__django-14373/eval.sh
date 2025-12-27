#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b1a4b1f0bdf05adbd3dc4dde14228e68da54c1a3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b1a4b1f0bdf05adbd3dc4dde14228e68da54c1a3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_dateformat.py b/tests/test_dateformat.py
new file mode 100644
index 0000000000..39e47f0e2e
--- /dev/null
+++ b/tests/test_dateformat.py
@@ -0,0 +1,15 @@
+import datetime
+
+from django.test import SimpleTestCase
+from django.utils.dateformat import DateFormat
+
+
+class DateFormatTests(SimpleTestCase):
+    def test_Y_specifier_year_less_than_1000(self):
+        """
+        The Y specifier for django.utils.dateformat.DateFormat should
+        return a four-digit year padded with zeros.
+        """
+        d = datetime.datetime(year=8, month=1, day=1)
+        df = DateFormat(d)
+        self.assertEqual(df.format('Y'), '0008')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/dateformat\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_dateformat
cat coverage.cover
git checkout b1a4b1f0bdf05adbd3dc4dde14228e68da54c1a3
git apply /root/pre_state.patch
