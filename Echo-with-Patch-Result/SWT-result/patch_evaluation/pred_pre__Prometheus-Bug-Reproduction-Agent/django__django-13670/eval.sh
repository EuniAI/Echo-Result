#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c448e614c60cc97c6194c62052363f4f501e0953 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c448e614c60cc97c6194c62052363f4f501e0953
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_dateformat.py b/tests/test_dateformat.py
new file mode 100644
index 0000000000..2c52f5e1e4
--- /dev/null
+++ b/tests/test_dateformat.py
@@ -0,0 +1,15 @@
+import datetime
+
+from django.test import SimpleTestCase
+from django.utils import dateformat
+
+
+class DateFormatTests(SimpleTestCase):
+
+    def test_y_format_year_less_than_10(self):
+        """
+        dateformat.y() should support years < 10, formatting them as two
+        digits with a leading zero.
+        """
+        dt = datetime.datetime(9, 4, 5, 6, 7)
+        self.assertEqual(dateformat.format(dt, 'y'), '09')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/dateformat\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_dateformat
cat coverage.cover
git checkout c448e614c60cc97c6194c62052363f4f501e0953
git apply /root/pre_state.patch
