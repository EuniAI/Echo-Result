#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1250483ebf73f7a82ff820b94092c63ce4238264 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1250483ebf73f7a82ff820b94092c63ce4238264
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_command_parser_subparser.py b/tests/test_command_parser_subparser.py
new file mode 100644
index 0000000000..788ebb9574
--- /dev/null
+++ b/tests/test_command_parser_subparser.py
@@ -0,0 +1,31 @@
+import sys
+from io import StringIO
+
+from django.core.management.base import BaseCommand, CommandError
+from django.test import SimpleTestCase
+from django.test.utils import captured_stderr
+
+
+class CommandParserSubparserTests(SimpleTestCase):
+    def test_subparser_error_formatting(self):
+        """
+        Subparsers of a CommandParser should use the same error reporting
+        style as their parent parser.
+        """
+
+        class Command(BaseCommand):
+            def add_arguments(self, parser):
+                subparsers = parser.add_subparsers(required=True)
+                create_parser = subparsers.add_parser("create")
+                create_parser.add_argument("name")
+
+            def handle(self, *args, **options):
+                pass
+
+        with captured_stderr() as stderr, self.assertRaises(SystemExit):
+            Command().run_from_argv(["manage.py", "test_command", "create"])
+        # Before the fix, a CommandError is raised and caught in run_from_argv,
+        # which prints a simple "CommandError:..." message. After the fix,
+        # the subparser's error() method is called, which prints a full
+        # usage message.
+        self.assertIn("usage: manage.py test_command create", stderr.getvalue())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_command_parser_subparser
cat coverage.cover
git checkout 1250483ebf73f7a82ff820b94092c63ce4238264
git apply /root/pre_state.patch
