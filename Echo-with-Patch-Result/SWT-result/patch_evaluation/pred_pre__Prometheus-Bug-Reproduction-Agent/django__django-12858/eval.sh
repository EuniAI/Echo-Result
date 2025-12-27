#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f2051eb8a7febdaaa43bd33bf5a6108c5f428e59 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f2051eb8a7febdaaa43bd33bf5a6108c5f428e59
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/invalid_models/test_ordering_check.py b/tests/invalid_models/test_ordering_check.py
new file mode 100644
index 0000000000..3b9fd1d451
--- /dev/null
+++ b/tests/invalid_models/test_ordering_check.py
@@ -0,0 +1,80 @@
+from django.core.checks import Error
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('invalid_models_tests')
+class OrderingCheckTests(SimpleTestCase):
+
+    def test_ordering_with_lookup_on_related_field(self):
+        """
+        Check that ordering on a lookup on a related field is allowed.
+        """
+        class Product(models.Model):
+            parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True)
+
+        class Supply(models.Model):
+            product = models.ForeignKey(Product, on_delete=models.CASCADE)
+
+        class Stock(models.Model):
+            supply = models.ForeignKey(Supply, on_delete=models.CASCADE)
+
+            class Meta:
+                ordering = ['supply__product__parent__isnull']
+
+        errors = Stock.check()
+        self.assertEqual(errors, [])
+
+    def test_ordering_with_transform_on_related_field(self):
+        """
+        Check that ordering on a transform on a related field is allowed.
+        """
+        class Product(models.Model):
+            name = models.CharField(max_length=255)
+            parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True)
+
+        class Supply(models.Model):
+            product = models.ForeignKey(Product, on_delete=models.CASCADE)
+
+        class Stock(models.Model):
+            supply = models.ForeignKey(Supply, on_delete=models.CASCADE)
+
+            class Meta:
+                ordering = ['supply__product__name__upper']
+
+        from django.db.models.functions import Upper
+        from django.db.models import CharField
+        CharField.register_lookup(Upper)
+        try:
+            errors = Stock.check()
+            self.assertEqual(errors, [])
+        finally:
+            CharField._unregister_lookup(Upper)
+
+    def test_ordering_with_invalid_lookup_on_related_field(self):
+        """
+        Check that ordering on a nonexistent lookup on a related field fails.
+        """
+        class Product(models.Model):
+            parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True)
+
+        class Supply(models.Model):
+            product = models.ForeignKey(Product, on_delete=models.CASCADE)
+
+        class Stock(models.Model):
+            supply = models.ForeignKey(Supply, on_delete=models.CASCADE)
+
+            class Meta:
+                ordering = ['supply__product__parent__nonexistent']
+
+        errors = Stock.check()
+        expected_errors = [
+            Error(
+                "'ordering' refers to the nonexistent field, related field, or "
+                "lookup 'supply__product__parent__nonexistent'.",
+                obj=Stock,
+                id='models.E015',
+            )
+        ]
+        self.assertEqual(errors, expected_errors)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 invalid_models.test_ordering_check
cat coverage.cover
git checkout f2051eb8a7febdaaa43bd33bf5a6108c5f428e59
git apply /root/pre_state.patch
