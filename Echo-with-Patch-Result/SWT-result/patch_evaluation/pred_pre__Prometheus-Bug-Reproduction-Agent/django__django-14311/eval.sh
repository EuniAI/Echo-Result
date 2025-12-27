#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5a8e8f80bb82a867eab7e4d9d099f21d0a976d22 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5a8e8f80bb82a867eab7e4d9d099f21d0a976d22
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/autoreload/test_dotted_path.py b/tests/autoreload/test_dotted_path.py
new file mode 100644
index 0000000000..eed701cd12
--- /dev/null
+++ b/tests/autoreload/test_dotted_path.py
@@ -0,0 +1,29 @@
+import sys
+import types
+from importlib.machinery import ModuleSpec
+from unittest import mock
+
+from django.test import SimpleTestCase
+from django.utils import autoreload
+
+
+class AutoreloadDottedModuleTest(SimpleTestCase):
+    @mock.patch('sys.warnoptions', [])
+    @mock.patch('sys.argv', ['/path/to/project/foo/bar/baz.py', 'runserver'])
+    def test_get_child_arguments_for_dotted_module(self):
+        """
+        get_child_arguments() returns the correct module name when the server
+        is started with a dotted path module, e.g. `python -m foo.bar.baz`.
+        """
+        main_mod = types.ModuleType('__main__')
+        main_mod.__file__ = '/path/to/project/foo/bar/baz.py'
+        # Simulate `python -m foo.bar.baz`.
+        main_mod.__spec__ = ModuleSpec('foo.bar.baz', None)
+
+        with mock.patch.dict(sys.modules, {'__main__': main_mod}):
+            child_args = autoreload.get_child_arguments()
+
+        self.assertEqual(
+            child_args,
+            [sys.executable, '-m', 'foo.bar.baz', 'runserver']
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 autoreload.test_dotted_path
cat coverage.cover
git checkout 5a8e8f80bb82a867eab7e4d9d099f21d0a976d22
git apply /root/pre_state.patch
