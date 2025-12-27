#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6c86495bcee22eac19d7fb040b2988b830707cbd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6c86495bcee22eac19d7fb040b2988b830707cbd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils_tests/test_timesince_long_interval.py b/tests/utils_tests/test_timesince_long_interval.py
new file mode 100644
index 0000000000..e8da194bf4
--- /dev/null
+++ b/tests/utils_tests/test_timesince_long_interval.py
@@ -0,0 +1,19 @@
+import datetime
+
+from django.test import SimpleTestCase
+from django.test.utils import override_settings, requires_tz_support
+from django.utils import timezone
+from django.utils.timesince import timesince
+
+
+class TimesinceTests(SimpleTestCase):
+    @requires_tz_support
+    @override_settings(USE_TZ=True)
+    def test_long_interval_with_tz(self):
+        """
+        Test that timesince() works correctly for intervals > 1 month
+        with USE_TZ=True, and doesn't raise a TypeError.
+        """
+        now = timezone.now()
+        d = now - datetime.timedelta(days=31)
+        self.assertEqual(timesince(d), "1\xa0month")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/timesince\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_timesince_long_interval
cat coverage.cover
git checkout 6c86495bcee22eac19d7fb040b2988b830707cbd
git apply /root/pre_state.patch
