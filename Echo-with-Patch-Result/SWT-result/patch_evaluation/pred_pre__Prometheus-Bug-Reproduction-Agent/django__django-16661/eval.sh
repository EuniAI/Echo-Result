#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d687febce5868545f99974d2499a91f81a32fef5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d687febce5868545f99974d2499a91f81a32fef5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/modeladmin/test_lookup_allowed.py b/tests/modeladmin/test_lookup_allowed.py
new file mode 100644
index 0000000000..62d4272e7b
--- /dev/null
+++ b/tests/modeladmin/test_lookup_allowed.py
@@ -0,0 +1,38 @@
+from django.contrib.admin.options import ModelAdmin
+from django.contrib.admin.sites import AdminSite
+from django.db import models
+from django.test import TestCase
+from django.test.utils import isolate_apps
+
+
+class ModelAdminLookupAllowedTests(TestCase):
+    def setUp(self):
+        self.site = AdminSite()
+
+    @isolate_apps("modeladmin")
+    def test_lookup_allowed_foreign_primary(self):
+        """
+        Test that lookup_allowed works correctly with a ForeignKey as a primary key.
+        """
+
+        class Country(models.Model):
+            name = models.CharField(max_length=256)
+
+        class Place(models.Model):
+            country = models.ForeignKey(Country, models.CASCADE)
+
+        class Restaurant(models.Model):
+            place = models.OneToOneField(Place, models.CASCADE, primary_key=True)
+
+        class Waiter(models.Model):
+            restaurant = models.ForeignKey(Restaurant, models.CASCADE)
+
+        class WaiterAdmin(ModelAdmin):
+            list_filter = [
+                "restaurant__place__country",
+            ]
+
+        ma = WaiterAdmin(Waiter, self.site)
+        self.assertIs(
+            ma.lookup_allowed("restaurant__place__country", "test_value"), True
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 modeladmin.test_lookup_allowed
cat coverage.cover
git checkout d687febce5868545f99974d2499a91f81a32fef5
git apply /root/pre_state.patch
