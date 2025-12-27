#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 955e54221008aba577ecbaefa15679f6777d3bf8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 955e54221008aba577ecbaefa15679f6777d3bf8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_hooks.py b/testing/test_hooks.py
new file mode 100644
index 000000000..e30ec644e
--- /dev/null
+++ b/testing/test_hooks.py
@@ -0,0 +1,72 @@
+import pytest
+from _pytest.reports import TestReport
+
+
+class TestHooks:
+    """Test that the hooks are working correctly for plugins"""
+
+    def test_test_report(self, testdir, pytestconfig):
+        testdir.makepyfile(
+            """
+            def test_a(): assert False
+            def test_b(): pass
+        """
+        )
+        reprec = testdir.inline_run()
+        reports = reprec.getreports("pytest_runtest_logreport")
+        assert len(reports) == 6
+        for rep in reports:
+            data = pytestconfig.hook.pytest_report_to_serializable(
+                config=pytestconfig, report=rep
+            )
+            assert data["_report_type"] == "TestReport"
+            new_rep = pytestconfig.hook.pytest_report_from_serializable(
+                config=pytestconfig, data=data
+            )
+            assert new_rep.nodeid == rep.nodeid
+            assert new_rep.when == rep.when
+            assert new_rep.outcome == rep.outcome
+
+    def test_chained_exception_report_serialization(self, testdir, pytestconfig):
+        """
+        Test that chained exceptions are correctly serialized and deserialized
+        via the pytest_report_to_serializable hook, which is used by xdist.
+        This reproduces issue #4032.
+        """
+        testdir.makepyfile(
+            """
+            def test_chained_exception_with_from():
+                try:
+                    try:
+                        raise ValueError(11)
+                    except Exception as e1:
+                        raise ValueError(12) from e1
+                except Exception as e2:
+                    raise ValueError(13) from e2
+            """
+        )
+        reprec = testdir.inline_run()
+
+        failed_report = [
+            rep
+            for rep in reprec.getreports("pytest_runtest_logreport")
+            if rep.when == "call"
+        ][0]
+
+        # Sanity check that the original report has the exception chain.
+        # The final exception (13) is caused by exception 12, which is caused by 11.
+        # So the chain of the final exception should have 2 entries.
+        assert len(failed_report.longrepr.chain) == 2
+
+        # Simulate xdist: serialize the report on the worker.
+        data = pytestconfig.hook.pytest_report_to_serializable(
+            config=pytestconfig, report=failed_report
+        )
+
+        # Simulate xdist: deserialize the report on the master.
+        new_report = pytestconfig.hook.pytest_report_from_serializable(
+            config=pytestconfig, data=data
+        )
+
+        # This will fail if the chain is lost during serialization.
+        assert len(new_report.longrepr.chain) == 2

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/reports\.py)' -m pytest -rA testing/test_hooks.py
cat coverage.cover
git checkout 955e54221008aba577ecbaefa15679f6777d3bf8
git apply /root/pre_state.patch
