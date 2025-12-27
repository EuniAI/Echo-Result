#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 76e0151ea0e0f56dca66cee846a78b89346d2c4c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 76e0151ea0e0f56dca66cee846a78b89346d2c4c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/db_functions/datetime/test_trunc_with_tzinfo.py b/tests/db_functions/datetime/test_trunc_with_tzinfo.py
new file mode 100644
index 0000000000..0edfe2ae8f
--- /dev/null
+++ b/tests/db_functions/datetime/test_trunc_with_tzinfo.py
@@ -0,0 +1,46 @@
+from datetime import date, datetime, time
+
+import pytz
+
+from django.db.models.functions import TruncDate, TruncTime
+from django.test import TestCase, override_settings
+from django.utils import timezone
+
+from ..models import DTModel
+
+
+class TruncWithTZInfoTest(TestCase):
+    def create_model(self, start_datetime, end_datetime):
+        return DTModel.objects.create(
+            name=start_datetime.isoformat() if start_datetime else 'None',
+            start_datetime=start_datetime,
+            end_datetime=end_datetime,
+            start_date=start_datetime.date() if start_datetime else None,
+            end_date=end_datetime.date() if end_datetime else None,
+            start_time=start_datetime.time() if start_datetime else None,
+            end_time=end_datetime.time() if end_datetime else None,
+            duration=(end_datetime - start_datetime) if start_datetime and end_datetime else None,
+        )
+
+    @override_settings(USE_TZ=True, TIME_ZONE='Europe/Berlin')
+    def test_trunc_date_and_time_with_tzinfo(self):
+        """
+        TruncDate and TruncTime should respect the tzinfo parameter and not
+        unconditionally use the current timezone.
+        """
+        # This datetime is in the 'Europe/Berlin' timezone (UTC+1).
+        # In UTC, this is 2019-12-31 23:30:00.
+        berlin_datetime = timezone.make_aware(datetime(2020, 1, 1, 0, 30))
+        self.create_model(berlin_datetime, berlin_datetime)
+
+        utc_tz = pytz.timezone('UTC')
+        obj = DTModel.objects.annotate(
+            truncated_date=TruncDate('start_datetime', tzinfo=utc_tz),
+            truncated_time=TruncTime('start_datetime', tzinfo=utc_tz),
+        ).get()
+
+        # The bug causes truncation to happen in the current timezone ('Europe/Berlin')
+        # which would result in date(2020, 1, 1) and time(0, 30).
+        # The correct behavior is to use the provided tzinfo (UTC).
+        self.assertEqual(obj.truncated_date, date(2019, 12, 31))
+        self.assertEqual(obj.truncated_time, time(23, 30))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/functions/datetime\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 db_functions.datetime.test_trunc_with_tzinfo
cat coverage.cover
git checkout 76e0151ea0e0f56dca66cee846a78b89346d2c4c
git apply /root/pre_state.patch
