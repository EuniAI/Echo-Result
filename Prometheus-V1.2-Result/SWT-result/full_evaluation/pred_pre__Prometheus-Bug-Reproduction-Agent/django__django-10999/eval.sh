#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 36300ef336e3f130a0dadc1143163ff3d23dc843 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 36300ef336e3f130a0dadc1143163ff3d23dc843
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils_tests/test_parse_duration.py b/tests/utils_tests/test_parse_duration.py
new file mode 100644
index 0000000000..0404b206ac
--- /dev/null
+++ b/tests/utils_tests/test_parse_duration.py
@@ -0,0 +1,16 @@
+import unittest
+from datetime import timedelta
+
+from django.utils.dateparse import parse_duration
+
+
+class DurationParseTests(unittest.TestCase):
+    def test_parse_negative_duration_with_negative_components(self):
+        """
+        Test parsing of negative durations where all components are negative.
+        This was failing due to a regex issue in the lookahead for hours.
+        """
+        self.assertEqual(
+            parse_duration('-1:-15:-30'),
+            timedelta(hours=-1, minutes=-15, seconds=-30)
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/dateparse\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_parse_duration
cat coverage.cover
git checkout 36300ef336e3f130a0dadc1143163ff3d23dc843
git apply /root/pre_state.patch
