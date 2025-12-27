#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4884a87e022056eda10534c13d74e49b8cdda632 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4884a87e022056eda10534c13d74e49b8cdda632
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/autoreload.py b/django/utils/autoreload.py
--- a/django/utils/autoreload.py
+++ b/django/utils/autoreload.py
@@ -220,6 +220,11 @@ def get_child_arguments():
     py_script = Path(sys.argv[0])
 
     args = [sys.executable] + ['-W%s' % o for o in sys.warnoptions]
+    if sys.implementation.name == 'cpython':
+        args.extend(
+            f'-X{key}' if value is True else f'-X{key}={value}'
+            for key, value in sys._xoptions.items()
+        )
     # __spec__ is set when the server was started with the `-m` option,
     # see https://docs.python.org/3/reference/import.html#main-spec
     # __spec__ may not exist, e.g. when running in a Conda env.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils/test_autoreload.py b/tests/utils/test_autoreload.py
new file mode 100644
index 0000000000..f654235ed4
--- /dev/null
+++ b/tests/utils/test_autoreload.py
@@ -0,0 +1,21 @@
+import sys
+from unittest import mock, skipIf
+
+from django.test import SimpleTestCase
+from django.utils import autoreload
+
+
+class TestChildArguments(SimpleTestCase):
+    @skipIf(not hasattr(sys, "_xoptions"), "sys._xoptions is not available.")
+    @mock.patch("__main__.__spec__", None)
+    @mock.patch("sys.argv", ["manage.py", "runserver"])
+    @mock.patch("sys.warnoptions", [])
+    def test_xoptions_are_passed_to_child(self):
+        """
+        -X options are passed to the child process.
+        """
+        with mock.patch.dict(sys._xoptions, {"utf8": True}):
+            self.assertEqual(
+                autoreload.get_child_arguments(),
+                [sys.executable, "-Xutf8", "manage.py", "runserver"],
+            )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 utils.test_autoreload
cat coverage.cover
git checkout 4884a87e022056eda10534c13d74e49b8cdda632
git apply /root/pre_state.patch
