#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7af8f4127397279d19ef7c7899e93018274e2f9b >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7af8f4127397279d19ef7c7899e93018274e2f9b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_combinator_none.py b/tests/queries/test_combinator_none.py
new file mode 100644
index 0000000000..75146c9937
--- /dev/null
+++ b/tests/queries/test_combinator_none.py
@@ -0,0 +1,37 @@
+from django.test import TestCase, skipUnlessDBFeature
+
+# The Number model is a simple, pre-existing model in the 'queries' test app.
+# Using it avoids all previous model definition and setup errors.
+from .models import Number
+
+
+@skipUnlessDBFeature('supports_select_union')
+class CombinatorNoneTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        # Create a range of numbers to query against.
+        for i in range(10):
+            Number.objects.create(num=i)
+
+    def test_combined_queryset_none(self):
+        """
+        QuerySet.none() on a combined queryset (e.g., using union) should
+        return an empty queryset.
+        """
+        # Create two distinct querysets.
+        qs1 = Number.objects.filter(num__lt=2)  # Should contain 0, 1
+        qs2 = Number.objects.filter(num__gt=7)  # Should contain 8, 9
+
+        # Combine them using union.
+        union_qs = qs1.union(qs2)
+        # The union queryset represents numbers 0, 1, 8, 9. Its count is 4.
+        self.assertEqual(union_qs.count(), 4)
+
+        # Call .none() on the combined queryset.
+        none_qs = union_qs.none()
+
+        # Before the fix, the .none() call is ineffective on a union, and the
+        # count will be 4 instead of 0. This assertion will fail.
+        # After the fix, the query will be correctly emptied, and the count
+        # will be 0, causing the test to pass.
+        self.assertEqual(none_qs.count(), 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_combinator_none
cat coverage.cover
git checkout 7af8f4127397279d19ef7c7899e93018274e2f9b
git apply /root/pre_state.patch
