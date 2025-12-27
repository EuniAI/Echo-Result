#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 321ecb40f4da842926e1bc07e11df4aabe53ca4b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 321ecb40f4da842926e1bc07e11df4aabe53ca4b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/annotations/test_count_optimization.py b/tests/annotations/test_count_optimization.py
new file mode 100644
index 0000000000..2ae5497a67
--- /dev/null
+++ b/tests/annotations/test_count_optimization.py
@@ -0,0 +1,23 @@
+from django.db import connection
+from django.db.models import Count
+from django.test import TestCase
+from django.test.utils import CaptureQueriesContext
+
+from .models import Book
+
+
+class AnnotationTests(TestCase):
+    def test_unused_annotation_stripped_from_count(self):
+        """
+        Annotations that aren't referenced elsewhere in the query should be
+        removed from count() queries.
+        """
+        with CaptureQueriesContext(connection) as queries:
+            # The original bug report used Count('chapters'), but the test model
+            # has an 'authors' field which serves the same purpose for this test.
+            Book.objects.annotate(authors_count=Count("authors")).count()
+        # The unoptimized query will contain a JOIN on the authors table,
+        # which is not necessary for a simple count. This assertion will fail
+        # until the bug is fixed.
+        sql = queries[0]["sql"]
+        self.assertNotIn("JOIN", sql)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/where\.py|django/db/models/expressions\.py|django/db/models/query_utils\.py|django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 annotations.test_count_optimization
cat coverage.cover
git checkout 321ecb40f4da842926e1bc07e11df4aabe53ca4b
git apply /root/pre_state.patch
