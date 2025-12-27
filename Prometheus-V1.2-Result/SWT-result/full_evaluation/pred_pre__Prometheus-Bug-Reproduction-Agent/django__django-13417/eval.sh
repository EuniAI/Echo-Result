#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_group_by_annotation_ordering.py b/tests/queries/test_group_by_annotation_ordering.py
new file mode 100644
index 0000000000..95c8faa403
--- /dev/null
+++ b/tests/queries/test_group_by_annotation_ordering.py
@@ -0,0 +1,25 @@
+from django.db.models import Count
+from django.test import TestCase
+
+from .models import Tag
+
+
+class GroupByQuerySetOrderedPropertyTest(TestCase):
+    """
+    Test the `ordered` property of QuerySets that involve a GROUP BY.
+    """
+
+    def test_grouped_by_annotation_clears_ordering(self):
+        """
+        A GROUP BY query is not ordered by default, so `ordered` should be
+        False, even if the model has a default ordering.
+        """
+        # The Tag model has default ordering defined in its Meta class.
+        self.assertTrue(Tag.objects.all().ordered)
+
+        # Annotating with a Count should add a GROUP BY clause, which clears
+        # any ordering.
+        qs = Tag.objects.annotate(Count('pk'))
+
+        # The bug is that `qs.ordered` is True, when it should be False.
+        self.assertFalse(qs.ordered)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_group_by_annotation_ordering
cat coverage.cover
git checkout 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396
git apply /root/pre_state.patch
