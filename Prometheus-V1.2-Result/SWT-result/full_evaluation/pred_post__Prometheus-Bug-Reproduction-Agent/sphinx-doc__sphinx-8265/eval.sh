#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b428cd2404675475a5c3dc2a2b0790ba57676202 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b428cd2404675475a5c3dc2a2b0790ba57676202
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/pycode/ast.py b/sphinx/pycode/ast.py
--- a/sphinx/pycode/ast.py
+++ b/sphinx/pycode/ast.py
@@ -166,14 +166,28 @@ def visit_Set(self, node: ast.Set) -> str:
         return "{" + ", ".join(self.visit(e) for e in node.elts) + "}"
 
     def visit_Subscript(self, node: ast.Subscript) -> str:
-        return "%s[%s]" % (self.visit(node.value), self.visit(node.slice))
+        def is_simple_tuple(value: ast.AST) -> bool:
+            return (
+                isinstance(value, ast.Tuple) and
+                bool(value.elts) and
+                not any(isinstance(elt, ast.Starred) for elt in value.elts)
+            )
+
+        if is_simple_tuple(node.slice):
+            elts = ", ".join(self.visit(e) for e in node.slice.elts)  # type: ignore
+            return "%s[%s]" % (self.visit(node.value), elts)
+        elif isinstance(node.slice, ast.Index) and is_simple_tuple(node.slice.value):
+            elts = ", ".join(self.visit(e) for e in node.slice.value.elts)  # type: ignore
+            return "%s[%s]" % (self.visit(node.value), elts)
+        else:
+            return "%s[%s]" % (self.visit(node.value), self.visit(node.slice))
 
     def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
         return "%s %s" % (self.visit(node.op), self.visit(node.operand))
 
     def visit_Tuple(self, node: ast.Tuple) -> str:
         if node.elts:
-            return ", ".join(self.visit(e) for e in node.elts)
+            return "(" + ", ".join(self.visit(e) for e in node.elts) + ")"
         else:
             return "()"
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_arg_parsing.py b/tests/test_domain_py_arg_parsing.py
new file mode 100644
index 000000000..336ca7f95
--- /dev/null
+++ b/tests/test_domain_py_arg_parsing.py
@@ -0,0 +1,35 @@
+import pytest
+from sphinx.addnodes import (
+    desc_parameterlist,
+    desc_parameter,
+    desc_sig_name,
+    desc_sig_operator,
+)
+from sphinx.domains.python import _pseudo_parse_arglist
+from sphinx.testing.util import assert_node
+
+
+def test_pseudo_parse_arglist_with_tuple_default():
+    """
+    Tests that the Python domain's argument parser correctly handles
+    tuple default values.
+
+    This reproduces a bug where a signature like `(color=(1, 1, 1))`
+    was being incorrectly parsed, splitting the tuple into multiple arguments.
+    """
+    # The node to be populated by the parser
+    paramlist = desc_parameterlist()
+
+    # The signature string as it would be passed to a directive like py:method
+    arglist = 'color=(1, 1, 1)'
+
+    # Run the parser on the argument string
+    _pseudo_parse_arglist(paramlist, arglist)
+
+    # The bug would cause the parser to split the tuple, creating more than one
+    # parameter node. The fix ensures the entire tuple is treated as a single
+    # default value within one parameter node.
+    assert len(paramlist) == 1
+    assert_node(paramlist[0], [desc_parameter, ([desc_sig_name, 'color'],
+                                                [desc_sig_operator, '='],
+                                                [desc_sig_name, '(1, 1, 1)'])])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/pycode/ast\.py)' -m tox -epy39 -v -- tests/test_domain_py_arg_parsing.py
cat coverage.cover
git checkout b428cd2404675475a5c3dc2a2b0790ba57676202
git apply /root/pre_state.patch
