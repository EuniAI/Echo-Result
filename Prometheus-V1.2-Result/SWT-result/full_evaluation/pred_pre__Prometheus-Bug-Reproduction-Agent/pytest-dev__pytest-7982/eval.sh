#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7e38c5c61928033a2dc1915cbee8caa8544a4d0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7e38c5c61928033a2dc1915cbee8caa8544a4d0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_collection_symlinks.py b/testing/test_collection_symlinks.py
new file mode 100644
index 000000000..33bfd01ae
--- /dev/null
+++ b/testing/test_collection_symlinks.py
@@ -0,0 +1,30 @@
+import pytest
+from _pytest.pytester import Testdir
+from _pytest.pathlib import symlink_or_skip
+
+def test_collect_symlinked_dir_during_recursion(testdir: Testdir) -> None:
+    """
+    Tests that pytest follows symlinks to directories during collection.
+
+    This reproduces the bug where symlinked directories inside a collection
+    root are ignored.
+    """
+    # 1. Create a directory with tests *outside* the main project root.
+    real_tests_dir = testdir.mkdir("real_tests")
+    real_tests_dir.join("test_real.py").write("def test_it(): pass")
+
+    # 2. Create the project root for collection.
+    project_dir = testdir.mkdir("project_root")
+
+    # 3. Create a symlink from within the project to the external tests.
+    symlink_path = project_dir.join("linked_tests")
+    symlink_or_skip(real_tests_dir, symlink_path)
+
+    # 4. Run pytest from the project root. The only way to find the test
+    #    is to follow the symlink.
+    result = testdir.runpytest(str(project_dir))
+
+    # 5. The bug causes pytest to not follow the symlink, finding 0 tests.
+    #    This assertion will fail when the bug is present. When fixed,
+    #    the symlink is followed, the test is found, and this passes.
+    result.assert_outcomes(passed=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/pathlib\.py)' -m pytest -rA testing/test_collection_symlinks.py
cat coverage.cover
git checkout a7e38c5c61928033a2dc1915cbee8caa8544a4d0
git apply /root/pre_state.patch
