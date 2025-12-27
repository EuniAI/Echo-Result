#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3c5eca2ded3dd2b59ebaf23eb289453b5d2930f0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3c5eca2ded3dd2b59ebaf23eb289453b5d2930f0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/pylint/lint/expand_modules.py b/pylint/lint/expand_modules.py
--- a/pylint/lint/expand_modules.py
+++ b/pylint/lint/expand_modules.py
@@ -52,6 +52,7 @@ def _is_ignored_file(
     ignore_list_re: list[Pattern[str]],
     ignore_list_paths_re: list[Pattern[str]],
 ) -> bool:
+    element = os.path.normpath(element)
     basename = os.path.basename(element)
     return (
         basename in ignore_list

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/lint/test_expand_modules_recursive_ignore.py b/tests/lint/test_expand_modules_recursive_ignore.py
new file mode 100644
index 000000000..3847f9179
--- /dev/null
+++ b/tests/lint/test_expand_modules_recursive_ignore.py
@@ -0,0 +1,115 @@
+# Licensed under the GPL: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
+# For details: https://github.com/PyCQA/pylint/blob/main/LICENSE
+# Copyright (c) https://github.com/PyCQA/pylint/blob/main/CONTRIBUTORS.txt
+
+from __future__ import annotations
+
+import re
+from pathlib import Path
+
+import pytest
+
+from pylint.checkers import BaseChecker
+from pylint.lint.expand_modules import _is_in_ignore_list_re, expand_modules
+from pylint.testutils import CheckerTestCase, set_config
+from pylint.typing import MessageDefinitionTuple
+
+TEST_DIRECTORY = Path(__file__).parent.parent
+INIT_PATH = str(TEST_DIRECTORY / "lint/__init__.py")
+EXPAND_MODULES = str(TEST_DIRECTORY / "lint/unittest_expand_modules.py")
+this_file = {
+    "basename": "lint.unittest_expand_modules",
+    "basepath": EXPAND_MODULES,
+    "isarg": True,
+    "name": "lint.unittest_expand_modules",
+    "path": EXPAND_MODULES,
+}
+
+this_file_from_init = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": False,
+    "name": "lint.unittest_expand_modules",
+    "path": EXPAND_MODULES,
+}
+
+unittest_lint = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": False,
+    "name": "lint.unittest_lint",
+    "path": str(TEST_DIRECTORY / "lint/unittest_lint.py"),
+}
+
+test_utils = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": False,
+    "name": "lint.test_utils",
+    "path": str(TEST_DIRECTORY / "lint/test_utils.py"),
+}
+
+test_pylinter = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": False,
+    "name": "lint.test_pylinter",
+    "path": str(TEST_DIRECTORY / "lint/test_pylinter.py"),
+}
+
+test_caching = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": False,
+    "name": "lint.test_caching",
+    "path": str(TEST_DIRECTORY / "lint/test_caching.py"),
+}
+
+
+init_of_package = {
+    "basename": "lint",
+    "basepath": INIT_PATH,
+    "isarg": True,
+    "name": "lint",
+    "path": INIT_PATH,
+}
+
+
+class TestExpandModules(CheckerTestCase):
+    """Test the expand_modules function while allowing options to be set."""
+
+    class Checker(BaseChecker):
+        """This dummy checker is needed to allow options to be set."""
+
+        name = "checker"
+        msgs: dict[str, MessageDefinitionTuple] = {}
+        options = (("test-opt", {"action": "store_true", "help": "help message"}),)
+
+    CHECKER_CLASS: type = Checker
+
+    @set_config(recursive=True, ignore_paths=r".*tests[\/]lint[\/]unittest_lint\.py")
+    def test_recursive_with_ignore_paths_respects_ignore(self) -> None:
+        """Test that recursive discovery respects ignore-paths.
+
+        Regression test for https://github.com/PyCQA/pylint/issues/7094
+        """
+        files_or_modules = [str(TEST_DIRECTORY / "lint")]
+        expected = [
+            init_of_package,
+            test_caching,
+            test_pylinter,
+            test_utils,
+            this_file_from_init,
+        ]
+
+        modules, errors = expand_modules(
+            files_or_modules,
+            [],
+            [],
+            self.linter.config.ignore_paths,
+        )
+        modules.sort(key=lambda d: d["name"])
+        expected.sort(key=lambda d: d["name"])
+
+        assert modules == expected
+        assert not errors

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/lint/expand_modules\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/lint/test_expand_modules_recursive_ignore.py
cat coverage.cover
git checkout 3c5eca2ded3dd2b59ebaf23eb289453b5d2930f0
git apply /root/pre_state.patch
