#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 02c356f2f3945b8075735d485c3cf48cad991011 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 02c356f2f3945b8075735d485c3cf48cad991011
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_selectdatewidget.py b/tests/test_selectdatewidget.py
new file mode 100644
index 0000000000..ed593c0b78
--- /dev/null
+++ b/tests/test_selectdatewidget.py
@@ -0,0 +1,20 @@
+from datetime import date
+
+from django.forms import Form, SelectDateWidget
+from django.test import SimpleTestCase
+
+
+class SelectDateWidgetTest(SimpleTestCase):
+    def test_value_from_datadict_overflow(self):
+        """
+        SelectDateWidget.value_from_datadict() shouldn't crash on a date
+        with a year that causes an OverflowError.
+        """
+        widget = SelectDateWidget()
+        data = {
+            "mydate_day": "1",
+            "mydate_month": "1",
+            "mydate_year": "1234567821345678",
+        }
+        value = widget.value_from_datadict(data, {}, "mydate")
+        self.assertEqual(value, "1234567821345678-1-1")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_selectdatewidget
cat coverage.cover
git checkout 02c356f2f3945b8075735d485c3cf48cad991011
git apply /root/pre_state.patch
