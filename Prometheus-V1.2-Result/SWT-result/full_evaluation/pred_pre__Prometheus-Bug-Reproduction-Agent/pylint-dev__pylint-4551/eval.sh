#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 99589b08de8c5a2c6cc61e13a37420a868c80599 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 99589b08de8c5a2c6cc61e13a37420a868c80599
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittest_pyreverse_inspector_issue_1539.py b/tests/unittest_pyreverse_inspector_issue_1539.py
new file mode 100644
index 000000000..e580bd1eb
--- /dev/null
+++ b/tests/unittest_pyreverse_inspector_issue_1539.py
@@ -0,0 +1,42 @@
+import astroid
+
+from pylint.pyreverse import inspector
+
+
+def test_type_hint_in_init_with_none_default_is_used():
+    """
+    Test that the Linker correctly infers the type of an instance
+    attribute from a type-hinted __init__ argument with a default
+    value of None.
+
+    This reproduces the bug described in https://github.com/PyCQA/pylint/issues/1539
+    """
+    module_node = astroid.parse(
+        """
+    class C:
+        def __init__(self, a: str = None):
+            self.a = a
+    """
+    )
+    class_node = module_node["C"]
+
+    # The Linker is a visitor that populates class information. For a single
+    # module test, the module node itself can act as the project context.
+    linker = inspector.Linker(module_node)
+    linker.visit(module_node)
+
+    # After visiting, the instance_attrs_type dictionary on the class node
+    # should be populated with type information.
+    assert hasattr(class_node, "instance_attrs_type")
+    attrs_type = class_node.instance_attrs_type
+
+    # The type for attribute 'a' should be inferred from the 'str' hint.
+    assert "a" in attrs_type
+    inferred_types = attrs_type["a"]
+    # Before the fix, this would likely be inferred as None or be empty.
+    assert len(inferred_types) == 1
+
+    # The inferred type for 'str' should be an astroid ClassDef node.
+    inferred_type = inferred_types[0]
+    assert isinstance(inferred_type, astroid.nodes.ClassDef)
+    assert inferred_type.name == "str"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/pyreverse/utils\.py|pylint/pyreverse/inspector\.py|pylint/pyreverse/diagrams\.py|pylint/pyreverse/writer\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/unittest_pyreverse_inspector_issue_1539.py
cat coverage.cover
git checkout 99589b08de8c5a2c6cc61e13a37420a868c80599
git apply /root/pre_state.patch
