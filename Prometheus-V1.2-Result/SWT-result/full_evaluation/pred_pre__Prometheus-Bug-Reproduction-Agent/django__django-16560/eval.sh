#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 51c9bb7cd16081133af4f0ab6d06572660309730 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 51c9bb7cd16081133af4f0ab6d06572660309730
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/constraints/test_violation_error_code.py b/tests/constraints/test_violation_error_code.py
new file mode 100644
index 0000000000..64a30cfbcb
--- /dev/null
+++ b/tests/constraints/test_violation_error_code.py
@@ -0,0 +1,35 @@
+from django.core.exceptions import ValidationError
+from django.db import connection, models
+from django.test import TestCase
+
+
+class BaseConstraintViolationErrorCodeTest(TestCase):
+    def test_custom_violation_error_code(self):
+        """
+        Test that a custom error code can be specified for a constraint
+        validation error.
+        """
+
+        class Product(models.Model):
+            name = models.CharField(max_length=255)
+
+            class Meta:
+                app_label = "constraints"
+                constraints = [
+                    models.UniqueConstraint(
+                        fields=["name"],
+                        name="name_uniq",
+                        violation_error_code="custom_code",
+                    )
+                ]
+
+        with connection.schema_editor() as schema_editor:
+            schema_editor.create_model(Product)
+        self.addCleanup(connection.schema_editor().delete_model, Product)
+
+        Product.objects.create(name="test")
+        instance = Product(name="test")
+        with self.assertRaises(ValidationError) as cm:
+            instance.validate_constraints()
+
+        self.assertEqual(cm.exception.error_dict["__all__"][0].code, "custom_code")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/postgres/constraints\.py|django/db/models/constraints\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 constraints.test_violation_error_code
cat coverage.cover
git checkout 51c9bb7cd16081133af4f0ab6d06572660309730
git apply /root/pre_state.patch
