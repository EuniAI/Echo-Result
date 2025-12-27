#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_deconstruct_expression.py b/tests/migrations/test_deconstruct_expression.py
new file mode 100644
index 0000000000..20e7d404d8
--- /dev/null
+++ b/tests/migrations/test_deconstruct_expression.py
@@ -0,0 +1,20 @@
+from django.db import models
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+
+
+class DeconstructExpressionPathTests(SimpleTestCase):
+    def test_expression_simplified_path(self):
+        """
+        Test that expressions are deconstructed to their simplified paths in
+        `django.db.models`.
+        """
+        expr = models.ExpressionWrapper(models.Value('test'), output_field=models.IntegerField())
+        serialized_string, imports = MigrationWriter.serialize(expr)
+        self.assertEqual(
+            (serialized_string, imports),
+            (
+                "models.ExpressionWrapper(models.Value('test'), output_field=models.IntegerField())",
+                {'from django.db import models'},
+            ),
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_deconstruct_expression
cat coverage.cover
git checkout 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb
git apply /root/pre_state.patch
