#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5fb51fb1467dc5eea7505402c3c5d9b378d3b441 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5fb51fb1467dc5eea7505402c3c5d9b378d3b441
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_napoleon_autodoc_typehints.py b/tests/test_ext_napoleon_autodoc_typehints.py
new file mode 100644
index 000000000..aa989d1b5
--- /dev/null
+++ b/tests/test_ext_napoleon_autodoc_typehints.py
@@ -0,0 +1,61 @@
+import pytest
+import textwrap
+
+
+@pytest.mark.sphinx(
+    'text',
+    testroot='ext-autodoc',
+    confoverrides={
+        'extensions': ['sphinx.ext.autodoc', 'sphinx.ext.napoleon'],
+        'autodoc_typehints': 'description',
+        'autodoc_typehints_description_target': 'documented',
+        'napoleon_numpy_docstring': False,
+    }
+)
+def test_napoleon_autodoc_typehints_description_target(app):
+    """
+    Test that for Google style docstrings, with
+    autodoc_typehints_description_target='documented', the return type is
+    included in the documentation when the return section is present.
+
+    This is a regression test for https://github.com/sphinx-doc/sphinx/issues/9735
+    """
+    python_code = textwrap.dedent('''
+        def my_function(arg1: int) -> str:
+            """A summary.
+
+            Args:
+                arg1: The first argument.
+
+            Returns:
+                The return value.
+            """
+            return str(arg1)
+    ''')
+    (app.srcdir / 'module.py').write_text(python_code, encoding='utf8')
+
+    rst_content = textwrap.dedent('''
+        .. automodule:: module
+           :members:
+    ''')
+    (app.srcdir / 'index.rst').write_text(rst_content, encoding='utf8')
+
+    app.build()
+
+    output = (app.outdir / 'index.txt').read_text(encoding='utf8')
+
+    expected_output = (
+        "module.my_function(arg1)\n"
+        "\n"
+        "   A summary.\n"
+        "\n"
+        "   Parameters:\n"
+        "      **arg1** (*int*) -- The first argument.\n"
+        "\n"
+        "   Returns:\n"
+        "      The return value.\n"
+        "\n"
+        "   Return type:\n"
+        "      str\n"
+    )
+    assert expected_output in output

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/typehints\.py)' -m tox -epy39 -v -- tests/test_ext_napoleon_autodoc_typehints.py
cat coverage.cover
git checkout 5fb51fb1467dc5eea7505402c3c5d9b378d3b441
git apply /root/pre_state.patch
