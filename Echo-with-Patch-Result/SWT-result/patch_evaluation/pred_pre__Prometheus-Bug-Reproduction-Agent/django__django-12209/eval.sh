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
diff --git a/basic/tests/test_explicit_pk_default_save.py b/basic/tests/test_explicit_pk_default_save.py
new file mode 100644
index 0000000000..99be929525
--- /dev/null
+++ b/basic/tests/test_explicit_pk_default_save.py
@@ -0,0 +1,27 @@
+import uuid
+
+from django.db import models
+from django.test import TestCase
+
+
+class UUIDPKWithDefault(models.Model):
+    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
+    name = models.CharField(blank=True, max_length=100)
+
+    class Meta:
+        app_label = 'basic'
+
+
+class ExplicitPKDefaultSaveTests(TestCase):
+    def test_explicit_pk_default_save(self):
+        """
+        Saving an instance with an explicit PK that already exists should
+        update it, even if the PK field has a `default`.
+        """
+        obj = UUIDPKWithDefault.objects.create(name='first')
+        new_obj = UUIDPKWithDefault(pk=obj.pk, name='second')
+        new_obj.save()
+        # The bug would cause an IntegrityError on the line above.
+        # Check that the original object was updated.
+        obj.refresh_from_db()
+        self.assertEqual(obj.name, 'second')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 basic.tests.test_explicit_pk_default_save
cat coverage.cover
git checkout 5a68f024987e6d16c2626a31bf653a2edddea579
git apply /root/pre_state.patch
