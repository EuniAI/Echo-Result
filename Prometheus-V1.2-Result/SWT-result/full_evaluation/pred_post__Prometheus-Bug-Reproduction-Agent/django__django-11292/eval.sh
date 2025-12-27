#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD eb16c7260e573ec513d84cb586d96bdf508f3173 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff eb16c7260e573ec513d84cb586d96bdf508f3173
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/management/base.py b/django/core/management/base.py
--- a/django/core/management/base.py
+++ b/django/core/management/base.py
@@ -95,7 +95,7 @@ class DjangoHelpFormatter(HelpFormatter):
     """
     show_last = {
         '--version', '--verbosity', '--traceback', '--settings', '--pythonpath',
-        '--no-color', '--force-color',
+        '--no-color', '--force-color', '--skip-checks',
     }
 
     def _reordered_actions(self, actions):
@@ -223,7 +223,7 @@ class BaseCommand:
     requires_system_checks = True
     # Arguments, common to all commands, which aren't defined by the argument
     # parser.
-    base_stealth_options = ('skip_checks', 'stderr', 'stdout')
+    base_stealth_options = ('stderr', 'stdout')
     # Command-specific options not defined by the argument parser.
     stealth_options = ()
 
@@ -286,6 +286,11 @@ def create_parser(self, prog_name, subcommand, **kwargs):
             '--force-color', action='store_true',
             help='Force colorization of the command output.',
         )
+        if self.requires_system_checks:
+            parser.add_argument(
+                '--skip-checks', action='store_true',
+                help='Skip system checks.',
+            )
         self.add_arguments(parser)
         return parser
 
@@ -357,7 +362,7 @@ def execute(self, *args, **options):
         if options.get('stderr'):
             self.stderr = OutputWrapper(options['stderr'])
 
-        if self.requires_system_checks and not options.get('skip_checks'):
+        if self.requires_system_checks and not options['skip_checks']:
             self.check()
         if self.requires_migrations_checks:
             self.check_migrations()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_scripts/test_command_run.py b/tests/admin_scripts/test_command_run.py
new file mode 100644
index 0000000000..f0d26a1e30
--- /dev/null
+++ b/tests/admin_scripts/test_command_run.py
@@ -0,0 +1,42 @@
+from unittest import mock
+
+from admin_scripts.tests import AdminScriptTestCase
+
+from django.core.management import BaseCommand
+
+
+class CommandRunTests(AdminScriptTestCase):
+    """
+    Tests that need to run by simulating the command line, not by call_command.
+    """
+    def test_script_prefix_set_in_commands(self):
+        self.write_settings('settings.py', apps=['user_commands'], sdict={
+            'ROOT_URLCONF': '"user_commands.urls"',
+            'FORCE_SCRIPT_NAME': '"/PREFIX/"',
+        })
+        out, err = self.run_manage(['reverse_url'])
+        self.assertNoOutput(err)
+        self.assertEqual(out.strip(), '/PREFIX/some/url/')
+
+    def test_disallowed_abbreviated_options(self):
+        """
+        To avoid conflicts with custom options, commands don't allow
+        abbreviated forms of the --setting and --pythonpath options.
+        """
+        self.write_settings('settings.py', apps=['user_commands'])
+        out, err = self.run_manage(['set_option', '--set', 'foo'])
+        self.assertNoOutput(err)
+        self.assertEqual(out.strip(), 'Set foo')
+
+    @mock.patch('django.core.management.base.BaseCommand.check')
+    def test_skip_checks_option(self, mocked_check):
+        """
+        The --skip-checks option skips system checks.
+        """
+        self.write_settings('settings.py', apps=['user_commands'])
+        # The 'dance' command's requires_system_checks is True by default.
+        # Before the fix, this call will write an "unrecognized arguments"
+        # error to stderr.
+        out, err = self.run_manage(['dance', '--skip-checks'])
+        self.assertNoOutput(err)
+        mocked_check.assert_not_called()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_scripts.test_command_run
cat coverage.cover
git checkout eb16c7260e573ec513d84cb586d96bdf508f3173
git apply /root/pre_state.patch
