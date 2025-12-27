#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7141cd90019b62688d507ae056298507678c058 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7141cd90019b62688d507ae056298507678c058
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/utils/tests/test_minversion_dev.py b/astropy/utils/tests/test_minversion_dev.py
new file mode 100644
index 0000000000..7ac4e3faf1
--- /dev/null
+++ b/astropy/utils/tests/test_minversion_dev.py
@@ -0,0 +1,16 @@
+import pytest
+from types import ModuleType
+from astropy.utils.introspection import minversion
+
+
+def test_minversion_dev_comparison():
+    """
+    Test that minversion can handle 'dev' versions.
+
+    This is a regression test for a bug that caused a TypeError when
+    comparing a version like '1.14.3' with '1.14dev' due to a bug in
+    distutils.LooseVersion.
+    """
+    test_module = ModuleType(str("test_module"))
+    test_module.__version__ = '1.14.3'
+    assert minversion(test_module, '1.14dev')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/utils/introspection\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/utils/tests/test_minversion_dev.py
cat coverage.cover
git checkout a7141cd90019b62688d507ae056298507678c058
git apply /root/pre_state.patch
