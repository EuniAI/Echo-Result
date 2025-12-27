#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD dd1615c59dc6fff633e27dbb3861f2d27e1fb976 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff dd1615c59dc6fff633e27dbb3861f2d27e1fb976
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_inherited_attribute.py b/tests/test_ext_autodoc_inherited_attribute.py
new file mode 100644
index 000000000..a8e50e0cf
--- /dev/null
+++ b/tests/test_ext_autodoc_inherited_attribute.py
@@ -0,0 +1,36 @@
+import pytest
+from .test_ext_autodoc import do_autodoc
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_inherited_attribute(app):
+    """Test for inherited attributes"""
+    (app.srcdir / 'target' / 'inheritance_attr.py').write_text(
+        'class Base:\n'
+        '    #: docstring for attr\n'
+        '    attr = 1\n\n'
+        'class Derived(Base):\n'
+        '    """Docstring for Derived."""\n'
+        '    pass\n',
+        encoding='utf-8'
+    )
+    options = {
+        'members': True,
+        'inherited-members': True,
+    }
+    actual = do_autodoc(app, 'class', 'target.inheritance_attr.Derived', options)
+    assert list(actual) == [
+        '',
+        '.. py:class:: Derived()',
+        '   :module: target.inheritance_attr',
+        '',
+        '   Docstring for Derived.',
+        '',
+        '',
+        '   .. py:attribute:: Derived.attr',
+        '      :module: target.inheritance_attr',
+        '      :value: 1',
+        '',
+        '      docstring for attr',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py|sphinx/ext/autodoc/importer\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_inherited_attribute.py
cat coverage.cover
git checkout dd1615c59dc6fff633e27dbb3861f2d27e1fb976
git apply /root/pre_state.patch
