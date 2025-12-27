#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 27c09043da52ca1f02605bf28600bfd5ace95ae4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 27c09043da52ca1f02605bf28600bfd5ace95ae4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_db_cache_cull_bug.py b/tests/test_db_cache_cull_bug.py
new file mode 100644
index 0000000000..a73c5c077a
--- /dev/null
+++ b/tests/test_db_cache_cull_bug.py
@@ -0,0 +1,52 @@
+import unittest
+
+from django.core import management
+from django.core.cache import caches
+from django.db import connection
+from django.test import TransactionTestCase, override_settings
+
+
+@override_settings(
+    CACHES={
+        "default": {
+            "BACKEND": "django.core.cache.backends.db.DatabaseCache",
+            "LOCATION": "test_cache_cull_bug_table",
+            "OPTIONS": {
+                "MAX_ENTRIES": 10,
+                "CULL_FREQUENCY": 1,
+            },
+        }
+    }
+)
+class DBCacheCullBugTest(TransactionTestCase):
+    def setUp(self):
+        super().setUp()
+        self.cache = caches["default"]
+        management.call_command("createcachetable", verbosity=0)
+
+    def tearDown(self):
+        table_name = self.cache._table
+        with connection.cursor() as cursor:
+            cursor.execute(f"DROP TABLE {connection.ops.quote_name(table_name)}")
+        super().tearDown()
+
+    def test_cull_with_frequency_one_triggers_bug(self):
+        """
+        Test that culling with CULL_FREQUENCY=1 triggers a TypeError
+        when the number of items to cull equals the total number of items.
+        """
+        # Add MAX_ENTRIES + 1 items to the cache. This brings the number of
+        # items to 11, which is one over the limit.
+        for i in range(11):
+            # Use leading zeros for predictable sorting of keys.
+            self.cache.set(f"key-{i:02d}", f"value-{i}")
+
+        # This 12th call to set() triggers the culling process because the
+        # number of entries (11) is greater than MAX_ENTRIES (10).
+        # In _cull, cull_num becomes 11 // 1 = 11. The culling query with
+        # OFFSET 11 on a table with 11 rows returns no results.
+        # `cursor.fetchone()` returns `None`, and `None[0]` raises a
+        # TypeError. This unhandled exception will cause the test to fail.
+        # After the bug is fixed, this line will execute without error, and
+        # the test will pass.
+        self.cache.set("key-11", "value-11")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/cache/backends/db\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_db_cache_cull_bug
cat coverage.cover
git checkout 27c09043da52ca1f02605bf28600bfd5ace95ae4
git apply /root/pre_state.patch
