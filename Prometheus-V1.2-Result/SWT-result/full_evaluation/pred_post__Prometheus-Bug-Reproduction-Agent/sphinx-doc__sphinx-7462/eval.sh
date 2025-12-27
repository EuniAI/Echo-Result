#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b3e26a6c851133b82b50f4b68b53692076574d13 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b3e26a6c851133b82b50f4b68b53692076574d13
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/domains/python.py b/sphinx/domains/python.py
--- a/sphinx/domains/python.py
+++ b/sphinx/domains/python.py
@@ -105,11 +105,16 @@ def unparse(node: ast.AST) -> List[Node]:
             result.append(addnodes.desc_sig_punctuation('', ']'))
             return result
         elif isinstance(node, ast.Tuple):
-            result = []
-            for elem in node.elts:
-                result.extend(unparse(elem))
-                result.append(addnodes.desc_sig_punctuation('', ', '))
-            result.pop()
+            if node.elts:
+                result = []
+                for elem in node.elts:
+                    result.extend(unparse(elem))
+                    result.append(addnodes.desc_sig_punctuation('', ', '))
+                result.pop()
+            else:
+                result = [addnodes.desc_sig_punctuation('', '('),
+                          addnodes.desc_sig_punctuation('', ')')]
+
             return result
         else:
             raise SyntaxError  # unsupported syntax
diff --git a/sphinx/pycode/ast.py b/sphinx/pycode/ast.py
--- a/sphinx/pycode/ast.py
+++ b/sphinx/pycode/ast.py
@@ -114,7 +114,10 @@ def unparse(node: ast.AST) -> str:
     elif isinstance(node, ast.UnaryOp):
         return "%s %s" % (unparse(node.op), unparse(node.operand))
     elif isinstance(node, ast.Tuple):
-        return ", ".join(unparse(e) for e in node.elts)
+        if node.elts:
+            return ", ".join(unparse(e) for e in node.elts)
+        else:
+            return "()"
     elif sys.version_info > (3, 6) and isinstance(node, ast.Constant):
         # this branch should be placed at last
         return repr(node.value)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_annotations.py b/tests/test_domain_py_annotations.py
new file mode 100644
index 000000000..e1d21eed0
--- /dev/null
+++ b/tests/test_domain_py_annotations.py
@@ -0,0 +1,28 @@
+import sys
+from unittest.mock import Mock
+
+import pytest
+from docutils import nodes
+
+from sphinx import addnodes
+from sphinx.addnodes import (
+    desc, desc_addname, desc_annotation, desc_content, desc_name, desc_optional,
+    desc_parameter, desc_parameterlist, desc_returns, desc_signature,
+    desc_sig_name, desc_sig_operator, desc_sig_punctuation, pending_xref,
+)
+from sphinx.domains import IndexEntry
+from sphinx.domains.python import (
+    py_sig_re, _parse_annotation, _pseudo_parse_arglist, PythonDomain, PythonModuleIndex
+)
+from sphinx.testing import restructuredtext
+from sphinx.testing.util import assert_node
+
+
+def test_parse_annotation_empty_tuple():
+    """Test parsing of empty tuple annotation ``Tuple[()]``."""
+    doctree = _parse_annotation("Tuple[()]")
+    assert_node(doctree, ([pending_xref, "Tuple"],
+                          [desc_sig_punctuation, "["],
+                          [desc_sig_punctuation, "("],
+                          [desc_sig_punctuation, ")"],
+                          [desc_sig_punctuation, "]"]))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/python\.py|sphinx/pycode/ast\.py)' -m tox -epy39 -v -- tests/test_domain_py_annotations.py
cat coverage.cover
git checkout b3e26a6c851133b82b50f4b68b53692076574d13
git apply /root/pre_state.patch
