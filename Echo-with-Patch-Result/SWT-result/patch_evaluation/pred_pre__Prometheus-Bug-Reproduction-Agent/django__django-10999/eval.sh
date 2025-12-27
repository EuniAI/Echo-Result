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
diff --git a/tests/test_dateparse.py b/tests/test_dateparse.py
new file mode 100644
index 0000000000..61e4528fee
--- /dev/null
+++ b/tests/test_dateparse.py
@@ -0,0 +1,17 @@
+import datetime
+import unittest
+
+from django.test import SimpleTestCase
+from django.utils.dateparse import parse_duration
+
+
+class DateParseTests(SimpleTestCase):
+    def test_parse_duration_negative_components(self):
+        """
+        parse_duration() should handle negative components in HH:MM:SS format.
+        This fails before the fix because the lookahead in standard_duration_re
+        for hours doesn't account for negative minutes and seconds.
+        """
+        duration_string = '-01:-02:-03'
+        expected_timedelta = datetime.timedelta(hours=-1, minutes=-2, seconds=-3)
+        self.assertEqual(parse_duration(duration_string), expected_timedelta)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/dateparse\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_dateparse
cat coverage.cover
git checkout 36300ef336e3f130a0dadc1143163ff3d23dc843
git apply /root/pre_state.patch
