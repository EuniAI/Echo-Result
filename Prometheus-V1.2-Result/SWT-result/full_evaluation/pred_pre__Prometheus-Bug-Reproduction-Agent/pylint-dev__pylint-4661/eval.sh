#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1d1619ef913b99b06647d2030bddff4800abdf63 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1d1619ef913b99b06647d2030bddff4800abdf63
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_xdg_data_directory.py b/tests/test_xdg_data_directory.py
new file mode 100644
index 000000000..31d76b8b3
--- /dev/null
+++ b/tests/test_xdg_data_directory.py
@@ -0,0 +1,38 @@
+import importlib
+import os
+
+from pylint import config
+
+
+def test_pylint_data_directory_follows_xdg_specification(tmp_path, monkeypatch):
+    """
+    Test that pylint creates its data directory according to the XDG Base
+    Directory Specification.
+
+    This test will fail until the bug is fixed. The desired behavior is for
+    pylint to create its data directory inside ~/.local/share/pylint/
+    when XDG_DATA_HOME is not set.
+    """
+    # 1. Set up a fake home directory for the test
+    home_dir = tmp_path / "home"
+    home_dir.mkdir()
+    expected_xdg_data_dir = home_dir / ".local" / "share" / "pylint"
+
+    # 2. Patch environment variables to simulate a clean user environment
+    #    - Set HOME to our fake home directory.
+    #    - Unset PYLINTHOME and XDG_DATA_HOME to test the default behavior.
+    monkeypatch.setenv("HOME", str(home_dir))
+    monkeypatch.delenv("PYLINTHOME", raising=False)
+    monkeypatch.delenv("XDG_DATA_HOME", raising=False)
+
+    # 3. Reload the config module to pick up the patched environment variables.
+    #    This is necessary because PYLINT_HOME is determined at import time.
+    importlib.reload(config)
+
+    # 4. Call a function that triggers the creation of the data directory.
+    config.save_results(results={}, base="test_run")
+
+    # 5. Assert that the XDG-compliant data directory is created.
+    #    This assertion will fail because pylint currently creates ~/.pylint.d
+    #    instead. It will pass once the bug is fixed.
+    assert expected_xdg_data_dir.is_dir()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/config/__init__\.py|setup\.cfg)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_xdg_data_directory.py
cat coverage.cover
git checkout 1d1619ef913b99b06647d2030bddff4800abdf63
git apply /root/pre_state.patch
