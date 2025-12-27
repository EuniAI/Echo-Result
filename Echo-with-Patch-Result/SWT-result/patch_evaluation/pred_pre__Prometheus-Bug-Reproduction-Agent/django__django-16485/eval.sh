#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 39f83765e12b0e5d260b7939fc3fe281d879b279 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 39f83765e12b0e5d260b7939fc3fe281d879b279
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/regression_tests/test_floatformat_zero_precision.py b/tests/regression_tests/test_floatformat_zero_precision.py
new file mode 100644
index 0000000000..f4b3a522c9
--- /dev/null
+++ b/tests/regression_tests/test_floatformat_zero_precision.py
@@ -0,0 +1,12 @@
+from decimal import Decimal
+
+from django.template.defaultfilters import floatformat
+from django.test import SimpleTestCase
+
+
+class FunctionTests(SimpleTestCase):
+    def test_floatformat_decimal_zero_with_zero_precision(self):
+        """
+        floatformat(Decimal('0.00'), 0) should return '0', not raise ValueError.
+        """
+        self.assertEqual(floatformat(Decimal("0.00"), 0), "0")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 regression_tests.test_floatformat_zero_precision
cat coverage.cover
git checkout 39f83765e12b0e5d260b7939fc3fe281d879b279
git apply /root/pre_state.patch
