#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 732d89c2940156bdc0e200bb36dc38b5e424bcba >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 732d89c2940156bdc0e200bb36dc38b5e424bcba
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_quantity_input_init_return_annotation.py b/astropy/units/tests/test_quantity_input_init_return_annotation.py
new file mode 100644
index 0000000000..bdd1a4e982
--- /dev/null
+++ b/astropy/units/tests/test_quantity_input_init_return_annotation.py
@@ -0,0 +1,22 @@
+import pytest
+from astropy import units as u
+
+
+def test_quantity_input_init_return_annotation_none():
+    """
+    Regression test for issue #7077.
+
+    Ensures that using quantity_input on a constructor (`__init__`)
+    with a `-> None` return annotation does not cause a crash.
+    """
+    class PoC:
+        @u.quantity_input
+        def __init__(self, voltage: u.V) -> None:
+            pass
+
+    # This line fails with an AttributeError before the fix.
+    # The test passes if this line executes without error.
+    instance = PoC(1. * u.V)
+
+    # Minimal assertion to prove the instance was created.
+    assert instance is not None

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/decorators\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_quantity_input_init_return_annotation.py
cat coverage.cover
git checkout 732d89c2940156bdc0e200bb36dc38b5e424bcba
git apply /root/pre_state.patch
