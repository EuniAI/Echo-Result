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
diff --git a/tests/serializers/test_natural_key_multidb.py b/tests/serializers/test_natural_key_multidb.py
new file mode 100644
index 0000000000..83376fbd58
--- /dev/null
+++ b/tests/serializers/test_natural_key_multidb.py
@@ -0,0 +1,88 @@
+import json
+
+from django.core import serializers
+from django.core.serializers.base import DeserializationError
+from django.db import models
+from django.test import TestCase
+
+
+class NKAuthorManager(models.Manager):
+    def get_by_natural_key(self, name):
+        return self.get(name=name)
+
+
+class NKBookManager(models.Manager):
+    def get_by_natural_key(self, title, author_name):
+        return self.get(title=title, author__name=author_name)
+
+
+class NKAuthor(models.Model):
+    name = models.CharField(max_length=255, unique=True)
+    objects = NKAuthorManager()
+
+    class Meta:
+        app_label = "serializers"
+
+    def natural_key(self):
+        return (self.name,)
+
+
+class NKBook(models.Model):
+    title = models.CharField(max_length=255)
+    author = models.ForeignKey(NKAuthor, models.CASCADE)
+    objects = NKBookManager()
+
+    class Meta:
+        app_label = "serializers"
+        unique_together = (("title", "author"),)
+
+    def natural_key(self):
+        return (self.title,) + self.author.natural_key()
+
+    natural_key.dependencies = ["serializers.nkauthor"]
+
+
+class NaturalKeyMultiDBTests(TestCase):
+    databases = {"default", "other"}
+    available_apps = [
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+        "serializers",
+    ]
+
+    def test_deserialization_with_natural_key_fk_on_other_db(self):
+        """
+        Tests that deserializing an object with a natural key that depends
+        on a foreign key works on a non-default database.
+        """
+        # 1. Create the dependency (author) on the 'other' database. It must
+        # not exist on the default database to reproduce the bug.
+        author = NKAuthor.objects.using("other").create(name="JR Tolkien")
+        self.assertFalse(NKAuthor.objects.using("default").exists())
+
+        # 2. Define the data for the object that has a natural foreign key.
+        book_data = json.dumps(
+            [
+                {
+                    "model": "serializers.nkbook",
+                    "fields": {"title": "The Ring", "author": ["JR Tolkien"]},
+                }
+            ]
+        )
+
+        # 3. Attempt to deserialize the data using the 'other' database.
+        # Before the patch, this fails with DeserializationError (wrapping
+        # a DoesNotExist) because the author is looked up on 'default'.
+        # After the patch, this should succeed.
+        deserialized_objects = list(
+            serializers.deserialize("json", book_data, using="other")
+        )
+
+        # 4. Save the deserialized object to the 'other' database.
+        self.assertEqual(len(deserialized_objects), 1)
+        deserialized_objects[0].save(using="other")
+
+        # 5. Verify the object was created correctly in the 'other' database.
+        final_book = NKBook.objects.using("other").get()
+        self.assertEqual(final_book.title, "The Ring")
+        self.assertEqual(final_book.author, author)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/serializers/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 serializers.test_natural_key_multidb
cat coverage.cover
git checkout fbacaa58ffc5a62456ee68b90efa13957f761ce4
git apply /root/pre_state.patch
