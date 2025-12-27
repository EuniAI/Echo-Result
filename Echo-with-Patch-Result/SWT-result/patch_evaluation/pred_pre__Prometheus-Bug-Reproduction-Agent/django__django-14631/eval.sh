#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 84400d2e9db7c51fee4e9bb04c028f665b8e7624 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 84400d2e9db7c51fee4e9bb04c028f665b8e7624
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_field_clean_refactor.py b/tests/test_field_clean_refactor.py
new file mode 100644
index 0000000000..6e19321b53
--- /dev/null
+++ b/tests/test_field_clean_refactor.py
@@ -0,0 +1,26 @@
+import datetime
+
+from django import forms
+from django.test import SimpleTestCase
+
+
+class FieldCleanRefactorTests(SimpleTestCase):
+    def test_clean_fields_disabled_callable_initial(self):
+        """
+        form._clean_fields() should return the same value as form[name].initial
+        for disabled fields with a callable initial.
+        """
+        now = datetime.datetime(2021, 10, 25, 14, 30, 45, 123456)
+
+        class DateTimeForm(forms.Form):
+            dt = forms.DateTimeField(initial=lambda: now, disabled=True)
+
+        form = DateTimeForm({})
+        self.assertTrue(form.is_valid())
+        # Before the fix, form.cleaned_data['dt'] contains microseconds
+        # because _clean_fields() uses get_initial_for_field(), but
+        # form['dt'].initial strips them because the default widget for
+        # DateTimeField doesn't support them. This assertion will fail.
+        # After the fix, _clean_fields() uses bound_field.initial, so the
+        # values will match.
+        self.assertEqual(form.cleaned_data['dt'], form['dt'].initial)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/boundfield\.py|django/forms/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_field_clean_refactor
cat coverage.cover
git checkout 84400d2e9db7c51fee4e9bb04c028f665b8e7624
git apply /root/pre_state.patch
