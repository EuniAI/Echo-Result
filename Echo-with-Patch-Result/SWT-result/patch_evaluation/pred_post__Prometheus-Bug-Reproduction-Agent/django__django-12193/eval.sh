#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3fb7c12158a2402f0f80824f6778112071235803 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3fb7c12158a2402f0f80824f6778112071235803
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/widgets.py b/django/forms/widgets.py
--- a/django/forms/widgets.py
+++ b/django/forms/widgets.py
@@ -522,9 +522,7 @@ def format_value(self, value):
 
     def get_context(self, name, value, attrs):
         if self.check_test(value):
-            if attrs is None:
-                attrs = {}
-            attrs['checked'] = True
+            attrs = {**(attrs or {}), 'checked': True}
         return super().get_context(name, value, attrs)
 
     def value_from_datadict(self, data, files, name):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_postgres_splitarraywidget.py b/tests/test_postgres_splitarraywidget.py
new file mode 100644
index 0000000000..33b5d43ad4
--- /dev/null
+++ b/tests/test_postgres_splitarraywidget.py
@@ -0,0 +1,32 @@
+from django import forms
+from django.contrib.postgres.forms import SplitArrayWidget
+from django.test import SimpleTestCase, modify_settings
+
+
+class PostgreSQLWidgetTestCase(SimpleTestCase):
+    """
+    A base class for PostgreSQL widget tests.
+    """
+    pass
+
+
+class SplitArrayCheckboxWidgetTest(PostgreSQLWidgetTestCase):
+    @modify_settings(INSTALLED_APPS={'append': 'django.contrib.postgres'})
+    def test_checked_attribute_not_leaked_in_context(self):
+        """
+        The 'checked' attribute should not leak to subsequent subwidgets
+        in the context data.
+        """
+        widget = SplitArrayWidget(forms.CheckboxInput(), size=2)
+        context = widget.get_context(name='flags', value=[True, False], attrs=None)
+        subwidgets = context['widget']['subwidgets']
+
+        # The first subwidget for the `True` value should have a 'checked'
+        # attribute in its context.
+        self.assertIn('checked', subwidgets[0]['attrs'])
+        self.assertTrue(subwidgets[0]['attrs']['checked'])
+
+        # The second subwidget for the `False` value should NOT have a
+        # 'checked' attribute. This assertion will fail if the bug is present,
+        # as the attribute will have leaked from the previous widget.
+        self.assertNotIn('checked', subwidgets[1]['attrs'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_postgres_splitarraywidget
cat coverage.cover
git checkout 3fb7c12158a2402f0f80824f6778112071235803
git apply /root/pre_state.patch
