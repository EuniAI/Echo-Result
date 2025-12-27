#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 770d3e6a4ce8e0a91a9e27156036c1985e74d4a3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 770d3e6a4ce8e0a91a9e27156036c1985e74d4a3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/expressions.py b/django/db/models/expressions.py
--- a/django/db/models/expressions.py
+++ b/django/db/models/expressions.py
@@ -1211,13 +1211,18 @@ def __invert__(self):
 
     def as_sql(self, compiler, connection, template=None, **extra_context):
         query = self.query.exists(using=connection.alias)
-        sql, params = super().as_sql(
-            compiler,
-            connection,
-            template=template,
-            query=query,
-            **extra_context,
-        )
+        try:
+            sql, params = super().as_sql(
+                compiler,
+                connection,
+                template=template,
+                query=query,
+                **extra_context,
+            )
+        except EmptyResultSet:
+            if self.negated:
+                return '', ()
+            raise
         if self.negated:
             sql = 'NOT {}'.format(sql)
         return sql, params

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_negated_exists.py b/tests/queries/test_negated_exists.py
new file mode 100644
index 0000000000..9fcf25c8ad
--- /dev/null
+++ b/tests/queries/test_negated_exists.py
@@ -0,0 +1,25 @@
+from django.db.models import Exists
+from django.test import TestCase
+
+from .models import SimpleCategory
+
+
+class NegatedExistsEmptyQuerysetFilterTests(TestCase):
+    def test_negated_exists_none_with_other_filters(self):
+        """
+        Tests that a negated Exists(subquery) with an empty queryset
+        doesn't result in an EmptyResultSet, which would incorrectly
+        make the query return no results.
+        """
+        # Create an object that should be found by the query.
+        category = SimpleCategory.objects.create(name='test')
+
+        # This query is the subject of the bug.
+        # ~Exists(empty_queryset) should always be TRUE, so this
+        # should be equivalent to SimpleCategory.objects.filter(name='test').
+        # The bug causes it to become an EmptyResultSet.
+        qs = SimpleCategory.objects.filter(~Exists(SimpleCategory.objects.none()), name='test')
+
+        # This assertion will fail if the bug is present (qs will be empty).
+        # It will pass when the bug is fixed.
+        self.assertSequenceEqual(qs, [category])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_negated_exists
cat coverage.cover
git checkout 770d3e6a4ce8e0a91a9e27156036c1985e74d4a3
git apply /root/pre_state.patch
