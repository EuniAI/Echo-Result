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
diff --git a/tests/test_numberformat.py b/tests/test_numberformat.py
new file mode 100644
index 0000000000..3f60ac4af0
--- /dev/null
+++ b/tests/test_numberformat.py
@@ -0,0 +1,18 @@
+from decimal import Decimal
+
+from django.test import SimpleTestCase
+from django.utils.numberformat import format as nformat
+
+
+class TestNumberFormat(SimpleTestCase):
+
+    def test_small_decimal_no_scientific_notation(self):
+        """
+        Test that extremely small decimals do not render in scientific notation
+        when a specific decimal position is requested.
+        """
+        # The bug causes '1e-200' to be formatted as '1.00e-200'.
+        # The correct behavior is to format it as '0.00'.
+        # This assertion checks for the absence of the 'e' which indicates
+        # scientific notation.
+        self.assertNotIn('e', nformat(Decimal('1e-200'), '.', decimal_pos=2))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/numberformat\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_numberformat
cat coverage.cover
git checkout 571ab44e8a8936014c22e7eebe4948d9611fd7ce
git apply /root/pre_state.patch
