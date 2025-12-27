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
diff --git a/django/db/models/functions/datetime.py b/django/db/models/functions/datetime.py
--- a/django/db/models/functions/datetime.py
+++ b/django/db/models/functions/datetime.py
@@ -292,7 +292,7 @@ class TruncDate(TruncBase):
     def as_sql(self, compiler, connection):
         # Cast to date rather than truncate to date.
         lhs, lhs_params = compiler.compile(self.lhs)
-        tzname = timezone.get_current_timezone_name() if settings.USE_TZ else None
+        tzname = self.get_tzname()
         sql = connection.ops.datetime_cast_date_sql(lhs, tzname)
         return sql, lhs_params
 
@@ -305,7 +305,7 @@ class TruncTime(TruncBase):
     def as_sql(self, compiler, connection):
         # Cast to time rather than truncate to time.
         lhs, lhs_params = compiler.compile(self.lhs)
-        tzname = timezone.get_current_timezone_name() if settings.USE_TZ else None
+        tzname = self.get_tzname()
         sql = connection.ops.datetime_cast_time_sql(lhs, tzname)
         return sql, lhs_params
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/db/models/functions/test_trunc_date_with_timezone.py b/tests/db/models/functions/test_trunc_date_with_timezone.py
new file mode 100644
index 0000000000..0b85fdf6e9
--- /dev/null
+++ b/tests/db/models/functions/test_trunc_date_with_timezone.py
@@ -0,0 +1,34 @@
+import datetime
+
+import pytz
+
+from django.db.models.functions import TruncDate
+from django.test import TestCase, override_settings, skipUnlessDBFeature
+from django.utils import timezone
+
+from ..models import DTModel
+
+
+@skipUnlessDBFeature('has_zoneinfo_database')
+@override_settings(USE_TZ=True, TIME_ZONE='UTC')
+class TruncDateWithTimezoneTests(TestCase):
+
+    def test_trunc_date_with_tzinfo(self):
+        """
+        TruncDate should respect the tzinfo parameter.
+        """
+        # This datetime is June 1st in UTC.
+        start_dt = timezone.make_aware(datetime.datetime(2021, 6, 1, 2, 30))
+        DTModel.objects.create(start_datetime=start_dt)
+
+        # In America/New_York (UTC-4), this datetime is May 31st.
+        tz = pytz.timezone('America/New_York')
+        obj = DTModel.objects.annotate(
+            trunc_date=TruncDate('start_datetime', tzinfo=tz),
+        ).get()
+
+        # The bug is that tzinfo is ignored, so the date is truncated using
+        # the active UTC timezone, returning June 1st. The correct behavior
+        # is to use the provided tzinfo, returning May 31st. This assertion
+        # will fail on the unpatched code, demonstrating the bug.
+        self.assertEqual(obj.trunc_date, datetime.date(2021, 5, 31))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/functions/datetime\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 db.models.functions.test_trunc_date_with_timezone
cat coverage.cover
git checkout 76e0151ea0e0f56dca66cee846a78b89346d2c4c
git apply /root/pre_state.patch
