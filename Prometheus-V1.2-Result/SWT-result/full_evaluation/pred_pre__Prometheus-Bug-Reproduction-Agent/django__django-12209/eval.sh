#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5a68f024987e6d16c2626a31bf653a2edddea579 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5a68f024987e6d16c2626a31bf653a2edddea579
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_uuid_pk.py b/tests/model_fields/test_uuid_pk.py
new file mode 100644
index 0000000000..46863eea6d
--- /dev/null
+++ b/tests/model_fields/test_uuid_pk.py
@@ -0,0 +1,85 @@
+import uuid
+
+from django.db import IntegrityError
+from django.test import TestCase, TransactionTestCase, skipUnlessDBFeature
+
+from .models import (
+    PrimaryKeyUUIDModel, RelatedToUUIDModel, UUIDChild, UUIDGrandchild,
+)
+
+
+class TestAsPrimaryKey(TestCase):
+    def test_creation(self):
+        PrimaryKeyUUIDModel.objects.create()
+        loaded = PrimaryKeyUUIDModel.objects.get()
+        self.assertIsInstance(loaded.pk, uuid.UUID)
+
+    def test_uuid_pk_on_save(self):
+        saved = PrimaryKeyUUIDModel.objects.create(id=None)
+        loaded = PrimaryKeyUUIDModel.objects.get()
+        self.assertIsNotNone(loaded.id, None)
+        self.assertEqual(loaded.id, saved.id)
+
+    def test_uuid_pk_on_bulk_create(self):
+        u1 = PrimaryKeyUUIDModel()
+        u2 = PrimaryKeyUUIDModel(id=None)
+        PrimaryKeyUUIDModel.objects.bulk_create([u1, u2])
+        # The two objects were correctly created.
+        u1_found = PrimaryKeyUUIDModel.objects.filter(id=u1.id).exists()
+        u2_found = PrimaryKeyUUIDModel.objects.exclude(id=u1.id).exists()
+        self.assertTrue(u1_found)
+        self.assertTrue(u2_found)
+        self.assertEqual(PrimaryKeyUUIDModel.objects.count(), 2)
+
+    def test_underlying_field(self):
+        pk_model = PrimaryKeyUUIDModel.objects.create()
+        RelatedToUUIDModel.objects.create(uuid_fk=pk_model)
+        related = RelatedToUUIDModel.objects.get()
+        self.assertEqual(related.uuid_fk.pk, related.uuid_fk_id)
+
+    def test_update_with_related_model_instance(self):
+        # regression for #24611
+        u1 = PrimaryKeyUUIDModel.objects.create()
+        u2 = PrimaryKeyUUIDModel.objects.create()
+        r = RelatedToUUIDModel.objects.create(uuid_fk=u1)
+        RelatedToUUIDModel.objects.update(uuid_fk=u2)
+        r.refresh_from_db()
+        self.assertEqual(r.uuid_fk, u2)
+
+    def test_update_with_related_model_id(self):
+        u1 = PrimaryKeyUUIDModel.objects.create()
+        u2 = PrimaryKeyUUIDModel.objects.create()
+        r = RelatedToUUIDModel.objects.create(uuid_fk=u1)
+        RelatedToUUIDModel.objects.update(uuid_fk=u2.pk)
+        r.refresh_from_db()
+        self.assertEqual(r.uuid_fk, u2)
+
+    def test_two_level_foreign_keys(self):
+        gc = UUIDGrandchild()
+        # exercises ForeignKey.get_db_prep_value()
+        gc.save()
+        self.assertIsInstance(gc.uuidchild_ptr_id, uuid.UUID)
+        gc.refresh_from_db()
+        self.assertIsInstance(gc.uuidchild_ptr_id, uuid.UUID)
+
+    def test_save_explicit_pk_with_default(self):
+        """
+        Saving a model instance with an explicit PK value should result in an
+        UPDATE if the PK already exists, even if the PK field has a default.
+        """
+        obj = PrimaryKeyUUIDModel.objects.create()
+        # This save() should be an UPDATE, not an INSERT. Before the fix, this
+        # will raise an IntegrityError.
+        PrimaryKeyUUIDModel(pk=obj.pk).save()
+        self.assertEqual(PrimaryKeyUUIDModel.objects.count(), 1)
+
+
+class TestAsPrimaryKeyTransactionTests(TransactionTestCase):
+    # Need a TransactionTestCase to avoid deferring FK constraint checking.
+    available_apps = ['model_fields']
+
+    @skipUnlessDBFeature('supports_foreign_keys')
+    def test_unsaved_fk(self):
+        u1 = PrimaryKeyUUIDModel()
+        with self.assertRaises(IntegrityError):
+            RelatedToUUIDModel.objects.create(uuid_fk=u1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_uuid_pk
cat coverage.cover
git checkout 5a68f024987e6d16c2626a31bf653a2edddea579
git apply /root/pre_state.patch
