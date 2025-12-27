#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 68aa4fb29e7dfe521749e1e14f750d7afabb3481 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 68aa4fb29e7dfe521749e1e14f750d7afabb3481
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/ext/autodoc/typehints.py b/sphinx/ext/autodoc/typehints.py
--- a/sphinx/ext/autodoc/typehints.py
+++ b/sphinx/ext/autodoc/typehints.py
@@ -27,7 +27,7 @@ def record_typehints(app: Sphinx, objtype: str, name: str, obj: Any,
         if callable(obj):
             annotations = app.env.temp_data.setdefault('annotations', {})
             annotation = annotations.setdefault(name, OrderedDict())
-            sig = inspect.signature(obj)
+            sig = inspect.signature(obj, type_aliases=app.config.autodoc_type_aliases)
             for param in sig.parameters.values():
                 if param.annotation is not param.empty:
                     annotation[param.name] = typing.stringify(param.annotation)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_type_aliases.py b/tests/test_ext_autodoc_type_aliases.py
new file mode 100644
index 000000000..d3ad353fa
--- /dev/null
+++ b/tests/test_ext_autodoc_type_aliases.py
@@ -0,0 +1,53 @@
+import sys
+import pytest
+from sphinx.testing.util import SphinxTestApp
+
+@pytest.mark.skipif(sys.version_info < (3, 7), reason='python 3.7+ is required.')
+@pytest.mark.sphinx(
+    'text',
+    testroot='ext-autodoc',
+    freshenv=True,
+    confoverrides={
+        'autodoc_typehints': 'description',
+        'autodoc_type_aliases': {
+            'JSONObject': 'project_types.JSONObject',
+        },
+        'extensions': ['sphinx.ext.autodoc', 'sphinx.ext.napoleon'],
+    }
+)
+def test_autodoc_type_aliases_with_typehints_description(app: SphinxTestApp):
+    """
+    Test that autodoc_type_aliases works with autodoc_typehints = 'description'.
+    Regression test for sphinx-doc/sphinx#8233.
+    """
+    (app.srcdir / 'project_types.py').write_text(
+        'from __future__ import annotations\n'
+        'from typing import Any, Dict\n'
+        '\n'
+        'JSONObject = Dict[str, Any]\n'
+        '\n'
+        'def sphinx_doc(data: JSONObject) -> JSONObject:\n'
+        '    """Does it work.\n'
+        '\n'
+        '    Args:\n'
+        '        data: Does it args.\n'
+        '\n'
+        '    Returns:\n'
+        '        Does it work in return.\n'
+        '    """\n'
+        '    return {}\n',
+        encoding='utf-8'
+    )
+    (app.srcdir / 'index.rst').write_text(
+        '.. autofunction:: project_types.sphinx_doc\n',
+        encoding='utf-8'
+    )
+
+    app.build()
+
+    content = (app.outdir / 'index.txt').read_text(encoding='utf-8')
+
+    # This assertion will fail with the bug, showing Dict[str, Any] instead.
+    # When the bug is fixed, it will correctly show the aliased type.
+    expected_param_line = '* **data** (*project_types.JSONObject*) – Does it args.'
+    assert expected_param_line in content

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/typehints\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_type_aliases.py
cat coverage.cover
git checkout 68aa4fb29e7dfe521749e1e14f750d7afabb3481
git apply /root/pre_state.patch
