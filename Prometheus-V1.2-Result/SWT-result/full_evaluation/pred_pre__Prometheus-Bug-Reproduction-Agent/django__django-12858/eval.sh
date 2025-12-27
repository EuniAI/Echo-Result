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
diff --git a/tests/check_framework/test_ordering_check.py b/tests/check_framework/test_ordering_check.py
new file mode 100644
index 0000000000..bef597a3ec
--- /dev/null
+++ b/tests/check_framework/test_ordering_check.py
@@ -0,0 +1,36 @@
+from django.core import checks
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps, override_system_checks
+
+
+@isolate_apps('check_framework', attr_name='apps')
+@override_system_checks([checks.model_checks.check_all_models])
+class OrderingCheckTests(SimpleTestCase):
+    def test_ordering_by_lookup_that_is_not_a_transform(self):
+        """
+        ordering shouldn't raise E015 for lookups that are not transforms.
+        """
+        class Product(models.Model):
+            parent = models.ForeignKey(
+                'self', on_delete=models.CASCADE, null=True,
+            )
+
+            class Meta:
+                app_label = 'check_framework'
+
+        class Supply(models.Model):
+            product = models.ForeignKey(Product, on_delete=models.CASCADE)
+
+            class Meta:
+                app_label = 'check_framework'
+
+        class Stock(models.Model):
+            supply = models.ForeignKey(Supply, on_delete=models.CASCADE)
+
+            class Meta:
+                app_label = 'check_framework'
+                ordering = ('supply__product__parent__isnull',)
+
+        errors = checks.run_checks(app_configs=self.apps.get_app_configs())
+        self.assertEqual(errors, [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 check_framework.test_ordering_check
cat coverage.cover
git checkout f2051eb8a7febdaaa43bd33bf5a6108c5f428e59
git apply /root/pre_state.patch
