#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 63884829acd207404f2a5c3cc1d6b4cd0a822b70 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 63884829acd207404f2a5c3cc1d6b4cd0a822b70
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/expressions.py b/django/db/models/expressions.py
--- a/django/db/models/expressions.py
+++ b/django/db/models/expressions.py
@@ -1299,6 +1299,11 @@ def as_sql(self, compiler, connection, template=None, **extra_context):
         template_params = extra_context
         sql_params = []
         condition_sql, condition_params = compiler.compile(self.condition)
+        # Filters that match everything are handled as empty strings in the
+        # WHERE clause, but in a CASE WHEN expression they must use a predicate
+        # that's always True.
+        if condition_sql == "":
+            condition_sql, condition_params = compiler.compile(Value(True))
         template_params["condition"] = condition_sql
         sql_params.extend(condition_params)
         result_sql, result_params = compiler.compile(self.result)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_negated_empty_in_case.py b/tests/test_negated_empty_in_case.py
new file mode 100644
index 0000000000..044549a05d
--- /dev/null
+++ b/tests/test_negated_empty_in_case.py
@@ -0,0 +1,31 @@
+import unittest
+
+from django.db import models
+from django.db.models import BooleanField, Case, Q, Value, When
+from django.test import TestCase
+
+
+class Author(models.Model):
+    name = models.CharField(max_length=50)
+
+
+class NegatedEmptyInCaseTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        Author.objects.create(name="John Smith")
+
+    def test_negated_empty_in_with_case(self):
+        """
+        A When() with a condition that is always true, such as ~Q(pk__in=[]),
+        should not generate an empty WHEN clause.
+        """
+        authors = Author.objects.annotate(
+            test=Case(
+                When(~Q(pk__in=[]), then=Value(True)),
+                default=Value(False),
+                output_field=BooleanField(),
+            )
+        )
+        # The query fails with a ProgrammingError before the fix.
+        # The assertion checks that the annotation has the correct value.
+        self.assertIs(authors.first().test, True)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_negated_empty_in_case
cat coverage.cover
git checkout 63884829acd207404f2a5c3cc1d6b4cd0a822b70
git apply /root/pre_state.patch
