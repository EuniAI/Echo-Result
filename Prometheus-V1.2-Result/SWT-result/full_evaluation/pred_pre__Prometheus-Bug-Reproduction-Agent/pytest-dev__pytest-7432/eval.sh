#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e6e300e729dd33956e5448d8be9a0b1540b4e53a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e6e300e729dd33956e5448d8be9a0b1540b4e53a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_skip_location_reporting.py b/testing/test_skip_location_reporting.py
new file mode 100644
index 000000000..725abc426
--- /dev/null
+++ b/testing/test_skip_location_reporting.py
@@ -0,0 +1,22 @@
+import pytest
+
+
+def test_skip_location_reporting_runxfail(testdir):
+    """--runxfail should not break skip location reporting.
+
+    Regression test for issue #7249.
+    """
+    p1 = testdir.makepyfile(
+        """
+        import pytest
+        @pytest.mark.skip
+        def test_skip_location() -> None:
+            assert 0
+    """
+    )
+    result = testdir.runpytest("-rs", "--runxfail")
+    result.stdout.fnmatch_lines(
+        [
+            "SKIPPED [[]1[]] {}:3: unconditional skip".format(p1.basename),
+        ]
+    )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/skipping\.py)' -m pytest -rA testing/test_skip_location_reporting.py
cat coverage.cover
git checkout e6e300e729dd33956e5448d8be9a0b1540b4e53a
git apply /root/pre_state.patch
