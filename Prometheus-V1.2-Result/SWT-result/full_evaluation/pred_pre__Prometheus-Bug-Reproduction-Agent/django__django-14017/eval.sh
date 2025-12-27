#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 466920f6d726eee90d5566e0a9948e92b33a122e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 466920f6d726eee90d5566e0a9948e92b33a122e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions/test_q_exists_operator.py b/tests/expressions/test_q_exists_operator.py
new file mode 100644
index 0000000000..598e2a4447
--- /dev/null
+++ b/tests/expressions/test_q_exists_operator.py
@@ -0,0 +1,39 @@
+from django.db.models import Exists, OuterRef, Q
+from django.test import TestCase
+
+# Correctly import models from the 'expressions' app to avoid ImportError.
+from expressions.models import Company, Employee
+
+
+class QExistsCombinationTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        """
+        Set up data for the test case.
+        - A CEO employee.
+        - A non-CEO employee.
+        - A company run by the CEO.
+        """
+        cls.ceo = Employee.objects.create(
+            firstname='John', lastname='Doe', salary=50000
+        )
+        cls.non_ceo = Employee.objects.create(
+            firstname='Jane', lastname='Smith', salary=40000
+        )
+        # Ensure all required fields for the Company model are provided.
+        Company.objects.create(
+            name='Django Inc.', num_employees=10, num_chairs=10, ceo=cls.ceo
+        )
+
+    def test_q_and_exists_operator(self):
+        """
+        Test that Q() & Exists() is a valid query and doesn't raise a
+        TypeError. This reproduces the bug where the operation is not
+        commutative.
+        """
+        is_ceo_query = Company.objects.filter(ceo=OuterRef('pk'))
+        # The following query construction raises a TypeError due to the bug.
+        # When the bug is fixed, this filter should execute successfully.
+        qs = Employee.objects.filter(Q() & Exists(is_ceo_query))
+        # This assertion will pass once the TypeError is resolved.
+        self.assertSequenceEqual(qs, [cls.ceo])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.test_q_exists_operator
cat coverage.cover
git checkout 466920f6d726eee90d5566e0a9948e92b33a122e
git apply /root/pre_state.patch
