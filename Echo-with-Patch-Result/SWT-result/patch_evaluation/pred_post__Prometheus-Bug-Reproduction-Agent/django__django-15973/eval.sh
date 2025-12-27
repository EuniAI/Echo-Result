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
diff --git a/tests/migrations/test_many_to_many_through_cross_app.py b/tests/migrations/test_many_to_many_through_cross_app.py
new file mode 100644
index 0000000000..5d3f047ead
--- /dev/null
+++ b/tests/migrations/test_many_to_many_through_cross_app.py
@@ -0,0 +1,89 @@
+from django.db import connection, migrations, models
+from django.db.migrations.state import ProjectState
+
+from .test_base import OperationTestBase
+
+
+class ManyToManyThroughCrossAppTests(OperationTestBase):
+    def test_m2m_through_model_in_other_app(self):
+        """
+        Tests that creating a model with a ManyToManyField referencing a
+        `through` model in another app by string doesn't fail.
+        """
+        app_label = "fonte"
+        related_app_label = "variavel"
+        through_app_label = "fonte_variavel"
+
+        # These are the operations to set up the 'variavel' app.
+        variavel_ops = [
+            migrations.CreateModel(
+                "VariavelModel",
+                fields=[
+                    (
+                        "id",
+                        models.BigAutoField(
+                            auto_created=True,
+                            primary_key=True,
+                            serialize=False,
+                            verbose_name="ID",
+                        ),
+                    ),
+                    ("nome", models.TextField(unique=True)),
+                    ("descricao", models.TextField()),
+                ],
+                options={"db_table": "variaveis"},
+            )
+        ]
+        # State before migration: the related 'to' model 'VariavelModel'
+        # exists in a different app.
+        project_state = self.apply_operations(
+            related_app_label, ProjectState(), variavel_ops
+        )
+
+        # This is the operation that causes the bug.
+        operation = migrations.CreateModel(
+            name="FonteModel",
+            fields=[
+                (
+                    "id",
+                    models.BigAutoField(
+                        auto_created=True,
+                        primary_key=True,
+                        serialize=False,
+                        verbose_name="ID",
+                    ),
+                ),
+                ("nome", models.TextField(unique=True)),
+                ("descricao", models.TextField()),
+                ("data_inicial", models.DateField()),
+                ("data_final", models.DateField(blank=True, null=True)),
+                (
+                    "variaveis",
+                    models.ManyToManyField(
+                        to=f"{related_app_label}.VariavelModel",
+                        through=f"{through_app_label}.FonteVariavelModel",
+                    ),
+                ),
+            ],
+            options={"db_table": "fontes"},
+        )
+
+        # This will raise AttributeError before the fix.
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+        with connection.schema_editor() as editor:
+            operation.database_forwards(app_label, editor, project_state, new_state)
+
+        # The assertion is that the table for FonteModel is created.
+        self.assertTableExists("fontes")
+
+        # Cleanup: Manually drop the 'fontes' table to avoid calling
+        # delete_model(), which has the same bug but is not covered by the patch.
+        # Then, properly unapply the setup operations for the 'variavel' app.
+        try:
+            with connection.schema_editor() as editor:
+                editor.execute(
+                    editor.sql_delete_table % {"table": editor.quote_name("fontes")}
+                )
+        finally:
+            self.unapply_operations(related_app_label, project_state, variavel_ops)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/autodetector\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_many_to_many_through_cross_app
cat coverage.cover
git checkout 2480554dc4ada4ecf3f6a08e318735a2e50783f3
git apply /root/pre_state.patch
