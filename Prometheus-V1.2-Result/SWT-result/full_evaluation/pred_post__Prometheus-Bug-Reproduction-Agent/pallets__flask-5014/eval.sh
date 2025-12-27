#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7ee9ceb71e868944a46e1ff00b506772a53a4f1d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7ee9ceb71e868944a46e1ff00b506772a53a4f1d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/flask/blueprints.py b/src/flask/blueprints.py
--- a/src/flask/blueprints.py
+++ b/src/flask/blueprints.py
@@ -190,6 +190,9 @@ def __init__(
             root_path=root_path,
         )
 
+        if not name:
+            raise ValueError("'name' may not be empty.")
+
         if "." in name:
             raise ValueError("'name' may not contain a dot '.' character.")
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_blueprint_errors.py b/tests/test_blueprint_errors.py
new file mode 100644
index 00000000..373e7c72
--- /dev/null
+++ b/tests/test_blueprint_errors.py
@@ -0,0 +1,10 @@
+import pytest
+import flask
+
+
+def test_empty_blueprint_name(app):
+    """Test that creating a blueprint with an empty name raises a
+    ValueError.
+    """
+    with pytest.raises(ValueError):
+        flask.Blueprint("", __name__)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/flask/blueprints\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_blueprint_errors.py
cat coverage.cover
git checkout 7ee9ceb71e868944a46e1ff00b506772a53a4f1d
git apply /root/pre_state.patch
