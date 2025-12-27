#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 89fc144dedc737a79929231438f035b1d4a993c9 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 89fc144dedc737a79929231438f035b1d4a993c9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_loaddata_reserved_name.py b/tests/test_loaddata_reserved_name.py
new file mode 100644
index 0000000000..6dd9af5f14
--- /dev/null
+++ b/tests/test_loaddata_reserved_name.py
@@ -0,0 +1,110 @@
+import json
+import os
+import shutil
+import sys
+import tempfile
+import unittest
+
+from django.core import management
+from django.db import connection
+from django.test import TransactionTestCase, override_settings
+
+# Global state for the temporary app.
+temp_dir = None
+app_name = 'loaddata_test_app'
+
+# Decorate the test class. This will be active for the entire class.
+@override_settings(INSTALLED_APPS=[
+    'django.contrib.contenttypes',
+    'django.contrib.auth',
+    app_name,
+])
+@unittest.skipUnless(connection.vendor == 'sqlite', 'SQLite specific test')
+class LoaddataReservedNameTest(TransactionTestCase):
+
+    @classmethod
+    def setUpClass(cls):
+        # 1. Create the app on the filesystem.
+        global temp_dir
+        temp_dir = tempfile.mkdtemp()
+        sys.path.insert(0, temp_dir)
+        app_dir = os.path.join(temp_dir, app_name)
+        os.mkdir(app_dir)
+
+        MODELS_PY_CONTENT = """
+from django.db import models
+
+class Group(models.Model):
+    name = models.CharField(max_length=255)
+
+class Order(models.Model):
+    group = models.ForeignKey(Group, models.CASCADE)
+
+    class Meta:
+        db_table = 'order'
+"""
+        with open(os.path.join(app_dir, '__init__.py'), 'w'):
+            pass
+        with open(os.path.join(app_dir, 'models.py'), 'w') as f:
+            f.write(MODELS_PY_CONTENT)
+
+        # 2. Now call super().setUpClass(). This will run the setup for
+        #    @override_settings, which will now find our app on sys.path
+        #    and correctly populate the app registry.
+        super().setUpClass()
+
+    @classmethod
+    def tearDownClass(cls):
+        super().tearDownClass()
+        # Clean up the temporary app directory and sys.path.
+        if temp_dir:
+            sys.path.pop(0)
+            shutil.rmtree(temp_dir)
+
+    def setUp(self):
+        super().setUp()
+        # Manually create the tables for our dynamic app.
+        # This is necessary because the test runner's migrate command ran
+        # before our app was created.
+        from django.apps import apps
+        with connection.schema_editor() as editor:
+            editor.create_model(apps.get_model(app_name, 'Group'))
+            editor.create_model(apps.get_model(app_name, 'Order'))
+
+    def tearDown(self):
+        from django.apps import apps
+        with connection.schema_editor() as editor:
+            editor.delete_model(apps.get_model(app_name, 'Order'))
+            editor.delete_model(apps.get_model(app_name, 'Group'))
+        super().tearDown()
+
+    def test_loaddata_with_sql_keyword_table_name(self):
+        """
+        loaddata should not crash on SQLite when a table name is a reserved
+        SQL keyword.
+        """
+        from django.apps import apps
+        Order = apps.get_model(app_name, 'Order')
+
+        with tempfile.TemporaryDirectory() as fixture_dir:
+            fixture_content = [
+                {
+                    'model': f'{app_name}.group',
+                    'pk': 1,
+                    'fields': {'name': 'test group'},
+                },
+                {
+                    'model': f'{app_name}.order',
+                    'pk': 1,
+                    'fields': {'group': 1},
+                },
+            ]
+            fixture_path = os.path.join(fixture_dir, 'fixture.json')
+            with open(fixture_path, 'w') as f:
+                json.dump(fixture_content, f)
+
+            # Call loaddata. This will trigger the bug on the unpatched codebase.
+            management.call_command('loaddata', fixture_path, verbosity=0)
+
+        # This assertion verifies that data was loaded successfully.
+        self.assertEqual(Order.objects.count(), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_loaddata_reserved_name
cat coverage.cover
git checkout 89fc144dedc737a79929231438f035b1d4a993c9
git apply /root/pre_state.patch
