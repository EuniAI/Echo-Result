#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 232dbe41c5250eb7d559d40438c4743483e95f15 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 232dbe41c5250eb7d559d40438c4743483e95f15
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_show_inheritance.py b/tests/test_ext_autodoc_show_inheritance.py
new file mode 100644
index 000000000..ad2a727ad
--- /dev/null
+++ b/tests/test_ext_autodoc_show_inheritance.py
@@ -0,0 +1,33 @@
+import pytest
+
+from .test_ext_autodoc import do_autodoc
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_show_inheritance_for_subclass_of_mocked_class(app):
+    """
+    Test that the base class is rendered correctly for a class that inherits
+    from a mocked class, when the 'show-inheritance' option is used.
+    """
+    # All missing modules in the target file must be mocked for it to be importable.
+    app.config.autodoc_mock_imports = [
+        "missing_module",
+        "missing_package1",
+        "missing_package2",
+        "missing_package3",
+        "sphinx.missing_module4",
+    ]
+    options = {
+        'show-inheritance': None,
+    }
+    actual = do_autodoc(app, 'class', 'target.need_mocks.Inherited', options)
+    assert list(actual) == [
+        '',
+        '.. py:class:: Inherited()',
+        '   :module: target.need_mocks',
+        '',
+        '   Bases: :py:class:`missing_module.Class`',
+        '',
+        '   docstring',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/mock\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_show_inheritance.py
cat coverage.cover
git checkout 232dbe41c5250eb7d559d40438c4743483e95f15
git apply /root/pre_state.patch
