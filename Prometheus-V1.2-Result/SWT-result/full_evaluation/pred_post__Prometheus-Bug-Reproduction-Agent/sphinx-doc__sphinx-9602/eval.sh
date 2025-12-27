#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6c38f68dae221e8cfc70c137974b8b88bd3baaab >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6c38f68dae221e8cfc70c137974b8b88bd3baaab
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/domains/python.py b/sphinx/domains/python.py
--- a/sphinx/domains/python.py
+++ b/sphinx/domains/python.py
@@ -123,7 +123,7 @@ def unparse(node: ast.AST) -> List[Node]:
             if node.value is Ellipsis:
                 return [addnodes.desc_sig_punctuation('', "...")]
             else:
-                return [nodes.Text(node.value)]
+                return [nodes.Text(repr(node.value))]
         elif isinstance(node, ast.Expr):
             return unparse(node.value)
         elif isinstance(node, ast.Index):
@@ -149,6 +149,12 @@ def unparse(node: ast.AST) -> List[Node]:
             result.append(addnodes.desc_sig_punctuation('', '['))
             result.extend(unparse(node.slice))
             result.append(addnodes.desc_sig_punctuation('', ']'))
+
+            # Wrap the Text nodes inside brackets by literal node if the subscript is a Literal
+            if result[0] in ('Literal', 'typing.Literal'):
+                for i, subnode in enumerate(result[1:], start=1):
+                    if isinstance(subnode, nodes.Text):
+                        result[i] = nodes.literal('', '', subnode)
             return result
         elif isinstance(node, ast.Tuple):
             if node.elts:
@@ -179,7 +185,9 @@ def unparse(node: ast.AST) -> List[Node]:
         tree = ast_parse(annotation)
         result = unparse(tree)
         for i, node in enumerate(result):
-            if isinstance(node, nodes.Text) and node.strip():
+            if isinstance(node, nodes.literal):
+                result[i] = node[0]
+            elif isinstance(node, nodes.Text) and node.strip():
                 result[i] = type_to_xref(str(node), env)
         return result
     except SyntaxError:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_literal.py b/tests/test_ext_autodoc_literal.py
new file mode 100644
index 000000000..91132fcab
--- /dev/null
+++ b/tests/test_ext_autodoc_literal.py
@@ -0,0 +1,56 @@
+import sys
+import pytest
+
+@pytest.mark.skipif(sys.version_info < (3, 8), reason="typing.Literal is available on Python 3.8+")
+@pytest.mark.sphinx('html', testroot='ext-autodoc', freshenv=True)
+def test_autodoc_literal_annotation_nitpick(app):
+    """
+    Tests that documenting a function with typing.Literal does not cause a
+    nitpicky warning for the literal's value.
+
+    The test works by running a full Sphinx build in a nitpicky environment.
+    It then asserts that the build produced no warnings.
+
+    When the bug is present, Sphinx tries to create a cross-reference for the
+    `True` in `Literal[True]`, which fails and raises a nitpicky warning.
+    This causes the assertion `assert app.warning.getvalue() == ''` to fail,
+    correctly reproducing the bug.
+
+    When the bug is fixed, no warnings will be emitted, and the test will pass.
+    """
+    # Create the Python source file with the code from the bug report
+    python_source = (
+        'import typing\n'
+        '\n'
+        '@typing.overload\n'
+        'def foo(x: "typing.Literal[True]") -> int: ...\n'
+        '\n'
+        '@typing.overload\n'
+        'def foo(x: "typing.Literal[False]") -> str: ...\n'
+        '\n'
+        'def foo(x: bool):\n'
+        '    """A function with Literal overloads."""\n'
+        '    return 1 if x else "foo"\n'
+    )
+    
+    # Ensure the 'target' directory exists and is a package
+    target_dir = app.srcdir / 'target'
+    if not target_dir.exists():
+        target_dir.mkdir()
+    (target_dir / '__init__.py').write_text('', encoding='utf-8')
+    (target_dir / 'literal_typing.py').write_text(python_source, encoding='utf-8')
+
+    # Create the reStructuredText file to trigger autodoc
+    rst_source = (
+        '.. automodule:: target.literal_typing\n'
+        '   :members: foo\n'
+    )
+    (app.srcdir / 'index.rst').write_text(rst_source, encoding='utf-8')
+
+    # Run the Sphinx build.
+    app.build()
+
+    # This is the minimal assertion that fails now but will pass when fixed.
+    # It checks that the warning stream is empty, simulating a `-W` build.
+    warnings = app.warning.getvalue()
+    assert warnings == ''

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/python\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_literal.py
cat coverage.cover
git checkout 6c38f68dae221e8cfc70c137974b8b88bd3baaab
git apply /root/pre_state.patch
