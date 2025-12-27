#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0773837e15bb632afffb6848a58c59a791008fa1 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0773837e15bb632afffb6848a58c59a791008fa1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_scripts/test_management_utility.py b/tests/admin_scripts/test_management_utility.py
new file mode 100644
index 0000000000..88b1db37e1
--- /dev/null
+++ b/tests/admin_scripts/test_management_utility.py
@@ -0,0 +1,20 @@
+import sys
+from unittest import mock
+
+from django.core import management
+from django.test import SimpleTestCase
+from django.test.utils import captured_stderr
+
+
+class ManagementUtilityProgNameTests(SimpleTestCase):
+
+    def test_prog_name(self):
+        """
+        ManagementUtility.execute() should use the prog_name computed from
+        argv to instantiate the CommandParser, even when sys.argv[0] is None.
+        """
+        with mock.patch.object(sys, 'argv', [None]):
+            utility = management.ManagementUtility(['my_prog', 'help'])
+            with captured_stderr() as stderr, self.assertRaises(SystemExit):
+                utility.execute()
+        self.assertIn('usage: my_prog subcommand', stderr.getvalue())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_scripts.test_management_utility
cat coverage.cover
git checkout 0773837e15bb632afffb6848a58c59a791008fa1
git apply /root/pre_state.patch
