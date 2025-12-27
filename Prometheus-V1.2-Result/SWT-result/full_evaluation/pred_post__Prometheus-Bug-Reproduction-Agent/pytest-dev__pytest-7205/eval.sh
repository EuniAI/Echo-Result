#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5e7f1ab4bf58e473e5d7f878eb2b499d7deabd29 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5e7f1ab4bf58e473e5d7f878eb2b499d7deabd29
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/_pytest/setuponly.py b/src/_pytest/setuponly.py
--- a/src/_pytest/setuponly.py
+++ b/src/_pytest/setuponly.py
@@ -1,4 +1,5 @@
 import pytest
+from _pytest._io.saferepr import saferepr
 
 
 def pytest_addoption(parser):
@@ -66,7 +67,7 @@ def _show_fixture_action(fixturedef, msg):
             tw.write(" (fixtures used: {})".format(", ".join(deps)))
 
     if hasattr(fixturedef, "cached_param"):
-        tw.write("[{}]".format(fixturedef.cached_param))
+        tw.write("[{}]".format(saferepr(fixturedef.cached_param, maxsize=42)))
 
     tw.flush()
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_show_fixtures.py b/testing/test_show_fixtures.py
new file mode 100644
index 000000000..95f54c1bf
--- /dev/null
+++ b/testing/test_show_fixtures.py
@@ -0,0 +1,33 @@
+import pytest
+import sys
+
+
+def test_show_fixtures_with_bytes_parameter(testdir):
+    """
+    A BytesWarning is raised when using --setup-show with a bytes parameter.
+
+    The -bb flag is used to treat BytesWarning as an error, which is how the
+    bug is triggered in the issue report. The test should fail with a non-zero
+    exit code and report the BytesWarning in stderr.
+
+    This test was corrected to pass the '-bb' flag to the python interpreter
+    instead of to pytest.
+    """
+    p = testdir.makepyfile(
+        """
+        import pytest
+
+        @pytest.mark.parametrize('data', [b'Hello World'])
+        def test_data(data):
+            pass
+        """
+    )
+
+    # The command `python -bb -m pytest ...` is constructed manually to ensure
+    # -bb is passed to the interpreter.
+    result = testdir.run(sys.executable, "-bb", "-m", "pytest", "--setup-show", p.strpath)
+
+    # The -bb flag promotes the BytesWarning to an error, so pytest should exit
+    # with a non-zero status code.
+    assert result.ret != 0
+    result.stderr.fnmatch_lines(["*BytesWarning: str() on a bytes instance*"])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/setuponly\.py)' -m pytest -rA testing/test_show_fixtures.py
cat coverage.cover
git checkout 5e7f1ab4bf58e473e5d7f878eb2b499d7deabd29
git apply /root/pre_state.patch
