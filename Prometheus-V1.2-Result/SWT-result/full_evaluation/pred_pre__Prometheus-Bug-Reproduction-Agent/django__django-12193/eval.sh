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
diff --git a/tests/postgres_tests/test_forms.py b/tests/postgres_tests/test_forms.py
new file mode 100644
index 0000000000..be02e40e2f
--- /dev/null
+++ b/tests/postgres_tests/test_forms.py
@@ -0,0 +1,43 @@
+import unittest
+from django import forms
+from django.test import SimpleTestCase
+
+try:
+    from django.contrib.postgres.forms import SplitArrayField
+except ImportError:
+    # If psycopg2 is not installed, this test will be skipped.
+    SplitArrayField = None
+
+
+# In the Django test suite, this would be `from . import PostgreSQLWidgetTestCase`.
+# For a self-contained example, SimpleTestCase is sufficient as no DB is needed.
+class PostgreSQLWidgetTestCase(SimpleTestCase):
+    pass
+
+
+@unittest.skipIf(SplitArrayField is None, 'psycopg2 is not installed')
+class TestSplitArrayFieldWidget(PostgreSQLWidgetTestCase):
+    def test_boolean_field_attrs_mutation(self):
+        """
+        SplitArrayField with a BooleanField should not have its attributes
+        mutated by the CheckboxInput widget when preparing the context.
+        """
+        class ArrayForm(forms.Form):
+            field = SplitArrayField(forms.BooleanField(required=False), size=2)
+
+        form = ArrayForm(initial={'field': [True, False]})
+        widget = form.fields['field'].widget
+
+        # Get the context data that would be passed to the template.
+        # This avoids the TemplateDoesNotExist error by not rendering the template.
+        context = widget.get_context(name='field', value=[True, False], attrs=None)
+
+        # The context for subwidgets is where the mutated 'checked' attribute appears.
+        subwidgets_context = context['widget']['subwidgets']
+
+        # The bug is that CheckboxInput.get_context() modifies the attrs
+        # dict. SplitArrayWidget reuses this dict, so after the first True
+        # value, 'checked' is present for all subsequent subwidgets.
+        # This assertion will fail because 'checked' will be in the attrs
+        # for the second widget, which corresponds to the 'False' value.
+        self.assertNotIn('checked', subwidgets_context[1]['attrs'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 postgres_tests.test_forms
cat coverage.cover
git checkout 3fb7c12158a2402f0f80824f6778112071235803
git apply /root/pre_state.patch
