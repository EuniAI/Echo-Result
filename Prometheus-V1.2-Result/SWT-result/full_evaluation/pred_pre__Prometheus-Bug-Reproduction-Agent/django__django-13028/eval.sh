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
diff --git a/tests/queries/test_filterable_attribute.py b/tests/queries/test_filterable_attribute.py
new file mode 100644
index 0000000000..0803559170
--- /dev/null
+++ b/tests/queries/test_filterable_attribute.py
@@ -0,0 +1,37 @@
+from django.db import models
+from django.test import TestCase
+
+# These models are defined for the test and will be managed by Django's
+# test runner. The app_label is set to make them part of a virtual app.
+class ProductMetaDataType(models.Model):
+    label = models.CharField(max_length=255)
+    filterable = models.BooleanField(default=False)
+
+    class Meta:
+        app_label = 'queries'
+
+class ProductMetaData(models.Model):
+    value = models.TextField()
+    metadata_type = models.ForeignKey(ProductMetaDataType, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'queries'
+
+
+class FilterableAttributeTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        """Set up data for the whole test case."""
+        cls.brand_metadata = ProductMetaDataType.objects.create(label='Brand', filterable=False)
+        cls.product_metadata = ProductMetaData.objects.create(value='Dark Vador', metadata_type=cls.brand_metadata)
+
+    def test_filter_by_model_with_filterable_false_attribute(self):
+        """
+        Filtering by a model instance with a `filterable=False` attribute should
+        succeed without raising an error.
+        """
+        # This query will raise an unhandled NotSupportedError with the current
+        # buggy code, causing the test to fail as intended. Once the bug is
+        # fixed, this query will succeed, and the assertion will pass.
+        queryset = ProductMetaData.objects.filter(metadata_type=self.brand_metadata)
+        self.assertIn(self.product_metadata, queryset)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_filterable_attribute
cat coverage.cover
git checkout 78ad4b4b0201003792bfdbf1a7781cbc9ee03539
git apply /root/pre_state.patch
