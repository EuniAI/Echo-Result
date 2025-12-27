#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 78ad4b4b0201003792bfdbf1a7781cbc9ee03539 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 78ad4b4b0201003792bfdbf1a7781cbc9ee03539
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_filterable_attribute.py b/tests/test_filterable_attribute.py
new file mode 100644
index 0000000000..9eec973fe9
--- /dev/null
+++ b/tests/test_filterable_attribute.py
@@ -0,0 +1,27 @@
+from django.db import models
+from django.test import TestCase
+
+
+class Filterable(models.Model):
+    filterable = models.BooleanField(default=False)
+    name = models.CharField(max_length=255)
+
+
+class Product(models.Model):
+    name = models.CharField(max_length=255)
+    filterable_fk = models.ForeignKey(Filterable, on_delete=models.CASCADE)
+
+
+class FilterableAttributeTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.filterable = Filterable.objects.create(filterable=False, name='test')
+        cls.product = Product.objects.create(name='product', filterable_fk=cls.filterable)
+
+    def test_filterable_attribute_on_model_instance(self):
+        """
+        A model instance with a `filterable=False` attribute can be used in a
+        filter().
+        """
+        qs = Product.objects.filter(filterable_fk=self.filterable)
+        self.assertSequenceEqual(qs, [self.product])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_filterable_attribute
cat coverage.cover
git checkout 78ad4b4b0201003792bfdbf1a7781cbc9ee03539
git apply /root/pre_state.patch
