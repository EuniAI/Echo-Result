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
diff --git a/django/db/models/query_utils.py b/django/db/models/query_utils.py
--- a/django/db/models/query_utils.py
+++ b/django/db/models/query_utils.py
@@ -217,6 +217,7 @@ def _unregister_lookup(cls, lookup, lookup_name=None):
         if lookup_name is None:
             lookup_name = lookup.lookup_name
         del cls.class_lookups[lookup_name]
+        cls._clear_cached_lookups()
 
 
 def select_related_descend(field, restricted, requested, load_fields, reverse=False):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/lookup/test_registration.py b/tests/lookup/test_registration.py
new file mode 100644
index 0000000000..aa90742f7f
--- /dev/null
+++ b/tests/lookup/test_registration.py
@@ -0,0 +1,33 @@
+from django.db import models
+from django.test import TestCase
+from django.test.utils import register_lookup
+
+from .models import Article
+
+
+class Exactly(models.lookups.Exact):
+    """
+    This lookup is used to test lookup registration.
+    """
+
+    lookup_name = "exactly"
+
+    def get_rhs_op(self, connection, rhs):
+        return connection.operators["exact"] % rhs
+
+
+class LookupTests(TestCase):
+    def test_unregister_lookup_clears_cache(self):
+        """
+        Test that _unregister_lookup clears the lookup cache.
+        """
+        field = Article._meta.get_field("author")
+        # Clear cache to ensure a clean state.
+        field.get_lookups.cache_clear()
+        self.assertNotIn("exactly", field.get_lookups())
+        # Register the lookup.
+        with register_lookup(models.ForeignObject, Exactly):
+            self.assertIn("exactly", field.get_lookups())
+        # After unregistering (by exiting the 'with' block), the lookup
+        # should no longer be present.
+        self.assertNotIn("exactly", field.get_lookups())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 lookup.test_registration
cat coverage.cover
git checkout 884b4c27f506b3c29d58509fc83a35c30ea10d94
git apply /root/pre_state.patch
