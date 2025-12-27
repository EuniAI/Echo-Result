#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3c1534944cbd34e8a41bc9e76818018fadefc9a1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3c1534944cbd34e8a41bc9e76818018fadefc9a1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_mark_inheritance.py b/testing/test_mark_inheritance.py
new file mode 100644
index 000000000..107e2d108
--- /dev/null
+++ b/testing/test_mark_inheritance.py
@@ -0,0 +1,32 @@
+import pytest
+from _pytest.pytester import Pytester
+
+
+class TestMark:
+    def test_mark_multiple_inheritance_is_merged(self, pytester: Pytester) -> None:
+        """
+        Tests that markers from multiple base classes are merged.
+        This reproduces a bug where markers from a second base class are lost
+        due to MRO.
+        """
+        p = pytester.makepyfile(
+            """
+            import pytest
+
+            @pytest.mark.foo
+            class Foo:
+                pass
+
+            @pytest.mark.bar
+            class Bar:
+                pass
+
+            class TestDings(Foo, Bar):
+                def test_dings(self):
+                    pass
+            """
+        )
+        items, rec = pytester.inline_genitems(p)
+        (item,) = items
+        markers = {m.name for m in item.iter_markers()}
+        assert markers == {"foo", "bar"}

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/mark/structures\.py)' -m pytest -rA testing/test_mark_inheritance.py
cat coverage.cover
git checkout 3c1534944cbd34e8a41bc9e76818018fadefc9a1
git apply /root/pre_state.patch
