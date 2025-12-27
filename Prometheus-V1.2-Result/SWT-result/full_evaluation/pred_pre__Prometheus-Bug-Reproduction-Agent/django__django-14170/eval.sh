#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6efc35b4fe3009666e56a60af0675d7d532bf4ff >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6efc35b4fe3009666e56a60af0675d7d532bf4ff
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/db_functions/datetime/test_iso_year.py b/tests/db_functions/datetime/test_iso_year.py
new file mode 100644
index 0000000000..df4efadd2d
--- /dev/null
+++ b/tests/db_functions/datetime/test_iso_year.py
@@ -0,0 +1,62 @@
+import pytz
+from datetime import datetime, timedelta, timezone as datetime_timezone
+
+try:
+    import zoneinfo
+except ImportError:
+    try:
+        from backports import zoneinfo
+    except ImportError:
+        zoneinfo = None
+
+from django.conf import settings
+from django.db.models import (
+    DateField, DateTimeField, F, IntegerField, Max, OuterRef, Subquery,
+    TimeField,
+)
+from django.db.models.functions import (
+    Extract, ExtractDay, ExtractHour, ExtractIsoWeekDay, ExtractIsoYear,
+    ExtractMinute, ExtractMonth, ExtractQuarter, ExtractSecond, ExtractWeek,
+    ExtractWeekDay, ExtractYear, Trunc, TruncDate, TruncDay, TruncHour,
+    TruncMinute, TruncMonth, TruncQuarter, TruncSecond, TruncTime, TruncWeek,
+    TruncYear,
+)
+from django.test import (
+    TestCase, override_settings, skipIfDBFeature, skipUnlessDBFeature,
+)
+from django.utils import timezone
+
+from ..models import Author, DTModel, Fan
+
+ZONE_CONSTRUCTORS = (pytz.timezone,)
+if zoneinfo is not None:
+    ZONE_CONSTRUCTORS += (zoneinfo.ZoneInfo,)
+
+
+@override_settings(USE_TZ=False)
+class DateFunctionTests(TestCase):
+
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
+    def test_filter_iso_year_on_boundary(self):
+        """
+        The __iso_year lookup must use EXTRACT and not the BETWEEN optimization
+        used by the __year lookup.
+        """
+        # 2021-01-01 is a Friday, so it belongs to ISO year 2020.
+        start_datetime = datetime(2021, 1, 1)
+        self.create_model(start_datetime, start_datetime)
+        # A filter for iso_year=2021 should not include this date. The faulty
+        # BETWEEN optimization would include it.
+        qs = DTModel.objects.filter(start_datetime__iso_year=2021)
+        self.assertEqual(qs.count(), 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/lookups\.py|django/db/backends/base/operations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 db_functions.datetime.test_iso_year
cat coverage.cover
git checkout 6efc35b4fe3009666e56a60af0675d7d532bf4ff
git apply /root/pre_state.patch
