#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b7da588e883e12b8ac3bb8a486e654e30fc1c6c8 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b7da588e883e12b8ac3bb8a486e654e30fc1c6c8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/management/base.py b/django/core/management/base.py
--- a/django/core/management/base.py
+++ b/django/core/management/base.py
@@ -140,6 +140,10 @@ def __init__(self, out, ending='\n'):
     def __getattr__(self, name):
         return getattr(self._out, name)
 
+    def flush(self):
+        if hasattr(self._out, 'flush'):
+            self._out.flush()
+
     def isatty(self):
         return hasattr(self._out, 'isatty') and self._out.isatty()
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_management_command_flush.py b/tests/test_management_command_flush.py
new file mode 100644
index 0000000000..1239f81886
--- /dev/null
+++ b/tests/test_management_command_flush.py
@@ -0,0 +1,25 @@
+import io
+from unittest import mock
+
+from django.core.management import BaseCommand, call_command
+from django.test import SimpleTestCase
+
+
+class ManagementCommandFlushTests(SimpleTestCase):
+    def test_output_wrapper_flush(self):
+        """
+        flush() on an OutputWrapper should flush the underlying stream.
+        """
+        out = io.StringIO()
+        mock_stdout = mock.Mock(wraps=out)
+
+        class FlushCommand(BaseCommand):
+            requires_system_checks = []
+
+            def handle(self, *args, **options):
+                self.stdout.write('some output', ending='')
+                self.stdout.flush()
+
+        command = FlushCommand(stdout=mock_stdout)
+        call_command(command)
+        mock_stdout.flush.assert_called_once()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_management_command_flush
cat coverage.cover
git checkout b7da588e883e12b8ac3bb8a486e654e30fc1c6c8
git apply /root/pre_state.patch
