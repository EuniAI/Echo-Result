#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c84b91b7603e488f7171fdff8f08368ef3d6b856 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c84b91b7603e488f7171fdff8f08368ef3d6b856
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/timezones/test_database_timezone.py b/tests/timezones/test_database_timezone.py
new file mode 100644
index 0000000000..32b4070d69
--- /dev/null
+++ b/tests/timezones/test_database_timezone.py
@@ -0,0 +1,55 @@
+import datetime
+from contextlib import contextmanager
+
+import pytz
+
+from django.db import connection
+from django.test import TestCase, override_settings, skipIfDBFeature
+from django.utils import timezone
+
+from .models import Event
+
+
+@skipIfDBFeature('supports_timezones')
+class DatabaseTimeZoneTests(TestCase):
+    """
+    Tests for timezone conversions on databases without native timezone
+    support.
+    """
+    @contextmanager
+    def override_database_connection_timezone(self, timezone_name):
+        original_timezone = connection.settings_dict['TIME_ZONE']
+        connection.settings_dict['TIME_ZONE'] = timezone_name
+        # Invalidate cached properties.
+        for attr in ('timezone', 'timezone_name'):
+            if hasattr(connection, attr):
+                delattr(connection, attr)
+        try:
+            yield
+        finally:
+            connection.settings_dict['TIME_ZONE'] = original_timezone
+            for attr in ('timezone', 'timezone_name'):
+                if hasattr(connection, attr):
+                    delattr(connection, attr)
+
+    @override_settings(USE_TZ=True)
+    def test_date_lookup_with_database_timezone(self):
+        """
+        A __date lookup on a DateTimeField should use the database's
+        TIME_ZONE for conversion, not UTC.
+        """
+        app_timezone_name = 'Europe/Paris'
+        tz = pytz.timezone(app_timezone_name)
+
+        with override_settings(TIME_ZONE=app_timezone_name):
+            with self.override_database_connection_timezone(app_timezone_name):
+                # Use a time late in the evening. In 'Europe/Paris' (UTC+2 in
+                # summer), 23:00 is 21:00 UTC. The buggy query will treat the
+                # stored '23:00' as UTC and convert it to 'Europe/Paris',
+                # resulting in a time of 01:00 on the next day.
+                dt = tz.localize(datetime.datetime(2017, 7, 6, 23, 0))
+                Event.objects.create(dt=dt)
+
+                # The bug causes the date in the WHERE clause to be calculated
+                # incorrectly (as the next day), so the query returns no results.
+                self.assertTrue(Event.objects.filter(dt__date=dt.date()).exists())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/mysql/operations\.py|django/db/backends/sqlite3/operations\.py|django/db/backends/oracle/operations\.py|django/db/backends/sqlite3/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 timezones.test_database_timezone
cat coverage.cover
git checkout c84b91b7603e488f7171fdff8f08368ef3d6b856
git apply /root/pre_state.patch
