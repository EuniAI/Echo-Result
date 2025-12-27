#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 93d4c9ea1de24eb391cb2b3561b6703fd46374df >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 93d4c9ea1de24eb391cb2b3561b6703fd46374df
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/management/commands/test_runserver.py b/tests/management/commands/test_runserver.py
new file mode 100644
index 0000000000..b3381f6c73
--- /dev/null
+++ b/tests/management/commands/test_runserver.py
@@ -0,0 +1,24 @@
+import socket
+from io import StringIO
+from unittest import mock
+
+from django.core.management import call_command
+from django.core.management.commands.runserver import Command as RunserverCommand
+from django.test import SimpleTestCase
+
+
+class RunserverCommandTest(SimpleTestCase):
+    def setUp(self):
+        def monkey_run(*args, **options):
+            return
+
+        self.output = StringIO()
+        self.cmd = RunserverCommand(stdout=self.output)
+        self.cmd.run = monkey_run
+
+    def test_runserver_addr_0(self):
+        """
+        The address '0' is normalized to '0.0.0.0' for IPv4.
+        """
+        call_command(self.cmd, addrport="0:8000", use_ipv6=False)
+        self.assertEqual(self.cmd.addr, "0.0.0.0")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/runserver\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 management.commands.test_runserver
cat coverage.cover
git checkout 93d4c9ea1de24eb391cb2b3561b6703fd46374df
git apply /root/pre_state.patch
