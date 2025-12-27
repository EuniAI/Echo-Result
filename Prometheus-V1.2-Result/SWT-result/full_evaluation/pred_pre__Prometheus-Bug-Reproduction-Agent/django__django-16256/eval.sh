#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 76e37513e22f4d9a01c7f15eee36fe44388e6670 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 76e37513e22f4d9a01c7f15eee36fe44388e6670
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/async/test_async_related_manager.py b/tests/async/test_async_related_manager.py
new file mode 100644
index 0000000000..2c3de94a8e
--- /dev/null
+++ b/tests/async/test_async_related_manager.py
@@ -0,0 +1,27 @@
+from django.test import TestCase
+
+from .models import RelatedModel, SimpleModel
+
+
+class AsyncRelatedManagerTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.s1 = SimpleModel.objects.create(field=1)
+
+    async def test_acreate_on_related_manager(self):
+        related = await self.s1.relatedmodel_set.acreate()
+        self.assertEqual(related.simple, self.s1)
+
+    async def test_aget_or_create_on_related_manager(self):
+        related, created = await self.s1.relatedmodel_set.aget_or_create(
+            id=999,
+        )
+        self.assertTrue(created)
+        self.assertEqual(related.simple, self.s1)
+
+    async def test_aupdate_or_create_on_related_manager(self):
+        related, created = await self.s1.relatedmodel_set.aupdate_or_create(
+            id=998,
+        )
+        self.assertTrue(created)
+        self.assertEqual(related.simple, self.s1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related_descriptors\.py|django/contrib/contenttypes/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 async.test_async_related_manager
cat coverage.cover
git checkout 76e37513e22f4d9a01c7f15eee36fe44388e6670
git apply /root/pre_state.patch
