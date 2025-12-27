#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f8c43aca467b7b0c4bb0a7fa41362f90b610b8df >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f8c43aca467b7b0c4bb0a7fa41362f90b610b8df
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -403,6 +403,7 @@ def get_aggregation(self, using, aggregate_exprs):
         # Store annotation mask prior to temporarily adding aggregations for
         # resolving purpose to facilitate their subsequent removal.
         refs_subquery = False
+        refs_window = False
         replacements = {}
         annotation_select_mask = self.annotation_select_mask
         for alias, aggregate_expr in aggregate_exprs.items():
@@ -419,6 +420,10 @@ def get_aggregation(self, using, aggregate_exprs):
                 getattr(self.annotations[ref], "subquery", False)
                 for ref in aggregate.get_refs()
             )
+            refs_window |= any(
+                getattr(self.annotations[ref], "contains_over_clause", True)
+                for ref in aggregate.get_refs()
+            )
             aggregate = aggregate.replace_expressions(replacements)
             self.annotations[alias] = aggregate
             replacements[Ref(alias, aggregate)] = aggregate
@@ -451,6 +456,7 @@ def get_aggregation(self, using, aggregate_exprs):
             or self.is_sliced
             or has_existing_aggregation
             or refs_subquery
+            or refs_window
             or qualify
             or self.distinct
             or self.combinator

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions_window/test_aggregation.py b/tests/expressions_window/test_aggregation.py
new file mode 100644
index 0000000000..51956ed6e8
--- /dev/null
+++ b/tests/expressions_window/test_aggregation.py
@@ -0,0 +1,78 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import F, Sum, Window
+from django.db.models.functions import Coalesce
+from django.test import TestCase, skipUnlessDBFeature
+
+from .models import Classification, Employee, PastEmployeeDepartment
+
+
+@skipUnlessDBFeature("supports_over_clause")
+class WindowFunctionTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        classification = Classification.objects.create()
+        Employee.objects.bulk_create(
+            [
+                Employee(
+                    name=e[0],
+                    salary=e[1],
+                    department=e[2],
+                    hire_date=e[3],
+                    age=e[4],
+                    bonus=Decimal(e[1]) / 400,
+                    classification=classification,
+                )
+                for e in [
+                    ("Jones", 45000, "Accounting", datetime.datetime(2005, 11, 1), 20),
+                    (
+                        "Williams",
+                        37000,
+                        "Accounting",
+                        datetime.datetime(2009, 6, 1),
+                        20,
+                    ),
+                    ("Jenson", 45000, "Accounting", datetime.datetime(2008, 4, 1), 20),
+                    ("Adams", 50000, "Accounting", datetime.datetime(2013, 7, 1), 50),
+                    ("Smith", 55000, "Sales", datetime.datetime(2007, 6, 1), 30),
+                    ("Brown", 53000, "Sales", datetime.datetime(2009, 9, 1), 30),
+                    ("Johnson", 40000, "Marketing", datetime.datetime(2012, 3, 1), 30),
+                    ("Smith", 38000, "Marketing", datetime.datetime(2009, 10, 1), 20),
+                    ("Wilkinson", 60000, "IT", datetime.datetime(2011, 3, 1), 40),
+                    ("Moore", 34000, "IT", datetime.datetime(2013, 8, 1), 40),
+                    ("Miller", 100000, "Management", datetime.datetime(2005, 6, 1), 40),
+                    ("Johnson", 80000, "Management", datetime.datetime(2005, 7, 1), 50),
+                ]
+            ]
+        )
+        employees = list(Employee.objects.order_by("pk"))
+        PastEmployeeDepartment.objects.bulk_create(
+            [
+                PastEmployeeDepartment(employee=employees[6], department="Sales"),
+                PastEmployeeDepartment(employee=employees[10], department="IT"),
+            ]
+        )
+
+    def test_aggregate_over_window_function(self):
+        """
+        Test that aggregating over a Window function annotation does not raise
+        an error.
+        """
+        queryset = Employee.objects.annotate(
+            cumulative_salary=Coalesce(
+                Window(expression=Sum("salary"), order_by=F("hire_date").asc()),
+                0,
+            )
+        )
+        aggregated = queryset.aggregate(
+            total_salary=Sum("salary"),
+            total_cumulative_salary=Sum("cumulative_salary"),
+        )
+        self.assertEqual(
+            aggregated,
+            {
+                "total_salary": 637000,
+                "total_cumulative_salary": 4646000,
+            },
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions_window.test_aggregation
cat coverage.cover
git checkout f8c43aca467b7b0c4bb0a7fa41362f90b610b8df
git apply /root/pre_state.patch
