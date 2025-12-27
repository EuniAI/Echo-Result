#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 81a4fd973d4cfcb25d01a7b0be62cdb28f82406d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 81a4fd973d4cfcb25d01a7b0be62cdb28f82406d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/extension.py b/sphinx/extension.py
--- a/sphinx/extension.py
+++ b/sphinx/extension.py
@@ -10,6 +10,8 @@
 
 from typing import TYPE_CHECKING, Any, Dict
 
+from packaging.version import InvalidVersion, Version
+
 from sphinx.config import Config
 from sphinx.errors import VersionRequirementError
 from sphinx.locale import __
@@ -51,7 +53,18 @@ def verify_needs_extensions(app: "Sphinx", config: Config) -> None:
                               'but it is not loaded.'), extname)
             continue
 
-        if extension.version == 'unknown version' or reqversion > extension.version:
+        fulfilled = True
+        if extension.version == 'unknown version':
+            fulfilled = False
+        else:
+            try:
+                if Version(reqversion) > Version(extension.version):
+                    fulfilled = False
+            except InvalidVersion:
+                if reqversion > extension.version:
+                    fulfilled = False
+
+        if not fulfilled:
             raise VersionRequirementError(__('This project needs the extension %s at least in '
                                              'version %s and therefore cannot be built with '
                                              'the loaded version (%s).') %

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_needs_extensions_version_comparison.py b/tests/test_needs_extensions_version_comparison.py
new file mode 100644
index 000000000..f9c5997bb
--- /dev/null
+++ b/tests/test_needs_extensions_version_comparison.py
@@ -0,0 +1,40 @@
+import sys
+from unittest.mock import Mock
+
+import pytest
+from sphinx.errors import VersionRequirementError
+
+
+def test_needs_extensions_version_comparison(make_app, monkeypatch):
+    """
+    Test that 'needs_extensions' version check handles versions > 9 correctly.
+
+    This test reproduces the bug where version strings are compared
+    lexicographically ('0.10.0' < '0.6.0'), leading to a false failure.
+    The test sets up a mock extension with version '0.10.0' and a requirement
+    for '0.6.0'.
+
+    With the bug, initializing the app raises a VersionRequirementError.
+    When the bug is fixed, version-aware comparison will be used, no error
+    will be raised, and this test will pass.
+    """
+    ext_name = 'ext_needs_ver_compare'
+    ext_module = Mock()
+    ext_module.setup.return_value = {
+        'version': '0.10.0',
+        'parallel_read_safe': True,
+        'parallel_write_safe': True,
+    }
+    monkeypatch.setitem(sys.modules, ext_name, ext_module)
+
+    confoverrides = {
+        'extensions': [ext_name],
+        'needs_extensions': {ext_name: '0.6.0'},
+    }
+
+    # This will fail with VersionRequirementError due to incorrect string comparison
+    # of the versions until the bug is fixed.
+    app = make_app(confoverrides=confoverrides)
+
+    # A minimal assertion to confirm the app was created successfully.
+    assert app is not None

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/extension\.py)' -m tox -epy39 -v -- tests/test_needs_extensions_version_comparison.py
cat coverage.cover
git checkout 81a4fd973d4cfcb25d01a7b0be62cdb28f82406d
git apply /root/pre_state.patch
