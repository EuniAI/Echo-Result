#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 30613d6a748fce18919ff8b0da166d9fda2ed9bc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 30613d6a748fce18919ff8b0da166d9fda2ed9bc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions/test_value.py b/tests/expressions/test_value.py
new file mode 100644
index 0000000000..90a3015722
--- /dev/null
+++ b/tests/expressions/test_value.py
@@ -0,0 +1,14 @@
+from django.db.models import Value
+from django.test import SimpleTestCase
+
+
+class ValueExpressionTests(SimpleTestCase):
+
+    def test_resolve_output_field_char_validator(self):
+        """
+        Value._resolve_output_field() shouldn't add a MaxLengthValidator to a
+        CharField.
+        """
+        value = Value('test')
+        output_field = value.resolve_expression(None).output_field
+        self.assertEqual(output_field.validators, [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.test_value
cat coverage.cover
git checkout 30613d6a748fce18919ff8b0da166d9fda2ed9bc
git apply /root/pre_state.patch
