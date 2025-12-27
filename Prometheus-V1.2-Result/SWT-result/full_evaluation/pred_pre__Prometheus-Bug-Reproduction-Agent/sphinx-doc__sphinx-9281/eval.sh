#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8ec06e9a1bd862cd713b9db748e039ccc7b3e15b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8ec06e9a1bd862cd713b9db748e039ccc7b3e15b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_util_inspect_enum.py b/tests/test_util_inspect_enum.py
new file mode 100644
index 000000000..a6d505667
--- /dev/null
+++ b/tests/test_util_inspect_enum.py
@@ -0,0 +1,15 @@
+import enum
+import pytest
+from sphinx.util import inspect
+
+def test_enum_object_description():
+    """
+    Test that enum members are correctly described for signatures.
+    This is to address a bug where enum default values are rendered
+    with their value, instead of just their member name.
+    """
+    class MyEnum(enum.Enum):
+        ValueA = 10
+
+    description = inspect.object_description(MyEnum.ValueA)
+    assert description == 'MyEnum.ValueA'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/util/inspect\.py)' -m tox -epy39 -v -- tests/test_util_inspect_enum.py
cat coverage.cover
git checkout 8ec06e9a1bd862cd713b9db748e039ccc7b3e15b
git apply /root/pre_state.patch
