#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 973fa566521037ac140dcece73fceae50ee522f1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 973fa566521037ac140dcece73fceae50ee522f1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/related_descriptors.py b/django/db/models/fields/related_descriptors.py
--- a/django/db/models/fields/related_descriptors.py
+++ b/django/db/models/fields/related_descriptors.py
@@ -646,8 +646,9 @@ def get_prefetch_queryset(self, instances, queryset=None):
             # Since we just bypassed this class' get_queryset(), we must manage
             # the reverse relation manually.
             for rel_obj in queryset:
-                instance = instances_dict[rel_obj_attr(rel_obj)]
-                setattr(rel_obj, self.field.name, instance)
+                if not self.field.is_cached(rel_obj):
+                    instance = instances_dict[rel_obj_attr(rel_obj)]
+                    setattr(rel_obj, self.field.name, instance)
             cache_name = self.field.remote_field.get_cache_name()
             return queryset, rel_obj_attr, instance_attr, False, cache_name, False
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_prefetch_related_deferred_fields.py b/tests/test_prefetch_related_deferred_fields.py
new file mode 100644
index 0000000000..6ff2859622
--- /dev/null
+++ b/tests/test_prefetch_related_deferred_fields.py
@@ -0,0 +1,59 @@
+from django.db import models
+from django.db.models import Prefetch
+from django.test import TestCase
+
+# Models defined directly in the test file to make it self-contained.
+# The app_label is necessary for the test runner to discover the models.
+class User(models.Model):
+    email = models.EmailField()
+    kind = models.CharField(
+        max_length=10, choices=[("ADMIN", "Admin"), ("REGULAR", "Regular")]
+    )
+
+    class Meta:
+        app_label = 'prefetch_related'
+
+
+class Profile(models.Model):
+    full_name = models.CharField(max_length=255)
+    user = models.OneToOneField(User, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'prefetch_related'
+
+
+class PrefetchRelatedDeferredFieldsTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        """Set up data for the whole test case."""
+        user = User.objects.create(
+            email="test@example.com",
+            kind="ADMIN",
+        )
+        Profile.objects.create(user=user, full_name="Test Tester")
+
+    def test_only_related_queryset(self):
+        """
+        Test that deferred fields from an outer queryset don't affect a
+        nested prefetch queryset.
+        """
+        queryset = User.objects.only("email").prefetch_related(
+            Prefetch(
+                "profile",
+                queryset=Profile.objects.prefetch_related(
+                    Prefetch("user", queryset=User.objects.only("kind"))
+                ),
+            )
+        )
+        # The initial fetch should execute 3 queries:
+        # 1. The main User object (email only).
+        # 2. The related Profile object.
+        # 3. The nested User object from the profile (kind only).
+        with self.assertNumQueries(3):
+            user = queryset.first()
+
+        # Accessing user.profile.user.kind should not trigger a query, as 'kind'
+        # should have been loaded by the nested prefetch. The bug causes an
+        # extra query here.
+        with self.assertNumQueries(0):
+            self.assertEqual(user.profile.user.kind, "ADMIN")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related_descriptors\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_prefetch_related_deferred_fields
cat coverage.cover
git checkout 973fa566521037ac140dcece73fceae50ee522f1
git apply /root/pre_state.patch
