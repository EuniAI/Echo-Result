#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 415f50298f97fb17f841a9df38d995ccf347dfcc >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 415f50298f97fb17f841a9df38d995ccf347dfcc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/autoreload.py b/django/utils/autoreload.py
--- a/django/utils/autoreload.py
+++ b/django/utils/autoreload.py
@@ -216,14 +216,14 @@ def get_child_arguments():
     executable is reported to not have the .exe extension which can cause bugs
     on reloading.
     """
-    import django.__main__
-    django_main_path = Path(django.__main__.__file__)
+    import __main__
     py_script = Path(sys.argv[0])
 
     args = [sys.executable] + ['-W%s' % o for o in sys.warnoptions]
-    if py_script == django_main_path:
-        # The server was started with `python -m django runserver`.
-        args += ['-m', 'django']
+    # __spec__ is set when the server was started with the `-m` option,
+    # see https://docs.python.org/3/reference/import.html#main-spec
+    if __main__.__spec__ is not None and __main__.__spec__.parent:
+        args += ['-m', __main__.__spec__.parent]
         args += sys.argv[1:]
     elif not py_script.exists():
         # sys.argv[0] may not exist for several reasons on Windows.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_autoreload_child_arguments.py b/tests/test_autoreload_child_arguments.py
new file mode 100644
index 0000000000..447cac717d
--- /dev/null
+++ b/tests/test_autoreload_child_arguments.py
@@ -0,0 +1,36 @@
+import sys
+import tempfile
+import types
+from pathlib import Path
+from unittest import mock
+
+from django.test import SimpleTestCase
+from django.utils import autoreload
+
+
+class AutoreloadChildArgumentsTests(SimpleTestCase):
+    @mock.patch('sys.warnoptions', [])
+    def test_run_as_other_module(self):
+        """
+        get_child_arguments() detects run-as-module for any module, not
+        just Django.
+        """
+        with tempfile.TemporaryDirectory() as tmpdir:
+            # Create a fake module structure to properly simulate `python -m my_app`.
+            module_dir = Path(tmpdir) / 'my_app'
+            module_dir.mkdir()
+            main_py = module_dir / '__main__.py'
+            main_py.touch()
+
+            # When running `python -m my_app`, __main__'s spec has a parent
+            # and sys.argv[0] is the path to __main__.py.
+            main_spec = mock.Mock(parent='my_app')
+            main_module = types.ModuleType('__main__')
+            main_module.__spec__ = main_spec
+
+            with mock.patch.dict(sys.modules, {'__main__': main_module}), \
+                    mock.patch('sys.argv', [str(main_py), 'runserver']):
+                self.assertEqual(
+                    autoreload.get_child_arguments(),
+                    [sys.executable, '-m', 'my_app', 'runserver'],
+                )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_autoreload_child_arguments
cat coverage.cover
git checkout 415f50298f97fb17f841a9df38d995ccf347dfcc
git apply /root/pre_state.patch
