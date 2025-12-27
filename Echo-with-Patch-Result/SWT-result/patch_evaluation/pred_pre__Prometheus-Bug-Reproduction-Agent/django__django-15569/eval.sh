#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 884b4c27f506b3c29d58509fc83a35c30ea10d94 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 884b4c27f506b3c29d58509fc83a35c30ea10d94
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_lookup_cache.py b/tests/test_lookup_cache.py
new file mode 100644
index 0000000000..db6d61e277
--- /dev/null
+++ b/tests/test_lookup_cache.py
@@ -0,0 +1,26 @@
+from django.db.models import CharField
+from django.db.models.lookups import Lookup
+from django.test import SimpleTestCase
+from django.test.utils import register_lookup
+
+
+class LookupCacheTests(SimpleTestCase):
+    def test_unregister_lookup_clears_cache(self):
+        """
+        _unregister_lookup() should clear the lookup cache.
+        """
+        class MyLookup(Lookup):
+            lookup_name = "mylookup"
+
+        # Populate cache.
+        CharField.get_lookups()
+
+        with register_lookup(CharField, MyLookup):
+            # This call will cache the lookups, including the newly registered
+            # one.
+            self.assertIn("mylookup", CharField.get_lookups())
+
+        # The lookup is unregistered when the context manager exits.
+        # Before the fix, the cache is stale and still has the lookup.
+        # With the fix, the cache is cleared.
+        self.assertNotIn("mylookup", CharField.get_lookups())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_lookup_cache
cat coverage.cover
git checkout 884b4c27f506b3c29d58509fc83a35c30ea10d94
git apply /root/pre_state.patch
