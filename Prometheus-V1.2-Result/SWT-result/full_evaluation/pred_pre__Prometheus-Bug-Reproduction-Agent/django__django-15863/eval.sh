#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 37c5b8c07be104fd5288cd87f101e48cb7a40298 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 37c5b8c07be104fd5288cd87f101e48cb7a40298
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_floatformat_precision.py b/tests/template_tests/filter_tests/test_floatformat_precision.py
new file mode 100644
index 0000000000..346d06e953
--- /dev/null
+++ b/tests/template_tests/filter_tests/test_floatformat_precision.py
@@ -0,0 +1,15 @@
+from decimal import Decimal
+
+from django.template.defaultfilters import floatformat
+from django.test import SimpleTestCase
+
+
+class FunctionTests(SimpleTestCase):
+    def test_decimal_high_precision(self):
+        """
+        Test that floatformat doesn't drop precision for high-precision
+        Decimal numbers.
+        """
+        value = Decimal("42.12345678901234567890")
+        result = floatformat(value, 20)
+        self.assertEqual(result, "42.12345678901234567890")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.filter_tests.test_floatformat_precision
cat coverage.cover
git checkout 37c5b8c07be104fd5288cd87f101e48cb7a40298
git apply /root/pre_state.patch
