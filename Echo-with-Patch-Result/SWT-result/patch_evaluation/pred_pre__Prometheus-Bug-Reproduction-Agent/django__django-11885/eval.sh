#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 04ac9b45a34440fa447feb6ae934687aacbfc5f4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 04ac9b45a34440fa447feb6ae934687aacbfc5f4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_fast_delete_combination.py b/tests/test_fast_delete_combination.py
new file mode 100644
index 0000000000..d74d2336c4
--- /dev/null
+++ b/tests/test_fast_delete_combination.py
@@ -0,0 +1,36 @@
+from django.test import TestCase
+
+from .models import Origin, Referrer, SecondReferrer
+
+
+class FastDeleteCombinationTests(TestCase):
+    def test_fast_delete_combined_queries(self):
+        """
+        When a model is referenced by multiple FKs from another model,
+        fast-deleting an instance of the first model should combine the
+        cascading deletes on the second model into a single query.
+        """
+        origin = Origin.objects.create()
+        ref_to_delete = Referrer.objects.create(
+            origin=origin, unique_field=1, large_field='foo'
+        )
+        other_ref = Referrer.objects.create(
+            origin=origin, unique_field=2, large_field='bar'
+        )
+
+        # This object will be deleted via the `referrer` FK cascade.
+        SecondReferrer.objects.create(referrer=ref_to_delete, other_referrer=other_ref)
+        # This object will be deleted via the `other_referrer` FK cascade.
+        SecondReferrer.objects.create(referrer=other_ref, other_referrer=ref_to_delete)
+
+        # Deleting `ref_to_delete` triggers two cascades to SecondReferrer.
+        # Before the fix, this is two separate fast delete queries. With the
+        # fix, these are combined into one.
+        # Queries:
+        # 1. DELETE FROM SecondReferrer WHERE ... (combined)
+        # 2. DELETE FROM Referrer WHERE ...
+        with self.assertNumQueries(2):
+            ref_to_delete.delete()
+
+        self.assertFalse(Referrer.objects.filter(pk=ref_to_delete.pk).exists())
+        self.assertEqual(SecondReferrer.objects.count(), 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/utils\.py|django/db/models/deletion\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_fast_delete_combination
cat coverage.cover
git checkout 04ac9b45a34440fa447feb6ae934687aacbfc5f4
git apply /root/pre_state.patch
