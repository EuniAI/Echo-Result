#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e856638ba086fcf5bebf1bebea32d5cf78de87b4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e856638ba086fcf5bebf1bebea32d5cf78de87b4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_collect_init.py b/testing/test_collect_init.py
new file mode 100644
index 000000000..c13ab3ee6
--- /dev/null
+++ b/testing/test_collect_init.py
@@ -0,0 +1,27 @@
+import pytest
+from _pytest.main import ExitCode
+
+
+def test_dont_collect_init_from_unrelated_pkg(testdir):
+    """
+    pytest should not collect/import __init__.py files from packages that
+    are not part of the test discovery.
+
+    Regression test for issue #5976.
+    """
+    # Recreate the scenario from the bug report: a directory with a failing
+    # __init__.py, which shouldn't be collected.
+    testdir.mkpydir("foobar")
+    testdir.tmpdir.join("foobar", "__init__.py").write("assert False")
+
+    # Add a test file so the run doesn't fail with "no tests collected".
+    testdir.makepyfile("def test_ok(): pass")
+
+    # When the bug is present, pytest tries to import foobar/__init__.py
+    # and fails with a collection error.
+    # When fixed, pytest should ignore it and run the tests.
+    result = testdir.runpytest()
+
+    # The correct behavior is for one test to pass. This assertion will fail
+    # until the bug is fixed.
+    result.assert_outcomes(passed=1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/python\.py)' -m pytest -rA testing/test_collect_init.py
cat coverage.cover
git checkout e856638ba086fcf5bebf1bebea32d5cf78de87b4
git apply /root/pre_state.patch
