#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2480554dc4ada4ecf3f6a08e318735a2e50783f3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2480554dc4ada4ecf3f6a08e318735a2e50783f3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/autodetector.py b/django/db/migrations/autodetector.py
--- a/django/db/migrations/autodetector.py
+++ b/django/db/migrations/autodetector.py
@@ -1422,7 +1422,7 @@ def _get_dependencies_for_foreign_key(app_label, model_name, field, project_stat
         dependencies = [(dep_app_label, dep_object_name, None, True)]
         if getattr(field.remote_field, "through", None):
             through_app_label, through_object_name = resolve_relation(
-                remote_field_model,
+                field.remote_field.through,
                 app_label,
                 model_name,
             )

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_m2m_through_migration.py b/tests/migrations/test_m2m_through_migration.py
new file mode 100644
index 0000000000..a89f25cd2a
--- /dev/null
+++ b/tests/migrations/test_m2m_through_migration.py
@@ -0,0 +1,67 @@
+from django.db import migrations, models
+from django.db.migrations.state import ProjectState
+
+from .test_base import OperationTestBase
+
+
+class M2MThroughSeparateAppTest(OperationTestBase):
+    def test_m2m_through_in_separate_app_migration(self):
+        """
+        Tests that applying a migration with a CreateModel operation for a model
+        that has a ManyToManyField with a 'through' model in a separate, not-yet-
+        migrated app does not cause an AttributeError.
+        """
+        # Initial state is empty.
+        project_state = ProjectState()
+
+        # 1. Simulate the migration of the 'variavel' app, which contains the
+        # target model of the M2M relationship.
+        project_state = self.apply_operations(
+            "variavel",
+            project_state,
+            operations=[
+                migrations.CreateModel(
+                    "VariavelModel",
+                    fields=[
+                        ("id", models.AutoField(primary_key=True)),
+                        ("nome", models.TextField(unique=True)),
+                    ],
+                )
+            ],
+        )
+
+        # 2. Define the migration for the 'fonte' app. This migration creates
+        # the FonteModel, which has a ManyToManyField pointing to VariavelModel
+        # through FonteVariavelModel. The 'through' model is specified as a
+        # string 'app_label.ModelName' and its app ('fonte_variavel') has not
+        # been migrated yet.
+        fonte_operations = [
+            migrations.CreateModel(
+                "FonteModel",
+                fields=[
+                    ("id", models.AutoField(primary_key=True)),
+                    ("nome", models.TextField(unique=True)),
+                    (
+                        "variaveis",
+                        models.ManyToManyField(
+                            to="variavel.VariavelModel",
+                            through="fonte_variavel.FonteVariavelModel",
+                        ),
+                    ),
+                ],
+            ),
+        ]
+
+        # 3. Apply the 'fonte' migration. This is the step that currently fails
+        # with "AttributeError: 'str' object has no attribute '_meta'" because
+        # the 'through' model reference is not resolved.
+        self.apply_operations(
+            "fonte",
+            project_state,
+            operations=fonte_operations,
+        )
+
+        # 4. The minimal assertion is to check that the table for FonteModel
+        # was created. This code will only be reached if the CreateModel
+        # operation completes successfully, which will happen once the bug is fixed.
+        self.assertTableExists("fonte_fontemodel")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/autodetector\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_m2m_through_migration
cat coverage.cover
git checkout 2480554dc4ada4ecf3f6a08e318735a2e50783f3
git apply /root/pre_state.patch
