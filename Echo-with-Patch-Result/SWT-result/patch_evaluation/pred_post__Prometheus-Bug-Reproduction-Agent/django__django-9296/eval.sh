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
diff --git a/django/core/paginator.py b/django/core/paginator.py
--- a/django/core/paginator.py
+++ b/django/core/paginator.py
@@ -34,6 +34,10 @@ def __init__(self, object_list, per_page, orphans=0,
         self.orphans = int(orphans)
         self.allow_empty_first_page = allow_empty_first_page
 
+    def __iter__(self):
+        for page_number in self.page_range:
+            yield self.page(page_number)
+
     def validate_number(self, number):
         """Validate the given 1-based page number."""
         try:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_paginator_iterator.py b/tests/test_paginator_iterator.py
new file mode 100644
index 0000000000..10e0daafbf
--- /dev/null
+++ b/tests/test_paginator_iterator.py
@@ -0,0 +1,14 @@
+from django.core.paginator import Paginator
+from django.test import SimpleTestCase
+
+
+class PaginatorIteratorTest(SimpleTestCase):
+    def test_paginator_is_iterable(self):
+        """
+        Tests that a Paginator object can be iterated over, yielding pages.
+        """
+        paginator = Paginator(['a', 'b', 'c'], 2)
+        # Before the fix, this will raise a TypeError because Paginator is not
+        # iterable. After the fix, it should yield Page objects.
+        page_reprs = [repr(p) for p in paginator]
+        self.assertEqual(page_reprs, ['<Page 1 of 2>', '<Page 2 of 2>'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/paginator\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_paginator_iterator
cat coverage.cover
git checkout 84322a29ce9b0940335f8ab3d60e55192bef1e50
git apply /root/pre_state.patch
