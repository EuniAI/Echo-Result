#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 26224d96066b5c60882296c551f54ca7732c0af0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 26224d96066b5c60882296c551f54ca7732c0af0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_text_antialiased.py b/lib/matplotlib/tests/test_text_antialiased.py
new file mode 100644
index 0000000000..2456727ef3
--- /dev/null
+++ b/lib/matplotlib/tests/test_text_antialiased.py
@@ -0,0 +1,13 @@
+import matplotlib as mpl
+from matplotlib import rcParams
+
+def test_text_antialiased():
+    """Test that Text antialiased getter/setter work."""
+    # This is based on test_default_antialiased for patches.
+    t = mpl.text.Text(0, 0, "hello")
+    # Check that we can toggle it.
+    t.set_antialiased(not rcParams['text.antialiased'])
+    assert t.get_antialiased() == (not rcParams['text.antialiased'])
+    # Check that None resets it.
+    t.set_antialiased(None)
+    assert t.get_antialiased() == rcParams['text.antialiased']

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/text\.py|lib/matplotlib/backends/backend_agg\.py|lib/matplotlib/backends/backend_cairo\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_text_antialiased.py
cat coverage.cover
git checkout 26224d96066b5c60882296c551f54ca7732c0af0
git apply /root/pre_state.patch
