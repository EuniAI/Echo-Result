#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 953f29f700a60fc09b08b2c2270c12c447490c6a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 953f29f700a60fc09b08b2c2270c12c447490c6a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/apps/registry.py b/django/apps/registry.py
--- a/django/apps/registry.py
+++ b/django/apps/registry.py
@@ -373,6 +373,7 @@ def clear_cache(self):
 
         This is mostly used in tests.
         """
+        self.get_swappable_settings_name.cache_clear()
         # Call expire cache on each model. This will purge
         # the relation tree and the fields cache.
         self.get_models.cache_clear()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/apps/test_swappable_cache.py b/tests/apps/test_swappable_cache.py
new file mode 100644
index 0000000000..3c404ab63a
--- /dev/null
+++ b/tests/apps/test_swappable_cache.py
@@ -0,0 +1,20 @@
+from django.apps import apps
+from django.test import SimpleTestCase, override_settings
+
+
+class RegistryCacheTests(SimpleTestCase):
+    @override_settings(
+        INSTALLED_APPS=["swappable_models"],
+        TEST_ARTICLE_MODEL="swappable_models.AlternateArticle",
+    )
+    def test_clear_cache_clears_swappable_cache(self):
+        """
+        Apps.clear_cache() clears the get_swappable_settings_name() cache.
+        """
+        # Populate the cache.
+        apps.get_swappable_settings_name("swappable_models.article")
+        self.assertEqual(apps.get_swappable_settings_name.cache_info().currsize, 1)
+        # Clear cache and check that get_swappable_settings_name() cache is
+        # cleared.
+        apps.clear_cache()
+        self.assertEqual(apps.get_swappable_settings_name.cache_info().currsize, 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/apps/registry\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 apps.test_swappable_cache
cat coverage.cover
git checkout 953f29f700a60fc09b08b2c2270c12c447490c6a
git apply /root/pre_state.patch
