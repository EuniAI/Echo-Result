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
diff --git a/sphinx/util/inspect.py b/sphinx/util/inspect.py
--- a/sphinx/util/inspect.py
+++ b/sphinx/util/inspect.py
@@ -442,14 +442,14 @@ def object_description(object: Any) -> str:
                      (object_description(key), object_description(object[key]))
                      for key in sorted_keys)
             return "{%s}" % ", ".join(items)
-    if isinstance(object, set):
+    elif isinstance(object, set):
         try:
             sorted_values = sorted(object)
         except TypeError:
             pass  # Cannot sort set values, fall back to generic repr
         else:
             return "{%s}" % ", ".join(object_description(x) for x in sorted_values)
-    if isinstance(object, frozenset):
+    elif isinstance(object, frozenset):
         try:
             sorted_values = sorted(object)
         except TypeError:
@@ -457,6 +457,9 @@ def object_description(object: Any) -> str:
         else:
             return "frozenset({%s})" % ", ".join(object_description(x)
                                                  for x in sorted_values)
+    elif isinstance(object, enum.Enum):
+        return "%s.%s" % (object.__class__.__name__, object.name)
+
     try:
         s = repr(object)
     except Exception as exc:

EOF_114329324912
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
