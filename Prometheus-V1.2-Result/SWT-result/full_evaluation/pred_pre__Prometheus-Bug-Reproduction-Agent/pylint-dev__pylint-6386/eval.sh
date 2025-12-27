#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 754b487f4d892e3d4872b6fc7468a71db4e31c13 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 754b487f4d892e3d4872b6fc7468a71db4e31c13
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/config/test_command_line_options.py b/tests/config/test_command_line_options.py
new file mode 100644
index 000000000..49982a14d
--- /dev/null
+++ b/tests/config/test_command_line_options.py
@@ -0,0 +1,16 @@
+import pytest
+from pylint.lint import Run
+
+def test_short_verbose_option_no_argument(tmp_path):
+    """
+    Test that the short verbose option '-v' does not require an argument.
+
+    This is a regression test for https://github.com/pylint-dev/pylint/issues/5753.
+    The bug causes pylint to exit with an argparse error when '-v' is used
+    without a value. A successful run should exit with code 0.
+    """
+    module = tmp_path / "mytest.py"
+    module.touch()
+    with pytest.raises(SystemExit) as ex:
+        Run([str(module), "-v"])
+    assert ex.value.code == 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/config/argument\.py|pylint/lint/base_options\.py|pylint/config/arguments_manager\.py|pylint/config/utils\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/config/test_command_line_options.py
cat coverage.cover
git checkout 754b487f4d892e3d4872b6fc7468a71db4e31c13
git apply /root/pre_state.patch
