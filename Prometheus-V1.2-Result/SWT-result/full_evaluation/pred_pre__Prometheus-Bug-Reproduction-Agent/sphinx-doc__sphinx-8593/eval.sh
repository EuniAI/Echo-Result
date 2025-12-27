#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 07983a5a8704ad91ae855218ecbda1c8598200ca >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 07983a5a8704ad91ae855218ecbda1c8598200ca
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_autodata_private.py b/tests/test_ext_autodoc_autodata_private.py
new file mode 100644
index 000000000..13fa18065
--- /dev/null
+++ b/tests/test_ext_autodoc_autodata_private.py
@@ -0,0 +1,35 @@
+import pytest
+from .test_ext_autodoc import do_autodoc
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_autodata_private_variable_with_meta_public(app):
+    """Tests that a private variable with ``:meta public:`` is documented.
+
+    This test reproduces a bug where ``:meta public:`` was not respected for
+    module-level variables. It assumes a test module ``target.private_var``
+    exists with the content:
+
+    .. code-block:: python
+
+        _foo = None  #: :meta public:
+
+    When the bug is fixed, autodoc should document ``_foo`` when documenting
+    the module with the ``:members:`` option.
+    """
+    options = {
+        'members': '',
+    }
+    actual = do_autodoc(app, 'module', 'target.private_var', options)
+    assert list(actual) == [
+        '',
+        '.. py:module:: target.private_var',
+        '',
+        '',
+        '.. py:data:: _foo',
+        '   :module: target.private_var',
+        '   :value: None',
+        '',
+        '   :meta public:',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py|sphinx/ext/autodoc/importer\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_autodata_private.py
cat coverage.cover
git checkout 07983a5a8704ad91ae855218ecbda1c8598200ca
git apply /root/pre_state.patch
