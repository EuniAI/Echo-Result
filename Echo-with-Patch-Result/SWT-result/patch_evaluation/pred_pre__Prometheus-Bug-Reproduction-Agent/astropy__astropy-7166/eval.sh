#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 26d147868f8a891a6009a25cd6a8576d2e1bd747 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 26d147868f8a891a6009a25cd6a8576d2e1bd747
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/utils/tests/test_inherit_docstrings.py b/astropy/utils/tests/test_inherit_docstrings.py
new file mode 100644
index 0000000000..f7adffec51
--- /dev/null
+++ b/astropy/utils/tests/test_inherit_docstrings.py
@@ -0,0 +1,23 @@
+import pytest
+from astropy.utils import misc
+
+
+def test_inherit_docstrings_on_properties():
+    """
+    Regression test for an issue where docstrings were not being
+    inherited for properties because inspect.isfunction() returns
+    False for properties.
+    """
+    class Base(metaclass=misc.InheritDocstrings):
+        @property
+        def foo(self):
+            """The docstring for foo."""
+            return 1
+
+    class Sub(Base):
+        @property
+        def foo(self):
+            return 2
+
+    if Base.foo.__doc__ is not None:
+        assert Sub.foo.__doc__ == "The docstring for foo."

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/utils/misc\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/utils/tests/test_inherit_docstrings.py
cat coverage.cover
git checkout 26d147868f8a891a6009a25cd6a8576d2e1bd747
git apply /root/pre_state.patch
