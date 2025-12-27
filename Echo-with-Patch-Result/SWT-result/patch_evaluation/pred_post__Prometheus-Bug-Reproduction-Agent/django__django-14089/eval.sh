#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d01709aae21de9cd2565b9c52f32732ea28a2d98 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d01709aae21de9cd2565b9c52f32732ea28a2d98
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/datastructures.py b/django/utils/datastructures.py
--- a/django/utils/datastructures.py
+++ b/django/utils/datastructures.py
@@ -25,6 +25,9 @@ def discard(self, item):
     def __iter__(self):
         return iter(self.dict)
 
+    def __reversed__(self):
+        return reversed(self.dict)
+
     def __contains__(self, item):
         return item in self.dict
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils/test_orderedset.py b/tests/utils/test_orderedset.py
new file mode 100644
index 0000000000..77af3e6bc5
--- /dev/null
+++ b/tests/utils/test_orderedset.py
@@ -0,0 +1,11 @@
+from django.test import SimpleTestCase
+from django.utils.datastructures import OrderedSet
+
+
+class OrderedSetTests(SimpleTestCase):
+    def test_reversed(self):
+        """
+        reversed() can be called on an OrderedSet.
+        """
+        os = OrderedSet([1, 2, 3, 4])
+        self.assertEqual(list(reversed(os)), [4, 3, 2, 1])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/datastructures\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils.test_orderedset
cat coverage.cover
git checkout d01709aae21de9cd2565b9c52f32732ea28a2d98
git apply /root/pre_state.patch
