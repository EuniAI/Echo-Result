#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bf47c719719d0e190a99fa2e7f959d5bbb7caf8a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bf47c719719d0e190a99fa2e7f959d5bbb7caf8a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/expressions.py b/django/db/models/expressions.py
--- a/django/db/models/expressions.py
+++ b/django/db/models/expressions.py
@@ -533,6 +533,7 @@ def __hash__(self):
             Combinable.SUB,
             Combinable.MUL,
             Combinable.DIV,
+            Combinable.MOD,
         )
     },
     # Bitwise operators.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_mod_expression.py b/tests/test_mod_expression.py
new file mode 100644
index 0000000000..182c811404
--- /dev/null
+++ b/tests/test_mod_expression.py
@@ -0,0 +1,17 @@
+from django.db.models import DecimalField, Expression, IntegerField
+from django.db.models.expressions import Combinable, CombinedExpression
+from django.test import SimpleTestCase
+
+
+class ModExpressionTests(SimpleTestCase):
+    def test_mod_mixed_types_output_field(self):
+        """
+        The output_field of a Mod operation between a DecimalField and an
+        IntegerField should be a DecimalField.
+        """
+        expr = CombinedExpression(
+            Expression(DecimalField()),
+            Combinable.MOD,
+            Expression(IntegerField()),
+        )
+        self.assertIsInstance(expr.output_field, DecimalField)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_mod_expression
cat coverage.cover
git checkout bf47c719719d0e190a99fa2e7f959d5bbb7caf8a
git apply /root/pre_state.patch
