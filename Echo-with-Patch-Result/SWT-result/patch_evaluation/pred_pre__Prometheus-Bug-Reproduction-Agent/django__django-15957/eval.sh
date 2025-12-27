#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f387d024fc75569d2a4a338bfda76cc2f328f627 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f387d024fc75569d2a4a338bfda76cc2f328f627
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/prefetch_related/test_sliced_prefetch.py b/tests/prefetch_related/test_sliced_prefetch.py
new file mode 100644
index 0000000000..a9ec7842c3
--- /dev/null
+++ b/tests/prefetch_related/test_sliced_prefetch.py
@@ -0,0 +1,52 @@
+from django.db import models
+from django.db.models import Prefetch
+from django.test import TestCase
+
+
+class Category(models.Model):
+    name = models.CharField(max_length=255)
+
+    class Meta:
+        app_label = "prefetch_related"
+        ordering = ["id"]
+
+
+class Post(models.Model):
+    title = models.CharField(max_length=255)
+    category = models.ForeignKey(
+        Category, on_delete=models.CASCADE, related_name="post_set"
+    )
+
+    class Meta:
+        app_label = "prefetch_related"
+        ordering = ["id"]
+
+
+class SlicedPrefetchTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.category = Category.objects.create(name="Test Category")
+        # Create more posts than the slice limit to test the slicing.
+        for i in range(5):
+            Post.objects.create(title=f"Post {i}", category=cls.category)
+
+    def test_prefetch_with_sliced_queryset(self):
+        """
+        Tests that a sliced queryset can be used in a Prefetch object.
+        """
+        # This query uses a sliced queryset in a Prefetch, which would fail
+        # before the fix.
+        categories_qs = Category.objects.prefetch_related(
+            Prefetch(
+                "post_set",
+                queryset=Post.objects.order_by("title")[:3],
+                to_attr="example_posts",
+            )
+        )
+
+        # Evaluating the queryset triggers the prefetch and the bug.
+        category = categories_qs.get()
+
+        # This assertion verifies that the slice was correctly applied to the
+        # prefetched objects for the given category.
+        self.assertEqual(len(category.example_posts), 3)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related_descriptors\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 prefetch_related.test_sliced_prefetch
cat coverage.cover
git checkout f387d024fc75569d2a4a338bfda76cc2f328f627
git apply /root/pre_state.patch
