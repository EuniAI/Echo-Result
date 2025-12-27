#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f8fab6f90233c7114d642dfe01a4e6d4cb14ee7d >> /root/pre_state.patch
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=utf8
export LANGUAGE=en_US:en
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f8fab6f90233c7114d642dfe01a4e6d4cb14ee7d
source /opt/miniconda3/bin/activate
conda activate testbed
python setup.py install
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_makemigrations_consistency_check.py b/tests/migrations/test_makemigrations_consistency_check.py
new file mode 100644
index 0000000000..1e66729192
--- /dev/null
+++ b/tests/migrations/test_makemigrations_consistency_check.py
@@ -0,0 +1,58 @@
+from io import StringIO
+from unittest import mock
+
+from django.apps import apps
+from django.conf import settings
+from django.core.management import call_command
+from django.db import connections
+from django.test import TestCase
+
+
+class TestMakemigrationsConsistencyCheck(TestCase):
+    """
+    This test is a standalone reproduction of a bug related to the
+    number of times allow_migrate() is called by makemigrations.
+    The original code was intended to be a method on the
+    `MakeMigrationsTests` class in `tests/migrations/test_commands.py`.
+    """
+
+    def test_makemigrations_consistency_check_call_count(self):
+        """
+        The history consistency checks in makemigrations should call
+        router.allow_migrate() once per model, not once per model per app.
+        """
+        app_labels = ['django.contrib.auth', 'django.contrib.contenttypes']
+        with self.settings(
+            DATABASES={
+                'default': {
+                    'ENGINE': 'django.db.backends.sqlite3',
+                    'NAME': ':memory:',
+                },
+            },
+            INSTALLED_APPS=app_labels,
+            # This specific router's allow_migrate() method always returns
+            # False, which is crucial for forcing the `any()` generator in
+            # `makemigrations` to be fully consumed, thus exposing the bug.
+            DATABASE_ROUTERS=['migrations.test_multidb.MigrateNothingRouter'],
+        ):
+            allow_migrate_path = 'migrations.test_multidb.MigrateNothingRouter.allow_migrate'
+            # The router already returns False, but patching allows us to spy on it.
+            with mock.patch(allow_migrate_path, return_value=False) as allow_migrate:
+                call_command('makemigrations', stdout=StringIO())
+
+                # The check is run for each database that isn't a dummy DB.
+                db_count = 0
+                for alias in settings.DATABASES:
+                    if connections[alias].settings_dict['ENGINE'] != 'django.db.backends.dummy':
+                        db_count += 1
+
+                # Calculate the total number of models across all configured apps.
+                # This is the expected number of calls for the *correct* code.
+                model_count = len(apps.get_models())
+                expected_call_count = model_count * db_count
+
+                # The buggy code will have a call count of roughly
+                # (len(app_labels) * model_count * db_count), which will fail this
+                # assertion. For example, if there are 4 models and 2 apps, the
+                # buggy code makes 8 calls, not 4.
+                self.assertEqual(allow_migrate.call_count, expected_call_count)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/makemigrations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_makemigrations_consistency_check
cat coverage.cover
git checkout f8fab6f90233c7114d642dfe01a4e6d4cb14ee7d
git apply /root/pre_state.patch
