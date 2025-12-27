#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bef6f7584280f1cc80e5e2d80b7ad073a93d26ec >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bef6f7584280f1cc80e5e2d80b7ad073a93d26ec
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/management/commands/runserver.py b/django/core/management/commands/runserver.py
--- a/django/core/management/commands/runserver.py
+++ b/django/core/management/commands/runserver.py
@@ -51,6 +51,10 @@ def add_arguments(self, parser):
             '--noreload', action='store_false', dest='use_reloader',
             help='Tells Django to NOT use the auto-reloader.',
         )
+        parser.add_argument(
+            '--skip-checks', action='store_true',
+            help='Skip system checks.',
+        )
 
     def execute(self, *args, **options):
         if options['no_color']:
@@ -114,8 +118,9 @@ def inner_run(self, *args, **options):
         shutdown_message = options.get('shutdown_message', '')
         quit_command = 'CTRL-BREAK' if sys.platform == 'win32' else 'CONTROL-C'
 
-        self.stdout.write("Performing system checks...\n\n")
-        self.check(display_num_errors=True)
+        if not options['skip_checks']:
+            self.stdout.write('Performing system checks...\n\n')
+            self.check(display_num_errors=True)
         # Need to check migrations here, so can't use the
         # requires_migrations_check attribute.
         self.check_migrations()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_runserver_skip_checks.py b/tests/test_runserver_skip_checks.py
new file mode 100644
index 0000000000..0cd92c24e9
--- /dev/null
+++ b/tests/test_runserver_skip_checks.py
@@ -0,0 +1,16 @@
+from unittest import mock
+
+from django.core.management import call_command
+from django.test import SimpleTestCase
+
+
+class RunserverSkipChecksTest(SimpleTestCase):
+    @mock.patch('django.core.servers.basehttp.run')
+    @mock.patch('django.core.management.base.BaseCommand.check_migrations')
+    @mock.patch('django.core.management.base.BaseCommand.check')
+    def test_skip_checks_option(self, mock_check, mock_check_migrations, mock_run):
+        """
+        The --skip-checks option skips system checks.
+        """
+        call_command('runserver', '--skip-checks', '--noreload')
+        mock_check.assert_not_called()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/runserver\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_runserver_skip_checks
cat coverage.cover
git checkout bef6f7584280f1cc80e5e2d80b7ad073a93d26ec
git apply /root/pre_state.patch
