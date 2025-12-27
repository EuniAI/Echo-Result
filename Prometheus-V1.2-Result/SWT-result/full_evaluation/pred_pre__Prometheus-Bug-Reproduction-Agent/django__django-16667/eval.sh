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
diff --git a/tests/forms_tests/widget_tests/test_selectdatewidget_overflow.py b/tests/forms_tests/widget_tests/test_selectdatewidget_overflow.py
new file mode 100644
index 0000000000..16446c2512
--- /dev/null
+++ b/tests/forms_tests/widget_tests/test_selectdatewidget_overflow.py
@@ -0,0 +1,23 @@
+from django.forms import DateField, Form, SelectDateWidget
+from django.test import SimpleTestCase
+
+
+class SelectDateWidgetTest(SimpleTestCase):
+    def test_value_from_datadict_overflow(self):
+        """
+        SelectDateWidget.value_from_datadict() should not crash on invalid
+        (overflowing) date values.
+        """
+
+        class ReproForm(Form):
+            my_date = DateField(widget=SelectDateWidget)
+
+        form = ReproForm(
+            {
+                "my_date_day": "1",
+                "my_date_month": "1",
+                "my_date_year": "1234567821345678",
+            }
+        )
+        self.assertFalse(form.is_valid())
+        self.assertEqual(form.errors, {"my_date": ["Enter a valid date."]})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.widget_tests.test_selectdatewidget_overflow
cat coverage.cover
git checkout 02c356f2f3945b8075735d485c3cf48cad991011
git apply /root/pre_state.patch
