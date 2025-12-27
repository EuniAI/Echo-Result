#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f0adf3b9b7a19cdee05368ff0c0c2d087f011180 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f0adf3b9b7a19cdee05368ff0c0c2d087f011180
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/http/test_dates.py b/tests/http/test_dates.py
new file mode 100644
index 0000000000..2c90318f99
--- /dev/null
+++ b/tests/http/test_dates.py
@@ -0,0 +1,30 @@
+import unittest
+from datetime import datetime
+
+from django.test import SimpleTestCase
+from django.utils.http import parse_http_date
+
+
+class HttpDateProcessingTests(SimpleTestCase):
+    def test_rfc850_two_digit_year_rolling_window(self):
+        """
+        Test that RFC 850 two-digit years use a rolling 50-year window.
+
+        This test relies on the current year to check the logic. The old
+        code used a fixed cutoff at the year 70, while the new code uses a
+        rolling 50-year window. By choosing a year like '71', we can
+        demonstrate the difference.
+        """
+        # As of any year from 1991-2040, the pivot year for the 50-year
+        # window will be > 71. For example, in 2024, the pivot is 74.
+        # The new logic will parse '71' as 2071.
+        # The old logic (`year < 70`) will parse '71' as 1971.
+        date_string = 'Saturday, 06-Nov-71 08:49:37 GMT'
+        parsed_timestamp = parse_http_date(date_string)
+
+        # This assertion will fail on the old code (which gives 1971) and
+        # pass on the new code (which gives 2071).
+        self.assertEqual(
+            datetime.utcfromtimestamp(parsed_timestamp),
+            datetime(2071, 11, 6, 8, 49, 37)
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/http\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 http.test_dates
cat coverage.cover
git checkout f0adf3b9b7a19cdee05368ff0c0c2d087f011180
git apply /root/pre_state.patch
