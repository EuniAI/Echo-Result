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
diff --git a/django/core/management/__init__.py b/django/core/management/__init__.py
--- a/django/core/management/__init__.py
+++ b/django/core/management/__init__.py
@@ -344,7 +344,12 @@ def execute(self):
         # Preprocess options to extract --settings and --pythonpath.
         # These options could affect the commands that are available, so they
         # must be processed early.
-        parser = CommandParser(usage='%(prog)s subcommand [options] [args]', add_help=False, allow_abbrev=False)
+        parser = CommandParser(
+            prog=self.prog_name,
+            usage='%(prog)s subcommand [options] [args]',
+            add_help=False,
+            allow_abbrev=False,
+        )
         parser.add_argument('--settings')
         parser.add_argument('--pythonpath')
         parser.add_argument('args', nargs='*')  # catch-all

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/management/test_prog_name.py b/tests/management/test_prog_name.py
new file mode 100644
index 0000000000..bdfa3c8c0c
--- /dev/null
+++ b/tests/management/test_prog_name.py
@@ -0,0 +1,41 @@
+import sys
+from io import StringIO
+from unittest.mock import patch
+
+from django.core.management import ManagementUtility
+from django.test import SimpleTestCase
+
+
+class ManagementUtilityProgNameTests(SimpleTestCase):
+    @patch('sys.stdout', new_callable=StringIO)
+    def test_prog_name_passed_to_preliminary_parser(self, mock_stdout):
+        """
+        ManagementUtility passes the computed prog_name to the preliminary
+        CommandParser, so it doesn't fall back to using sys.argv.
+        """
+        argv = ['custom_prog', 'check', '--help']
+        utility = ManagementUtility(argv)
+        raised_type_error = False
+
+        with patch('sys.argv', [None]):
+            try:
+                # On patched code, this raises SystemExit after printing help.
+                # On unpatched code, this raises TypeError before SystemExit.
+                with self.assertRaises(SystemExit):
+                    utility.execute()
+            except TypeError:
+                # This is the bug we expect to see on the unpatched code.
+                # We catch it and convert it into a test failure.
+                raised_type_error = True
+
+        # This assertion will fail on the old code (since raised_type_error
+        # will be True) and pass on the new code (since it will be False).
+        self.assertFalse(
+            raised_type_error,
+            "TypeError was raised because ManagementUtility did not pass "
+            "prog_name to its preliminary CommandParser."
+        )
+        # This assertion confirms the fix works correctly on the new code by
+        # checking the output, which is only generated if the TypeError is not
+        # raised.
+        self.assertIn('usage: custom_prog subcommand [options] [args]', mock_stdout.getvalue())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 management.test_prog_name
cat coverage.cover
git checkout 0773837e15bb632afffb6848a58c59a791008fa1
git apply /root/pre_state.patch
