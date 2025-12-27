#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1e55ae64624d28c5fe8b63ad7979880ee2e6ef3f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1e55ae64624d28c5fe8b63ad7979880ee2e6ef3f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/functional/r/regression/regression_4510_unused_import_type_comment.py b/tests/functional/r/regression/regression_4510_unused_import_type_comment.py
new file mode 100644
index 000000000..80b6038ec
--- /dev/null
+++ b/tests/functional/r/regression/regression_4510_unused_import_type_comment.py
@@ -0,0 +1,12 @@
+# pylint: disable=invalid-name,missing-docstring
+"""
+Regression test for unused-import false positive when a
+module is used in a type comment.
+https://github.com/PyCQA/pylint/issues/4510
+"""
+
+import abc
+from abc import ABC
+
+X = ...  # type: abc.ABC
+Y = ...  # type: ABC

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/constants\.py|pylint/checkers/variables\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/functional/r/regression/regression_4510_unused_import_type_comment.py
cat coverage.cover
git checkout 1e55ae64624d28c5fe8b63ad7979880ee2e6ef3f
git apply /root/pre_state.patch
