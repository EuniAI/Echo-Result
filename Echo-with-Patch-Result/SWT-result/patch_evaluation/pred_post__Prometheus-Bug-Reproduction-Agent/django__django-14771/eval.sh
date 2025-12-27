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
diff --git a/tests/autoreload/test_child_arguments.py b/tests/autoreload/test_child_arguments.py
new file mode 100644
index 0000000000..0ee86e6c20
--- /dev/null
+++ b/tests/autoreload/test_child_arguments.py
@@ -0,0 +1,35 @@
+import sys
+from unittest import mock, skipIf
+
+from django.test import SimpleTestCase
+from django.utils.autoreload import get_child_arguments
+
+
+@skipIf(not hasattr(sys, "_xoptions"), "sys._xoptions is not available on this platform.")
+class AutoreloadChildArgumentsTests(SimpleTestCase):
+    """
+    Tests for passing implementation-specific options to the autoreloader child
+    process.
+    """
+
+    @mock.patch("django.utils.autoreload.Path")
+    @mock.patch("django.utils.autoreload.sys")
+    def test_xoptions_are_passed_to_child(self, mock_sys, mock_path):
+        """
+        -X options are passed to the child process.
+        """
+        mock_main = mock.MagicMock()
+        # Ensure __main__ doesn't have a __spec__ to simulate running a script
+        # directly.
+        del mock_main.__spec__
+
+        mock_sys.executable = "python"
+        mock_sys.argv = ["manage.py", "runserver"]
+        mock_sys.warnoptions = []
+        mock_sys._xoptions = {"utf8": True}
+        # Mock sys.modules to control the `import __main__` statement.
+        mock_sys.modules = {"__main__": mock_main}
+        mock_path.return_value.exists.return_value = True
+
+        args = get_child_arguments()
+        self.assertIn("-Xutf8", args)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 autoreload.test_child_arguments
cat coverage.cover
git checkout 4884a87e022056eda10534c13d74e49b8cdda632
git apply /root/pre_state.patch
