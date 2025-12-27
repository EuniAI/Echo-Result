#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d3d173425fc0a1107836da5b4567f1c88253191b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d3d173425fc0a1107836da5b4567f1c88253191b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_admin_e035_check.py b/tests/test_admin_e035_check.py
new file mode 100644
index 0000000000..fcec6fac1a
--- /dev/null
+++ b/tests/test_admin_e035_check.py
@@ -0,0 +1,27 @@
+from django.contrib import admin
+from django.contrib.admin import AdminSite
+from django.core import checks
+from django.test import SimpleTestCase
+
+from .models import City, State
+
+
+class ReadonlyFieldMessagesTest(SimpleTestCase):
+    def test_readonly_nonexistent_field_error_message(self):
+        class CityInline(admin.TabularInline):
+            model = City
+            readonly_fields = ["nonexistent_field"]
+
+        errors = CityInline(State, AdminSite()).check()
+        self.assertEqual(
+            errors,
+            [
+                checks.Error(
+                    "The value of 'readonly_fields[0]' refers to "
+                    "'nonexistent_field', which is not a callable, an attribute "
+                    "of 'CityInline', or an attribute of 'admin_checks.City'.",
+                    obj=CityInline,
+                    id="admin.E035",
+                )
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/checks\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_admin_e035_check
cat coverage.cover
git checkout d3d173425fc0a1107836da5b4567f1c88253191b
git apply /root/pre_state.patch
