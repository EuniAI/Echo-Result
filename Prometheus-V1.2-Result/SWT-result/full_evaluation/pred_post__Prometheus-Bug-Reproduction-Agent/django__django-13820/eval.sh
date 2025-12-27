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
diff --git a/django/db/migrations/loader.py b/django/db/migrations/loader.py
--- a/django/db/migrations/loader.py
+++ b/django/db/migrations/loader.py
@@ -88,15 +88,19 @@ def load_disk(self):
                     continue
                 raise
             else:
-                # Empty directories are namespaces.
-                # getattr() needed on PY36 and older (replace w/attribute access).
-                if getattr(module, '__file__', None) is None:
-                    self.unmigrated_apps.add(app_config.label)
-                    continue
                 # Module is not a package (e.g. migrations.py).
                 if not hasattr(module, '__path__'):
                     self.unmigrated_apps.add(app_config.label)
                     continue
+                # Empty directories are namespaces. Namespace packages have no
+                # __file__ and don't use a list for __path__. See
+                # https://docs.python.org/3/reference/import.html#namespace-packages
+                if (
+                    getattr(module, '__file__', None) is None and
+                    not isinstance(module.__path__, list)
+                ):
+                    self.unmigrated_apps.add(app_config.label)
+                    continue
                 # Force a reload if it's already loaded (tests need this)
                 if was_loaded:
                     reload(module)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_pyc_loader.py b/tests/migrations/test_pyc_loader.py
new file mode 100644
index 0000000000..be01e7f779
--- /dev/null
+++ b/tests/migrations/test_pyc_loader.py
@@ -0,0 +1,85 @@
+import compileall
+import os
+from importlib import import_module
+from unittest.mock import MagicMock, patch
+
+from django.db import connection, connections
+from django.db.migrations.exceptions import (
+    AmbiguityError,
+    InconsistentMigrationHistory,
+    NodeNotFoundError,
+)
+from django.db.migrations.loader import MigrationLoader
+from django.db.migrations.recorder import MigrationRecorder
+from django.test import TestCase, modify_settings, override_settings
+
+from .test_base import MigrationTestBase
+
+
+class PycLoaderTests(MigrationTestBase):
+    def test_valid(self):
+        """
+        To support frozen environments, MigrationLoader loads .pyc migrations.
+        """
+        with self.temporary_migration_module(
+            module="migrations.test_migrations"
+        ) as migration_dir:
+            # Compile .py files to .pyc files and delete .py files.
+            compileall.compile_dir(migration_dir, force=True, quiet=1, legacy=True)
+            for name in os.listdir(migration_dir):
+                if name.endswith(".py"):
+                    os.remove(os.path.join(migration_dir, name))
+            loader = MigrationLoader(connection)
+            self.assertIn(("migrations", "0001_initial"), loader.disk_migrations)
+
+    def test_invalid(self):
+        """
+        MigrationLoader reraises ImportErrors caused by "bad magic number" pyc
+        files with a more helpful message.
+        """
+        with self.temporary_migration_module(
+            module="migrations.test_migrations_bad_pyc"
+        ) as migration_dir:
+            # The -tpl suffix is to avoid the pyc exclusion in MANIFEST.in.
+            os.rename(
+                os.path.join(migration_dir, "0001_initial.pyc-tpl"),
+                os.path.join(migration_dir, "0001_initial.pyc"),
+            )
+            msg = (
+                r"Couldn't import '\w+.migrations.0001_initial' as it appears "
+                "to be a stale .pyc file."
+            )
+            with self.assertRaisesRegex(ImportError, msg):
+                MigrationLoader(connection)
+
+    @override_settings(INSTALLED_APPS=["migrations"])
+    def test_package_with_no_file_attribute(self):
+        """
+        Migrations from a regular package without __file__ are loaded.
+        """
+        with self.temporary_migration_module(
+            module="migrations.test_migrations"
+        ) as migration_dir:
+            from django.conf import settings
+
+            module_name = settings.MIGRATION_MODULES["migrations"]
+            # This mock simulates a module from a frozen environment.
+            mock_module = MagicMock(spec=object)
+            # It's a package, so it has __path__.
+            mock_module.__path__ = [migration_dir]
+            # But no __file__.
+            del mock_module.__file__
+
+            original_import = import_module
+
+            def import_side_effect(name, package=None):
+                if name == module_name:
+                    return mock_module
+                return original_import(name, package)
+
+            with patch(
+                "django.db.migrations.loader.import_module",
+                side_effect=import_side_effect,
+            ):
+                loader = MigrationLoader(connection)
+                self.assertIn(("migrations", "0001_initial"), loader.disk_migrations)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/loader\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_pyc_loader
cat coverage.cover
git checkout 98ad327864aed8df245fd19ea9d2743279e11643
git apply /root/pre_state.patch
