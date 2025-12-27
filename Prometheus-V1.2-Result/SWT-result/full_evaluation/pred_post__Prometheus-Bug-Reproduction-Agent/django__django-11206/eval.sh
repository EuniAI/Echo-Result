#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 571ab44e8a8936014c22e7eebe4948d9611fd7ce >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 571ab44e8a8936014c22e7eebe4948d9611fd7ce
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/numberformat.py b/django/utils/numberformat.py
--- a/django/utils/numberformat.py
+++ b/django/utils/numberformat.py
@@ -27,6 +27,14 @@ def format(number, decimal_sep, decimal_pos=None, grouping=0, thousand_sep='',
     # sign
     sign = ''
     if isinstance(number, Decimal):
+
+        if decimal_pos is not None:
+            # If the provided number is too small to affect any of the visible
+            # decimal places, consider it equal to '0'.
+            cutoff = Decimal('0.' + '1'.rjust(decimal_pos, '0'))
+            if abs(number) < cutoff:
+                number = Decimal('0')
+
         # Format values with more than 200 digits (an arbitrary cutoff) using
         # scientific notation to avoid high memory usage in {:f}'.format().
         _, digits, exponent = number.as_tuple()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils_tests/test_numberformat_regression.py b/tests/utils_tests/test_numberformat_regression.py
new file mode 100644
index 0000000000..a9d6960f1c
--- /dev/null
+++ b/tests/utils_tests/test_numberformat_regression.py
@@ -0,0 +1,14 @@
+from decimal import Decimal
+
+from django.test import SimpleTestCase
+from django.utils.numberformat import format as nformat
+
+
+class TestNumberFormat(SimpleTestCase):
+
+    def test_small_decimal_does_not_use_exponential_notation(self):
+        """
+        Extremely small numbers shouldn't be displayed in exponential
+        notation when a decimal_pos argument is provided.
+        """
+        self.assertEqual(nformat(Decimal('1e-200'), '.', decimal_pos=2), '0.00')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/numberformat\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_numberformat_regression
cat coverage.cover
git checkout 571ab44e8a8936014c22e7eebe4948d9611fd7ce
git apply /root/pre_state.patch
