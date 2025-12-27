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
diff --git a/tests/prefetch_related/test_defer_prefetch.py b/tests/prefetch_related/test_defer_prefetch.py
new file mode 100644
index 0000000000..3aac6f200c
--- /dev/null
+++ b/tests/prefetch_related/test_defer_prefetch.py
@@ -0,0 +1,48 @@
+from django.db import models
+from django.db.models import Prefetch
+from django.test import TestCase
+
+# Models defined for this test case based on the bug report
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
+    user = models.OneToOneField(
+        User, on_delete=models.CASCADE, related_name='profile'
+    )
+
+    class Meta:
+        app_label = 'prefetch_related'
+
+
+class DeferPrefetchTests(TestCase):
+    def test_only_related_queryset(self):
+        """
+        A nested prefetch shouldn't inherit the deferred fields from its parent
+        prefetch.
+        """
+        user = User.objects.create(
+            email="test@example.com",
+            kind="ADMIN",
+        )
+        Profile.objects.create(user=user, full_name="Test Tester")
+        queryset = User.objects.only("email").prefetch_related(
+            Prefetch(
+                "profile",
+                queryset=Profile.objects.prefetch_related(
+                    Prefetch("user", queryset=User.objects.only("kind"))
+                ),
+            )
+        )
+        with self.assertNumQueries(3):
+            user = queryset.first()
+        with self.assertNumQueries(0):
+            self.assertEqual(user.profile.user.kind, "ADMIN")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related_descriptors\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 prefetch_related.test_defer_prefetch
cat coverage.cover
git checkout 973fa566521037ac140dcece73fceae50ee522f1
git apply /root/pre_state.patch
