#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 350123f38c2b6217c38d70bfbd924a9ba3df1289 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 350123f38c2b6217c38d70bfbd924a9ba3df1289
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/management/__init__.py b/django/core/management/__init__.py
--- a/django/core/management/__init__.py
+++ b/django/core/management/__init__.py
@@ -130,11 +130,19 @@ def get_actions(parser):
                 yield opt
 
     parser_actions = list(get_actions(parser))
+    mutually_exclusive_required_options = {
+        opt
+        for group in parser._mutually_exclusive_groups
+        for opt in group._group_actions if group.required
+    }
     # Any required arguments which are passed in via **options must be passed
     # to parse_args().
     parse_args += [
         '{}={}'.format(min(opt.option_strings), arg_options[opt.dest])
-        for opt in parser_actions if opt.required and opt.dest in options
+        for opt in parser_actions if (
+            opt.dest in options and
+            (opt.required or opt in mutually_exclusive_required_options)
+        )
     ]
     defaults = parser.parse_args(args=parse_args)
     defaults = dict(defaults._get_kwargs(), **arg_options)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/user_commands/test_call_command_mutual_exclusion.py b/tests/user_commands/test_call_command_mutual_exclusion.py
new file mode 100644
index 0000000000..865f3a374b
--- /dev/null
+++ b/tests/user_commands/test_call_command_mutual_exclusion.py
@@ -0,0 +1,60 @@
+from io import StringIO
+from unittest import mock
+
+from django.core import management
+from django.core.management import CommandError
+from django.test import SimpleTestCase, override_settings
+
+# The original command is imported so it can be subclassed.
+from user_commands.management.commands import dance
+
+
+@override_settings(
+    INSTALLED_APPS=[
+        'django.contrib.auth',
+        'django.contrib.contenttypes',
+        'user_commands',
+    ],
+)
+class CallCommandMutualExclusionTest(SimpleTestCase):
+
+    def test_required_mutually_exclusive_group_kwarg_reproduces_bug(self):
+        """
+        Reproduces a bug where call_command fails to process a keyword
+        argument that is part of a required mutually exclusive group.
+
+        This test patches `get_commands` to inject a modified command
+        instance. This is a clean way to control the command object used by
+        `call_command`, ensuring the test setup is correct and correctly
+        exposes the CommandError described in the bug report.
+        """
+        # 1. Define a command subclass with the required mutually exclusive group.
+        class CommandWithMutexGroup(dance.Command):
+            def add_arguments(self, parser):
+                super().add_arguments(parser)
+                group = parser.add_mutually_exclusive_group(required=True)
+                group.add_argument('--shop-id', type=int)
+                group.add_argument('--shop', type=str)
+
+        # 2. Instantiate the modified command.
+        command_instance = CommandWithMutexGroup()
+        out = StringIO()
+
+        # 3. Patch `get_commands` to return a dictionary containing our
+        #    pre-initialized command instance. `fetch_command` is designed
+        #    to handle this case, making this a stable injection point.
+        with mock.patch('django.core.management.get_commands', return_value={'dance': command_instance}):
+            # 4. This call is now expected to fail with a CommandError due to the bug.
+            #    The bug prevents `shop_id=1` from being passed to the
+            #    ArgumentParser, which then complains that a required argument
+            #    is missing. When the bug is fixed, this call will succeed.
+            management.call_command(
+                'dance',
+                shop_id=1,
+                verbosity=1,  # Ensures the handle method prints options
+                stdout=out,
+            )
+
+        # 5. This assertion will only be reached if the bug is fixed. The `dance`
+        #    command prints the options it received, so we check for `shop_id`.
+        self.assertIn('shop_id', out.getvalue())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 user_commands.test_call_command_mutual_exclusion
cat coverage.cover
git checkout 350123f38c2b6217c38d70bfbd924a9ba3df1289
git apply /root/pre_state.patch
