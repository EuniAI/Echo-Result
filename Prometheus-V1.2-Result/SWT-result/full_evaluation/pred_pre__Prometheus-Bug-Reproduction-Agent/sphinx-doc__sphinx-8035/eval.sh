#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5e6da19f0e44a0ae83944fb6ce18f18f781e1a6e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5e6da19f0e44a0ae83944fb6ce18f18f781e1a6e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_private_members_specific.py b/tests/test_ext_autodoc_private_members_specific.py
new file mode 100644
index 000000000..f68483ac5
--- /dev/null
+++ b/tests/test_ext_autodoc_private_members_specific.py
@@ -0,0 +1,26 @@
+import pytest
+
+from test_ext_autodoc import do_autodoc
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_private_members_specific_members(app):
+    """Test "private-members" option with specific members."""
+    app.config.autoclass_content = 'class'
+    options = {
+        'private-members': 'private_function',
+    }
+    actual = do_autodoc(app, 'module', 'target.private', options)
+    assert list(actual) == [
+        '',
+        '.. py:module:: target.private',
+        '',
+        '',
+        '.. py:function:: private_function(name)',
+        '   :module: target.private',
+        '',
+        '   private_function is a docstring().',
+        '',
+        '   :meta private:',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_private_members_specific.py
cat coverage.cover
git checkout 5e6da19f0e44a0ae83944fb6ce18f18f781e1a6e
git apply /root/pre_state.patch
