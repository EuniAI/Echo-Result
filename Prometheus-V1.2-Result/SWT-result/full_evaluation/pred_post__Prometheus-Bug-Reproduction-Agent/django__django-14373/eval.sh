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
diff --git a/django/utils/dateformat.py b/django/utils/dateformat.py
--- a/django/utils/dateformat.py
+++ b/django/utils/dateformat.py
@@ -313,8 +313,8 @@ def y(self):
         return '%02d' % (self.data.year % 100)
 
     def Y(self):
-        "Year, 4 digits; e.g. '1999'"
-        return self.data.year
+        """Year, 4 digits with leading zeros; e.g. '1999'."""
+        return '%04d' % self.data.year
 
     def z(self):
         """Day of the year, i.e. 1 to 366."""

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils_tests/test_dateformat_padding.py b/tests/utils_tests/test_dateformat_padding.py
new file mode 100644
index 0000000000..d96d758ca2
--- /dev/null
+++ b/tests/utils_tests/test_dateformat_padding.py
@@ -0,0 +1,22 @@
+from datetime import datetime
+
+from django.test import SimpleTestCase, override_settings
+from django.utils import dateformat, translation
+
+
+@override_settings(TIME_ZONE='Europe/Copenhagen')
+class DateFormatTests(SimpleTestCase):
+
+    def setUp(self):
+        self._orig_lang = translation.get_language()
+        translation.activate('en-us')
+
+    def tearDown(self):
+        translation.activate(self._orig_lang)
+
+    def test_Y_format_year_before_1000(self):
+        """
+        The Y specifier should be padded with zeros for years < 1000.
+        """
+        d = datetime(42, 9, 8, 5, 0)
+        self.assertEqual(dateformat.format(d, 'Y'), '0042')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/dateformat\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_dateformat_padding
cat coverage.cover
git checkout b1a4b1f0bdf05adbd3dc4dde14228e68da54c1a3
git apply /root/pre_state.patch
