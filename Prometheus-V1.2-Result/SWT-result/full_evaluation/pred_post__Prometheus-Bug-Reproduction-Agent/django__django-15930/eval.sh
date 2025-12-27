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
diff --git a/tests/expressions_case/test_negated_empty_in_clause.py b/tests/expressions_case/test_negated_empty_in_clause.py
new file mode 100644
index 0000000000..e6a60b0447
--- /dev/null
+++ b/tests/expressions_case/test_negated_empty_in_clause.py
@@ -0,0 +1,30 @@
+import unittest
+
+from django.db.models import BooleanField, Case, Q, Value, When
+from django.test import TestCase
+
+from .models import CaseTestModel
+
+
+class NegatedEmptyInClauseTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        CaseTestModel.objects.create(integer=1)
+        CaseTestModel.objects.create(integer=2)
+
+    def test_negated_empty_in_clause_in_when(self):
+        """
+        Test that ~Q(pk__in=[]) is handled correctly as a When()
+        condition.
+        """
+        annotated_qs = CaseTestModel.objects.annotate(
+            a=Case(
+                When(~Q(pk__in=[]), then=Value(True)),
+                default=Value(False),
+                output_field=BooleanField(),
+            )
+        ).order_by("-a")
+        # This will execute the query which fails before the fix.
+        # After the fix, it should return all objects, and all of them
+        # should have `a` set to True.
+        self.assertFalse(annotated_qs.filter(a=False).exists())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions_case.test_negated_empty_in_clause
cat coverage.cover
git checkout 63884829acd207404f2a5c3cc1d6b4cd0a822b70
git apply /root/pre_state.patch
