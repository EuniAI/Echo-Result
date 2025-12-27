#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4b45b6c8e4d7c9701a332e80d3b1c84209dc36e2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4b45b6c8e4d7c9701a332e80d3b1c84209dc36e2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_rename_content_type_multidb.py b/tests/migrations/test_rename_content_type_multidb.py
new file mode 100644
index 0000000000..60cbb87b13
--- /dev/null
+++ b/tests/migrations/test_rename_content_type_multidb.py
@@ -0,0 +1,57 @@
+from unittest.mock import patch
+
+from django.apps.registry import apps
+from django.contrib.contenttypes.management import RenameContentType
+from django.contrib.contenttypes.models import ContentType, ContentTypeManager
+from django.db import connections
+from django.db.migrations.state import ProjectState
+from django.test import TransactionTestCase
+
+
+class RenameContentTypeMultiDBTest(TransactionTestCase):
+    databases = {'default', 'other'}
+    available_apps = ['django.contrib.contenttypes']
+
+    def test_rename_content_type_save_uses_correct_database(self):
+        """
+        Tests that RenameContentType's save() call is passed the correct
+        database alias, reproducing the bug where it defaults to the wrong DB.
+        """
+        app_label = 'contenttypes'
+        model_name = 'contenttype'
+
+        # The operation will be on the 'other' database.
+        db_alias = 'other'
+        schema_editor = connections[db_alias].schema_editor()
+        project_state = ProjectState.from_apps(apps)
+
+        # Get a real ContentType object from the 'other' database.
+        # This object will be returned by the patched manager method.
+        target_ct = ContentType.objects.using(db_alias).get(
+            app_label=app_label, model=model_name
+        )
+
+        operation = RenameContentType(
+            app_label=app_label,
+            old_model=model_name,
+            new_model='renamedcontenttype',
+        )
+
+        # We patch the manager's get_by_natural_key to control the instance
+        # that the operation receives.
+        with patch.object(ContentTypeManager, 'get_by_natural_key') as mock_get_ct:
+            # We also patch the 'save' method on the specific instance that
+            # will be returned, so we can inspect how it's called.
+            with patch.object(target_ct, 'save') as mock_save:
+                mock_get_ct.return_value = target_ct
+
+                # Run the operation.
+                operation.rename_forward(project_state.apps, schema_editor)
+
+                # The bug is that `using=db` is missing from the save call.
+                # The fix adds it. This assertion will fail on the unfixed
+                # code (raising an AssertionError) and pass on the fixed code.
+                mock_save.assert_called_with(
+                    using=db_alias,
+                    update_fields={'model'}
+                )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/contenttypes/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_rename_content_type_multidb
cat coverage.cover
git checkout 4b45b6c8e4d7c9701a332e80d3b1c84209dc36e2
git apply /root/pre_state.patch
