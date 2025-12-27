#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ba726067604ce5a8ca3919edf653496722b433ab >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ba726067604ce5a8ca3919edf653496722b433ab
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/prefetch_related/test_gfk_to_uuid.py b/tests/prefetch_related/test_gfk_to_uuid.py
new file mode 100644
index 0000000000..a366146165
--- /dev/null
+++ b/tests/prefetch_related/test_gfk_to_uuid.py
@@ -0,0 +1,49 @@
+import uuid
+
+from django.contrib.contenttypes.fields import GenericForeignKey
+from django.contrib.contenttypes.models import ContentType
+from django.db import models
+from django.test import TestCase
+
+# The models are defined with an `app_label` that is known to exist during
+# the test run. The Django test runner discovers test applications (like
+# 'prefetch_related' from the tests/prefetch_related directory) and adds them
+# to INSTALLED_APPS.
+class Foo(models.Model):
+    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
+
+    class Meta:
+        app_label = 'prefetch_related'
+
+
+class Bar(models.Model):
+    foo_content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE)
+    # The object_id needs to be a CharField to store the UUID as a string.
+    # A UUID string with hyphens is 36 characters long.
+    foo_object_id = models.CharField(max_length=36)
+    foo = GenericForeignKey('foo_content_type', 'foo_object_id')
+
+    class Meta:
+        app_label = 'prefetch_related'
+
+
+class PrefetchRelatedGFKToUUIDTests(TestCase):
+    def test_prefetch_gfk_to_uuid_pk(self):
+        """
+        Test prefetching a GenericForeignKey that points to a model with a
+        UUID primary key.
+        """
+        foo_obj = Foo.objects.create()
+        Bar.objects.create(foo=foo_obj)
+
+        # The prefetch_related() is the key part of the test.
+        # It takes 2 queries: one for Bar, one for the prefetched Foo.
+        with self.assertNumQueries(2):
+            bar_obj = Bar.objects.prefetch_related('foo').get()
+
+        # Without the fix, the GFK relation is not correctly hydrated
+        # from the prefetched objects. Accessing `bar_obj.foo` will return None
+        # because the key types (string vs UUID object) mismatch during the
+        # prefetch "stitching". This causes the assertion to fail.
+        with self.assertNumQueries(0):
+            self.assertEqual(bar_obj.foo, foo_obj)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 prefetch_related.test_gfk_to_uuid
cat coverage.cover
git checkout ba726067604ce5a8ca3919edf653496722b433ab
git apply /root/pre_state.patch
