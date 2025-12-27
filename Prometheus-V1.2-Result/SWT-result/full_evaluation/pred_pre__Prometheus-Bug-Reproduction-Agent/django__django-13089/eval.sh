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
diff --git a/tests/cache/test_db_cache_cull_bug.py b/tests/cache/test_db_cache_cull_bug.py
new file mode 100644
index 0000000000..f3e077c30d
--- /dev/null
+++ b/tests/cache/test_db_cache_cull_bug.py
@@ -0,0 +1,57 @@
+from django.core import management
+from django.core.cache import cache
+from django.db import connection
+from django.test import TransactionTestCase, override_settings
+
+
+@override_settings(CACHES={
+    'default': {
+        'BACKEND': 'django.core.cache.backends.db.DatabaseCache',
+        'LOCATION': 'test_cache_table_cull_bug',
+        'OPTIONS': {
+            'MAX_ENTRIES': 2,
+            'CULL_FREQUENCY': 1,
+        },
+    },
+})
+class DBCacheCullBugTest(TransactionTestCase):
+    """
+    Tests for a TypeError in the database cache backend's _cull method.
+    """
+    available_apps = ['cache']
+
+    def setUp(self):
+        super().setUp()
+        management.call_command('createcachetable', verbosity=0)
+
+    def tearDown(self):
+        super().tearDown()
+        with connection.cursor() as cursor:
+            table_name = connection.ops.quote_name('test_cache_table_cull_bug')
+            cursor.execute(f'DROP TABLE {table_name}')
+
+    def test_cull_with_cull_frequency_of_one(self):
+        """
+        _cull() fails with a TypeError when CULL_FREQUENCY is 1 and the cache
+        is full.
+        """
+        # With MAX_ENTRIES = 2, these three calls fill the cache just enough
+        # so the next call to set() will trigger a cull.
+        cache.set('key1', 1)
+        cache.set('key2', 1)
+        cache.set('key3', 1)
+        # At this point, the table has 3 rows.
+
+        # This fourth call to set() triggers the bug.
+        # 1. _base_set() sees 3 rows, which is > MAX_ENTRIES (2), so it calls _cull().
+        # 2. _cull() counts 3 unexpired entries.
+        # 3. The offset for the culling query is calculated as int(3 / 1) = 3.
+        # 4. The culling query runs with OFFSET 3 on a table with 3 rows,
+        #    returning no results.
+        # 5. cursor.fetchone() returns None, and accessing fetchone()[0] raises
+        #    a TypeError.
+        cache.set('key4', 1)
+
+        # This assertion is the minimal check. It will only be reached if the
+        # bug is fixed and the cache.set() call above does not crash.
+        self.assertEqual(cache.get('key4'), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/cache/backends/db\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 cache.test_db_cache_cull_bug
cat coverage.cover
git checkout 27c09043da52ca1f02605bf28600bfd5ace95ae4
git apply /root/pre_state.patch
