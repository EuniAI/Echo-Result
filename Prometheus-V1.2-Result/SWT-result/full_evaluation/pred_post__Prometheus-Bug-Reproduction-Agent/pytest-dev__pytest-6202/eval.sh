#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3a668ea6ff24b0c8f00498c3144c63bac561d925 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3a668ea6ff24b0c8f00498c3144c63bac561d925
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/_pytest/python.py b/src/_pytest/python.py
--- a/src/_pytest/python.py
+++ b/src/_pytest/python.py
@@ -285,8 +285,7 @@ def getmodpath(self, stopatmodule=True, includemodule=False):
                     break
             parts.append(name)
         parts.reverse()
-        s = ".".join(parts)
-        return s.replace(".[", "[")
+        return ".".join(parts)
 
     def reportinfo(self):
         # XXX caching?

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_nodeid_reporting.py b/testing/test_nodeid_reporting.py
new file mode 100644
index 000000000..22c57cc0d
--- /dev/null
+++ b/testing/test_nodeid_reporting.py
@@ -0,0 +1,30 @@
+import pytest
+
+
+def test_nodeid_special_chars_in_parametrize(testdir):
+    """
+    Tests that node IDs with special characters from parametrization are not
+    incorrectly modified in the report header.
+
+    This is a regression test for a bug where "..[" in a parameter name
+    was being replaced by ".[", causing an incorrect test headline.
+    """
+    testdir.makepyfile(
+        """
+        import pytest
+        @pytest.mark.parametrize("a", ["..["])
+        def test_boo(a):
+            assert 0
+        """
+    )
+    result = testdir.inline_run()
+
+    # The result object contains reports for setup, call, and teardown.
+    # We are interested in the 'call' report, which is the second one.
+    reports = result.getreports("pytest_runtest_logreport")
+    call_report = reports[1]
+
+    # The report's `location` attribute is a tuple (path, lineno, name).
+    # The `name` part is used for the test report headline and is where the bug manifests.
+    # We assert that the name is the expected 'test_boo[..[]' and not the buggy 'test_boo[.[]'.
+    assert call_report.location[2] == "test_boo[..[]"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/python\.py)' -m pytest -rA testing/test_nodeid_reporting.py
cat coverage.cover
git checkout 3a668ea6ff24b0c8f00498c3144c63bac561d925
git apply /root/pre_state.patch
