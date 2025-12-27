#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 93cedc82f29076c824d476354527af1150888e4f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 93cedc82f29076c824d476354527af1150888e4f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/managers_regress/test_manager_signatures.py b/tests/managers_regress/test_manager_signatures.py
new file mode 100644
index 0000000000..0a9d341a7e
--- /dev/null
+++ b/tests/managers_regress/test_manager_signatures.py
@@ -0,0 +1,24 @@
+import inspect
+
+from django.db import models
+from django.test import SimpleTestCase
+
+
+class Person(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = "managers"
+
+
+class ManagerSignatureTests(SimpleTestCase):
+    def test_manager_method_signature(self):
+        """
+        inspect.signature() should return the correct signature for manager
+        methods proxied from a queryset.
+        """
+        signature = inspect.signature(Person.objects.bulk_create)
+        # The buggy signature is (*args, **kwargs).
+        # The expected signature is (objs, batch_size=None, ignore_conflicts=False).
+        expected_params = ["objs", "batch_size", "ignore_conflicts"]
+        self.assertEqual(list(signature.parameters), expected_params)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/manager\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 managers_regress.test_manager_signatures
cat coverage.cover
git checkout 93cedc82f29076c824d476354527af1150888e4f
git apply /root/pre_state.patch
