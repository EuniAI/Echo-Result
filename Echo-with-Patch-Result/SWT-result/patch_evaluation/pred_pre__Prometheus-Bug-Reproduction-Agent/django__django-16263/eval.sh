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
diff --git a/regression_tests/test_strip_unused_annotations.py b/regression_tests/test_strip_unused_annotations.py
new file mode 100644
index 0000000000..9ea233975e
--- /dev/null
+++ b/regression_tests/test_strip_unused_annotations.py
@@ -0,0 +1,29 @@
+from django.db import connection
+from django.db.models import Count
+from django.test import TestCase
+from django.test.utils import CaptureQueriesContext
+
+from .models import Book, Chapter
+
+
+class StripUnusedAnnotationsTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        book = Book.objects.create(name="The Unused Annotation")
+        Chapter.objects.create(title="Chapter 1", book=book)
+
+    def test_unused_annotation_is_stripped_from_count(self):
+        """
+        An annotation that is not used by any other part of the query should
+        be stripped from a .count() call.
+        """
+        with CaptureQueriesContext(connection) as queries:
+            annotated_qs = Book.objects.annotate(chapters_count=Count("chapter"))
+            self.assertEqual(annotated_qs.count(), 1)
+        annotated_sql = queries[0]["sql"]
+
+        with CaptureQueriesContext(connection) as queries_simple:
+            self.assertEqual(Book.objects.count(), 1)
+        simple_sql = queries_simple[0]["sql"]
+
+        self.assertEqual(annotated_sql, simple_sql)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py|django/db/models/sql/where\.py|django/db/models/sql/query\.py|django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 regression_tests.test_strip_unused_annotations
cat coverage.cover
git checkout 321ecb40f4da842926e1bc07e11df4aabe53ca4b
git apply /root/pre_state.patch
