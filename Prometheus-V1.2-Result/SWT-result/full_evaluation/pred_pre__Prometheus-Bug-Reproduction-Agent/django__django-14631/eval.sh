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
diff --git a/tests/forms_tests/tests/test_initial.py b/tests/forms_tests/tests/test_initial.py
new file mode 100644
index 0000000000..1f71bb94c7
--- /dev/null
+++ b/tests/forms_tests/tests/test_initial.py
@@ -0,0 +1,20 @@
+import datetime
+
+from django.forms import DateTimeField, Form
+from django.test import SimpleTestCase
+
+
+class CleanFieldsInitialTests(SimpleTestCase):
+    def test_datetime_clean_initial_callable_disabled(self):
+        """
+        form.cleaned_data[name] should be equal to form[name].initial for a
+        disabled field with a callable initial value.
+        """
+        initial_dt = lambda: datetime.datetime(2022, 1, 1, 12, 0, 0, 123)
+
+        class DateTimeForm(Form):
+            dt = DateTimeField(initial=initial_dt, disabled=True)
+
+        form = DateTimeForm({})
+        form.full_clean()
+        self.assertEqual(form.cleaned_data["dt"], form["dt"].initial)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/forms\.py|django/forms/boundfield\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.tests.test_initial
cat coverage.cover
git checkout 84400d2e9db7c51fee4e9bb04c028f665b8e7624
git apply /root/pre_state.patch
