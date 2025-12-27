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
diff --git a/tests/utils_tests/test_http_date_parsing.py b/tests/utils_tests/test_http_date_parsing.py
new file mode 100644
index 0000000000..3a46eef87b
--- /dev/null
+++ b/tests/utils_tests/test_http_date_parsing.py
@@ -0,0 +1,23 @@
+import unittest
+from datetime import datetime
+from unittest.mock import patch
+
+from django.utils.http import parse_http_date
+
+
+class HttpDateProcessingTests(unittest.TestCase):
+    @patch('time.time', return_value=datetime(2022, 1, 1).timestamp())
+    def test_rfc850_two_digit_year(self, mock_time):
+        """
+        Test RFC 850 date parsing with a two-digit year.
+
+        Recipients of a timestamp with a two-digit year must interpret a
+        timestamp that appears to be more than 50 years in the future as
+        representing the most recent year in the past that had the same
+        last two digits.
+        """
+        # With the current time mocked to 2022, a two-digit year of '71'
+        # should be interpreted as 2071, as this is not more than 50 years in
+        # the future. The current implementation incorrectly parses it as 1971.
+        parsed_date = parse_http_date('Sunday, 06-Nov-71 08:49:37 GMT')
+        self.assertEqual(datetime.utcfromtimestamp(parsed_date), datetime(2071, 11, 6, 8, 49, 37))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/http\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_http_date_parsing
cat coverage.cover
git checkout f0adf3b9b7a19cdee05368ff0c0c2d087f011180
git apply /root/pre_state.patch
