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
diff --git a/django/template/defaultfilters.py b/django/template/defaultfilters.py
--- a/django/template/defaultfilters.py
+++ b/django/template/defaultfilters.py
@@ -149,7 +149,7 @@ def floatformat(text, arg=-1):
             use_l10n = False
             arg = arg[:-1] or -1
     try:
-        input_val = repr(text)
+        input_val = str(text)
         d = Decimal(input_val)
     except InvalidOperation:
         try:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_floatformat_decimal_precision.py b/tests/test_floatformat_decimal_precision.py
new file mode 100644
index 0000000000..0fdd91091a
--- /dev/null
+++ b/tests/test_floatformat_decimal_precision.py
@@ -0,0 +1,14 @@
+from decimal import Decimal
+
+from django.template.defaultfilters import floatformat
+from django.test import SimpleTestCase
+
+
+class FloatformatDecimalPrecisionTests(SimpleTestCase):
+    def test_decimal_precision(self):
+        """
+        floatformat should not lose precision on Decimal numbers.
+        """
+        value = Decimal("42.12345678901234567890")
+        output = floatformat(value, 20)
+        self.assertEqual(output, "42.12345678901234567890")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_floatformat_decimal_precision
cat coverage.cover
git checkout 37c5b8c07be104fd5288cd87f101e48cb7a40298
git apply /root/pre_state.patch
