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
diff --git a/tests/utils_tests/test_orderedset.py b/tests/utils_tests/test_orderedset.py
new file mode 100644
index 0000000000..93fad43b8f
--- /dev/null
+++ b/tests/utils_tests/test_orderedset.py
@@ -0,0 +1,22 @@
+"""
+Tests for stuff in django.utils.datastructures.
+"""
+
+import copy
+import pickle
+
+from django.test import SimpleTestCase
+from django.utils.datastructures import (
+    CaseInsensitiveMapping, DictWrapper, ImmutableList, MultiValueDict,
+    MultiValueDictKeyError, OrderedSet,
+)
+
+
+class OrderedSetTests(SimpleTestCase):
+
+    def test_reversed(self):
+        """
+        reversed() can be called on an OrderedSet.
+        """
+        s = OrderedSet([1, 2, 3, 4])
+        self.assertEqual(list(reversed(s)), [4, 3, 2, 1])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/datastructures\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils_tests.test_orderedset
cat coverage.cover
git checkout d01709aae21de9cd2565b9c52f32732ea28a2d98
git apply /root/pre_state.patch
