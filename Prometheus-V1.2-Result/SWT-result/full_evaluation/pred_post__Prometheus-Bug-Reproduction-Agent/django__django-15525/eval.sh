#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fbacaa58ffc5a62456ee68b90efa13957f761ce4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fbacaa58ffc5a62456ee68b90efa13957f761ce4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/serializers/base.py b/django/core/serializers/base.py
--- a/django/core/serializers/base.py
+++ b/django/core/serializers/base.py
@@ -336,7 +336,9 @@ def build_instance(Model, data, db):
         and hasattr(default_manager, "get_by_natural_key")
         and hasattr(Model, "natural_key")
     ):
-        natural_key = Model(**data).natural_key()
+        obj = Model(**data)
+        obj._state.db = db
+        natural_key = obj.natural_key()
         try:
             data[Model._meta.pk.attname] = Model._meta.pk.to_python(
                 default_manager.db_manager(db).get_by_natural_key(*natural_key).pk

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/multiple_database/test_loaddata_natural_key.py b/tests/multiple_database/test_loaddata_natural_key.py
new file mode 100644
index 0000000000..148ec7ece1
--- /dev/null
+++ b/tests/multiple_database/test_loaddata_natural_key.py
@@ -0,0 +1,101 @@
+import os
+import tempfile
+
+from django.core import management
+from django.db import models
+from django.test import TestCase, override_settings
+
+
+# Define models with unique names to avoid conflicts with existing test models.
+# These models replicate the structure described in the bug report.
+class NKAuthorManager(models.Manager):
+    def get_by_natural_key(self, name):
+        return self.get(name=name)
+
+
+class NKAuthor(models.Model):
+    name = models.CharField(max_length=255, unique=True)
+    objects = NKAuthorManager()
+
+    class Meta:
+        app_label = "multiple_database"
+
+    def natural_key(self):
+        return (self.name,)
+
+
+class NKBookManager(models.Manager):
+    def get_by_natural_key(self, title, author_name):
+        return self.get(title=title, author__name=author_name)
+
+
+class NKBook(models.Model):
+    title = models.CharField(max_length=255)
+    author = models.ForeignKey(NKAuthor, models.DO_NOTHING)
+    objects = NKBookManager()
+
+    class Meta:
+        app_label = "multiple_database"
+        unique_together = (("title", "author"),)
+
+    def natural_key(self):
+        return (self.title,) + self.author.natural_key()
+
+    natural_key.dependencies = ["multiple_database.NKAuthor"]
+
+
+@override_settings(
+    INSTALLED_APPS=[
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+        "multiple_database",
+    ]
+)
+class LoaddataNaturalKeyMultiDBTests(TestCase):
+    databases = {"default", "other"}
+    available_apps = ["multiple_database"]
+
+    def test_loaddata_natural_key_foreign_key_other_db(self):
+        """
+        Test that loaddata works with natural keys and foreign keys on a
+        non-default database.
+        """
+        # Fixture data using natural keys, with model names updated to match
+        # the uniquely named models defined for this test.
+        fixture_content = """
+[
+    {
+        "model": "multiple_database.nkauthor",
+        "fields": {
+            "name": "JR Tolkien"
+        }
+    },
+    {
+        "model": "multiple_database.nkbook",
+        "fields": {
+            "title": "The Ring",
+            "author": ["JR Tolkien"]
+        }
+    }
+]
+"""
+        with tempfile.TemporaryDirectory() as tempdir:
+            fixture_path = os.path.join(tempdir, "books.json")
+            with open(fixture_path, "w") as f:
+                f.write(fixture_content)
+
+            with override_settings(FIXTURE_DIRS=[tempdir]):
+                # This command will raise NKAuthor.DoesNotExist before the fix,
+                # because the FK lookup for the author's natural key will
+                # incorrectly query the 'default' database instead of 'other'.
+                management.call_command(
+                    "loaddata",
+                    "books.json",
+                    database="other",
+                    verbosity=0,
+                )
+
+        # This assertion will only be reached after the bug is fixed. It
+        # confirms that the book was loaded correctly into the 'other' db.
+        book = NKBook.objects.using("other").get(title="The Ring")
+        self.assertEqual(book.author.name, "JR Tolkien")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/serializers/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 multiple_database.test_loaddata_natural_key
cat coverage.cover
git checkout fbacaa58ffc5a62456ee68b90efa13957f761ce4
git apply /root/pre_state.patch
