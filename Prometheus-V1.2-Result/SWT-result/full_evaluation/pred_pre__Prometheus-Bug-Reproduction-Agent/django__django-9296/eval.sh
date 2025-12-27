#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 84322a29ce9b0940335f8ab3d60e55192bef1e50 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 84322a29ce9b0940335f8ab3d60e55192bef1e50
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/pagination/test_iterator.py b/tests/pagination/test_iterator.py
new file mode 100644
index 0000000000..47e3e1fd9c
--- /dev/null
+++ b/tests/pagination/test_iterator.py
@@ -0,0 +1,16 @@
+from django.core.paginator import Paginator
+from django.test import SimpleTestCase
+
+
+class PaginationIteratorTest(SimpleTestCase):
+    """
+    Test case for Paginator iteration as requested in issue description.
+    """
+
+    def test_paginator_is_iterable(self):
+        """
+        Test that a Paginator object can be iterated over to yield pages.
+        """
+        paginator = Paginator([1, 2, 3, 4, 5], 2)
+        page_contents = [p.object_list for p in paginator]
+        self.assertEqual(page_contents, [[1, 2], [3, 4], [5]])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/paginator\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 pagination.test_iterator
cat coverage.cover
git checkout 84322a29ce9b0940335f8ab3d60e55192bef1e50
git apply /root/pre_state.patch
