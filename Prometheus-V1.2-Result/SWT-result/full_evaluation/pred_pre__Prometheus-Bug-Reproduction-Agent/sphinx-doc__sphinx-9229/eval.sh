#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 876fa81e0a038cda466925b85ccf6c5452e0f685 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 876fa81e0a038cda466925b85ccf6c5452e0f685
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_type_alias.py b/tests/test_ext_autodoc_type_alias.py
new file mode 100644
index 000000000..8d194f33a
--- /dev/null
+++ b/tests/test_ext_autodoc_type_alias.py
@@ -0,0 +1,76 @@
+import pytest
+import sys
+from unittest.mock import Mock
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
+def test_type_alias_docstring_inconsistency(app):
+    """Test that docstrings for all type aliases are consistently displayed."""
+    (app.srcdir / 'target' / 'type_alias_issue.py').write_text(
+        'from pathlib import Path\n'
+        'from typing import Any, Callable, Dict, Union\n'
+        '\n'
+        'ScaffoldOpts = Dict[str, Any]\n'
+        '"""Docstring for ScaffoldOpts."""\n'
+        '\n'
+        'FileContents = Union[str, None]\n'
+        '"""Docstring for FileContents."""\n'
+        '\n'
+        'FileOp = Callable[[Path, FileContents, ScaffoldOpts], Union[Path, None]]\n'
+        '"""Docstring for FileOp."""\n',
+        encoding='utf-8'
+    )
+
+    options = {"members": None}
+    actual = do_autodoc(app, 'module', 'target.type_alias_issue', options)
+
+    assert list(actual) == [
+        '',
+        '.. py:module:: target.type_alias_issue',
+        '',
+        '',
+        '.. py:data:: FileContents',
+        '   :module: target.type_alias_issue',
+        '',
+        '   Docstring for FileContents.',
+        '',
+        '   alias of :class:`~typing.Union`\[:class:`str`, :obj:`None`]',
+        '',
+        '',
+        '.. py:data:: FileOp',
+        '   :module: target.type_alias_issue',
+        '',
+        '   Docstring for FileOp.',
+        '',
+        '   alias of :class:`~typing.Callable`\[\[:class:`~pathlib.Path`, '
+        ':class:`~typing.Union`\[:class:`str`, :obj:`None`], '
+        ':class:`~typing.Dict`\[:class:`str`, :class:`~typing.Any`]], '
+        ':class:`~typing.Union`\[:class:`~pathlib.Path`, :obj:`None`]]',
+        '',
+        '',
+        '.. py:data:: ScaffoldOpts',
+        '   :module: target.type_alias_issue',
+        '',
+        '   Docstring for ScaffoldOpts.',
+        '',
+        '   alias of :class:`~typing.Dict`\[:class:`str`, :class:`~typing.Any`]',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_type_alias.py
cat coverage.cover
git checkout 876fa81e0a038cda466925b85ccf6c5452e0f685
git apply /root/pre_state.patch
