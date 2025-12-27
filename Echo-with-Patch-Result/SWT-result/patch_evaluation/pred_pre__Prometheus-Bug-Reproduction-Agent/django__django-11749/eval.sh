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
diff --git a/tests/test_mutually_exclusive_required_args.py b/tests/test_mutually_exclusive_required_args.py
new file mode 100644
index 0000000000..8a5e6a67fa
--- /dev/null
+++ b/tests/test_mutually_exclusive_required_args.py
@@ -0,0 +1,41 @@
+from io import StringIO
+
+from django.core import management
+from django.core.management.base import BaseCommand
+from django.test import SimpleTestCase, override_settings
+
+
+@override_settings(
+    INSTALLED_APPS=[
+        'django.contrib.auth',
+        'django.contrib.contenttypes',
+        'user_commands',
+    ],
+)
+class MutuallyExclusiveRequiredArgsTest(SimpleTestCase):
+    """
+    Test for call_command with mutually exclusive required arguments.
+    """
+
+    def test_call_command_mutually_exclusive_required_options_as_kwargs(self):
+        """
+        A call to a command with a required mutually exclusive group of
+        arguments should not fail when one of the arguments is passed as a
+        keyword argument to call_command.
+        """
+        class TestCommand(BaseCommand):
+            def add_arguments(self, parser):
+                group = parser.add_mutually_exclusive_group(required=True)
+                group.add_argument('--shop-id', type=int)
+                group.add_argument('--shop', type=str)
+
+            def handle(self, *args, **options):
+                self.stdout.write(
+                    'shop_id=%s, shop=%s' % (options['shop_id'], options['shop'])
+                )
+
+        out = StringIO()
+        # This call raises CommandError without the fix because 'shop_id' is not
+        # individually required, but part of a required group.
+        management.call_command(TestCommand(), shop_id=1, stdout=out)
+        self.assertIn('shop_id=1, shop=None', out.getvalue())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_mutually_exclusive_required_args
cat coverage.cover
git checkout 350123f38c2b6217c38d70bfbd924a9ba3df1289
git apply /root/pre_state.patch
