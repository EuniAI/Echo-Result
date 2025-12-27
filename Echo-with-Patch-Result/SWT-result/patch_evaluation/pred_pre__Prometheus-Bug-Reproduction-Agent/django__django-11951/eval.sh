#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 312049091288dbba2299de8d07ea3e3311ed7238 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 312049091288dbba2299de8d07ea3e3311ed7238
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/bulk_create/test_backend_limits.py b/tests/bulk_create/test_backend_limits.py
new file mode 100644
index 0000000000..fcd549eb1c
--- /dev/null
+++ b/tests/bulk_create/test_backend_limits.py
@@ -0,0 +1,43 @@
+import unittest
+from operator import attrgetter
+
+from django.db import IntegrityError, NotSupportedError, connection
+from django.db.models import FileField, Value
+from django.db.models.functions import Lower
+from django.test import (
+    TestCase, override_settings, skipIfDBFeature, skipUnlessDBFeature,
+)
+
+from .models import (
+    Country, NoFields, NullableFields, Pizzeria, ProxyCountry,
+    ProxyMultiCountry, ProxyMultiProxyCountry, ProxyProxyCountry, Restaurant,
+    State, TwoFields,
+)
+
+
+class BulkCreateTests(TestCase):
+    def setUp(self):
+        self.data = [
+            Country(name="United States of America", iso_two_letter="US"),
+            Country(name="The Netherlands", iso_two_letter="NL"),
+            Country(name="Germany", iso_two_letter="DE"),
+            Country(name="Czech Republic", iso_two_letter="CZ")
+        ]
+
+    # ... existing tests from tests/bulk_create/tests.py would be here ...
+
+    @unittest.skipUnless(connection.vendor == 'sqlite', 'SQLite-specific test')
+    @skipUnlessDBFeature('has_bulk_insert')
+    def test_batch_size_respects_backend_limits(self):
+        """
+        The batch_size parameter in bulk_create() should be capped by the
+        maximum batch size supported by the database.
+        """
+        # For SQLite with one field, the limit is 500, due to
+        # SQLITE_MAX_COMPOUND_SELECT.
+        objs = [Restaurant(name=str(i)) for i in range(501)]
+        # With batch_size=501, bulk_create() should fail as it exceeds the
+        # limit. The fix will cap the batch_size at 500, splitting the
+        # operation into two queries (500 and 1), which will succeed.
+        Restaurant.objects.bulk_create(objs, batch_size=501)
+        self.assertEqual(Restaurant.objects.count(), 501)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 bulk_create.test_backend_limits
cat coverage.cover
git checkout 312049091288dbba2299de8d07ea3e3311ed7238
git apply /root/pre_state.patch
