#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ec9af606c6cfa515f946d74da9b51574f2f9b16f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ec9af606c6cfa515f946d74da9b51574f2f9b16f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_mock_generic_subclass.py b/tests/test_ext_autodoc_mock_generic_subclass.py
new file mode 100644
index 000000000..ea9275b12
--- /dev/null
+++ b/tests/test_ext_autodoc_mock_generic_subclass.py
@@ -0,0 +1,27 @@
+import pytest
+from typing import TypeVar
+
+from sphinx.ext.autodoc.mock import _MockObject
+
+
+def test_mock_subclassing_generic_class():
+    """
+    Tests that creating a subclass of a mocked generic type does not raise a
+    TypeError.
+
+    This test reproduces the bug where ``_make_subclass`` attempts to
+    concatenate a string with a ``TypeVar``, which previously caused documentation
+    generation to fail for projects using generic-typed classes.
+    """
+    T = TypeVar('T')
+    mock_generic_class = _MockObject()
+    mock_generic_class.__display_name__ = 'mocked.Generic'
+
+    # This line triggers the TypeError in the buggy version, as it calls
+    # _make_subclass with a TypeVar, leading to an invalid concatenation.
+    generic_alias = mock_generic_class[T]
+
+    # This assertion will fail with a TypeError before the fix, and pass after.
+    # It checks that the returned object is a _MockObject with the correct
+    # name, which is expected behavior for a mocked generic alias.
+    assert repr(generic_alias) == 'mocked.Generic.~T'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/mock\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_mock_generic_subclass.py
cat coverage.cover
git checkout ec9af606c6cfa515f946d74da9b51574f2f9b16f
git apply /root/pre_state.patch
