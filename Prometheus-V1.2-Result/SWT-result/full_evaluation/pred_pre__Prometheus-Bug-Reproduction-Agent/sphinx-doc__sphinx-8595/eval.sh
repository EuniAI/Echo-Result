#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b19bce971e82f2497d67fdacdeca8db08ae0ba56 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b19bce971e82f2497d67fdacdeca8db08ae0ba56
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_empty_all.py b/tests/test_ext_autodoc_empty_all.py
new file mode 100644
index 000000000..7ea8ce444
--- /dev/null
+++ b/tests/test_ext_autodoc_empty_all.py
@@ -0,0 +1,52 @@
+import sys
+from unittest.mock import Mock
+
+import pytest
+
+from sphinx.ext.autodoc.directive import DocumenterBridge, process_documenter_options
+from sphinx.util.docutils import LoggingReporter
+
+
+def do_autodoc(app, objtype, name, options=None):
+    if options is None:
+        options = {}
+    app.env.temp_data.setdefault('docname', 'index')  # set dummy docname
+    doccls = app.registry.documenters[objtype]
+    docoptions = process_documenter_options(doccls, app.config, options)
+    state = Mock()
+    state.document.settings.tab_width = 8
+    bridge = DocumenterBridge(app.env, LoggingReporter(''), docoptions, 1, state)
+    documenter = doccls(bridge, name)
+    documenter.generate()
+
+    return bridge.result
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_autodoc_empty_all_ignored(app):
+    """
+    Tests that autodoc respects an empty __all__ attribute on a module.
+
+    This test monkey-patches the `target` module's `__all__` attribute to be an
+    empty list. With the bug, autodoc ignores the empty `__all__` and documents
+    members. A fixed version should respect the empty `__all__` and document
+    no members.
+    """
+    # The 'target' module is part of the testroot and is importable.
+    import target
+    original_all = getattr(target, '__all__', None)
+    target.__all__ = []
+    try:
+        options = {'members': None}
+        actual = do_autodoc(app, 'module', 'target', options)
+
+        # The bug causes members to be documented. The fix is that no members
+        # are documented. This assertion will fail if any class members are
+        # found in the output, and pass otherwise.
+        assert not [line for line in actual if '.. py:class::' in line]
+    finally:
+        # Restore the original __all__ to avoid side-effects.
+        if original_all is not None:
+            target.__all__ = original_all
+        else:
+            del target.__all__

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_empty_all.py
cat coverage.cover
git checkout b19bce971e82f2497d67fdacdeca8db08ae0ba56
git apply /root/pre_state.patch
