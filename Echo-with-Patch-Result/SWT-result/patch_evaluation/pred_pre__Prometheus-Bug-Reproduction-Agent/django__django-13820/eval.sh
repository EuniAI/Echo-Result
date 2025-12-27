#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 98ad327864aed8df245fd19ea9d2743279e11643 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 98ad327864aed8df245fd19ea9d2743279e11643
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_loader_no_file_attr.py b/tests/migrations/test_loader_no_file_attr.py
new file mode 100644
index 0000000000..c4109e9455
--- /dev/null
+++ b/tests/migrations/test_loader_no_file_attr.py
@@ -0,0 +1,46 @@
+import sys
+from types import ModuleType
+from unittest.mock import MagicMock, patch
+
+from django.db.migrations.loader import MigrationLoader
+from django.test import TestCase, modify_settings, override_settings
+
+
+class MigrationLoaderFileAttributeTests(TestCase):
+    # Add the 'basic' test app to INSTALLED_APPS for the loader to find it.
+    # Then, override its migration module to point to our fake module.
+    @modify_settings(INSTALLED_APPS={'append': 'migrations.migrations_test_apps.basic'})
+    @override_settings(MIGRATION_MODULES={'basic': 'basic.migrations'})
+    def test_regular_package_no_file_attribute(self):
+        """
+        Migrations in a regular package without a __file__ attribute should be
+        loaded.
+        """
+        migrations_module_name = 'basic.migrations'
+        migration_name = '0001_initial'
+        full_migration_module_name = f'{migrations_module_name}.{migration_name}'
+
+        # A mock module for a regular package without a __file__ attribute.
+        migrations_pkg_module = ModuleType(migrations_module_name)
+        migrations_pkg_module.__path__ = ['/fake/path']
+
+        # A mock for the actual migration file.
+        migration_file_module = ModuleType(full_migration_module_name)
+        migration_file_module.Migration = MagicMock()
+
+        # Place the mock modules in sys.modules so they can be "imported".
+        mocked_modules = {
+            migrations_module_name: migrations_pkg_module,
+            full_migration_module_name: migration_file_module,
+        }
+        # Mock pkgutil to "find" the migration file in our mock package.
+        with patch.dict(sys.modules, mocked_modules), \
+             patch('django.db.migrations.loader.pkgutil.iter_modules', return_value=[(None, migration_name, False)]):
+            loader = MigrationLoader(connection=None)
+
+            # The bug is that the loader incorrectly flags the app as
+            # unmigrated due to the missing __file__ attribute. This assertion
+            # will fail on the buggy code because 'basic' will NOT be in
+            # migrated_apps. It will pass on the patched code which correctly
+            # checks the type of __path__ and loads the app's migrations.
+            self.assertIn('basic', loader.migrated_apps)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/loader\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_loader_no_file_attr
cat coverage.cover
git checkout 98ad327864aed8df245fd19ea9d2743279e11643
git apply /root/pre_state.patch
