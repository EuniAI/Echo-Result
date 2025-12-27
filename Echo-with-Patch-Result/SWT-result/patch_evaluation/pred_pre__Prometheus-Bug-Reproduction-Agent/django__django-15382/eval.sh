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
diff --git a/tests/test_subquery_expression.py b/tests/test_subquery_expression.py
new file mode 100644
index 0000000000..cb6c875e51
--- /dev/null
+++ b/tests/test_subquery_expression.py
@@ -0,0 +1,20 @@
+from django.db.models import Exists
+from django.test import TestCase
+
+from .models import Company
+
+
+class SubqueryExpressionTests(TestCase):
+    def test_negated_exists_with_empty_queryset(self):
+        """
+        A negated exists-subquery with an empty queryset should not remove
+        the WHERE clause.
+        """
+        company = Company.objects.create(
+            name='test',
+            num_employees=1,
+            num_chairs=1,
+            ceo=Company.ceo.field.related_model.objects.create(firstname='test'),
+        )
+        qs = Company.objects.filter(~Exists(Company.objects.none()), name='test')
+        self.assertSequenceEqual(qs, [company])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_subquery_expression
cat coverage.cover
git checkout 770d3e6a4ce8e0a91a9e27156036c1985e74d4a3
git apply /root/pre_state.patch
