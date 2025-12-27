#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 939c7bb7ff7c53a4d27df067cea637540f0e1dad >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 939c7bb7ff7c53a4d27df067cea637540f0e1dad
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_classmethod_property.py b/tests/test_ext_autodoc_classmethod_property.py
new file mode 100644
index 000000000..58cf38533
--- /dev/null
+++ b/tests/test_ext_autodoc_classmethod_property.py
@@ -0,0 +1,67 @@
+import sys
+from unittest.mock import Mock
+
+import pytest
+from docutils.statemachine import ViewList
+
+from sphinx.ext.autodoc import Options
+from sphinx.ext.autodoc.directive import DocumenterBridge, process_documenter_options
+from sphinx.testing.util import SphinxTestApp
+from sphinx.util.docutils import LoggingReporter
+
+
+def do_autodoc(app: SphinxTestApp, objtype: str, name: str, options: dict = None):
+    """
+    Helper function to run an autodoc documenter.
+    """
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
+@pytest.mark.skipif(sys.version_info < (3, 9), reason='@classmethod+@property is available on py39+')
+@pytest.mark.sphinx('html', testroot='ext-autodoc')
+def test_classmethod_property(app: SphinxTestApp):
+    """
+    Test that methods decorated with @classmethod and @property are documented.
+    """
+    from target.properties import Foo
+
+    @classmethod
+    @property
+    def classprop(cls):
+        """class property docstring"""
+        return "foo"
+
+    Foo.classprop = classprop
+
+    try:
+        options = {
+            "members": "classprop",
+        }
+        actual = do_autodoc(app, 'class', 'target.properties.Foo', options)
+        assert list(actual) == [
+            '',
+            '.. py:class:: Foo()',
+            '   :module: target.properties',
+            '',
+            '   docstring',
+            '',
+            '',
+            '   .. py:property:: Foo.classprop',
+            '      :module: target.properties',
+            '',
+            '      class property docstring',
+            '',
+        ]
+    finally:
+        del Foo.classprop

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py|sphinx/domains/python\.py|sphinx/util/inspect\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_classmethod_property.py
cat coverage.cover
git checkout 939c7bb7ff7c53a4d27df067cea637540f0e1dad
git apply /root/pre_state.patch
