#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2a55431a5678af52f669ffe7dff3dd0bd21727f8 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2a55431a5678af52f669ffe7dff3dd0bd21727f8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions/test_window_functions_lag_decimalfield.py b/tests/expressions/test_window_functions_lag_decimalfield.py
new file mode 100644
index 0000000000..0f02301967
--- /dev/null
+++ b/tests/expressions/test_window_functions_lag_decimalfield.py
@@ -0,0 +1,63 @@
+import datetime
+import unittest
+from decimal import Decimal
+
+from django.db import connection, models
+from django.db.models import F, Window
+from django.db.models.functions import Lag
+from django.test import TransactionTestCase, skipUnlessDBFeature
+
+# Define the model from the bug report. By setting the app_label to
+# 'expressions', a known app in the test suite, we can use it with
+# TransactionTestCase without setup errors.
+class LagTest(models.Model):
+    modified = models.DateField()
+    data = models.FloatField()
+    amount = models.DecimalField(decimal_places=4, max_digits=7)
+
+    class Meta:
+        app_label = 'expressions'
+
+
+@unittest.skipUnless(connection.vendor == 'sqlite', 'This test is specific to SQLite')
+@skipUnlessDBFeature('supports_over_clause')
+class WindowFunctionsLagSQLiteTest(TransactionTestCase):
+    available_apps = ['expressions']
+
+    def test_lag_decimalfield_sqlite_crash(self):
+        """
+        Test that Lag() over a DecimalField on SQLite doesn't crash.
+        """
+        # Create two objects to make the window function's ordering and lag
+        # meaningful and verifiable.
+        LagTest.objects.create(
+            modified=datetime.date(2020, 7, 20),
+            data=1.0,
+            amount=Decimal('12.34'),
+        )
+        LagTest.objects.create(
+            modified=datetime.date(2020, 7, 21),
+            data=2.0,
+            amount=Decimal('56.78'),
+        )
+
+        queryset = LagTest.objects.annotate(
+            w=Window(
+                expression=Lag('amount', 1),
+                order_by=F('modified').asc(),
+            )
+        )
+
+        # On the unpatched codebase, evaluating the queryset will raise an
+        # unhandled `OperationalError: near "OVER": syntax error`.
+        # On the patched codebase, this will execute successfully.
+        # The assertion checks for the correct, non-crashing behavior and
+        # verifies the lag calculation is correct.
+        self.assertQuerysetEqual(
+            queryset.order_by('modified'),
+            [
+                (Decimal('12.3400'), None),
+                (Decimal('56.7800'), Decimal('12.3400')),
+            ],
+            transform=lambda row: (row.amount, row.w)
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.test_window_functions_lag_decimalfield
cat coverage.cover
git checkout 2a55431a5678af52f669ffe7dff3dd0bd21727f8
git apply /root/pre_state.patch
