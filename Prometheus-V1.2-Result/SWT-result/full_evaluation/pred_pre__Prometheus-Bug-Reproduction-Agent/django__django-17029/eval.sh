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
diff --git a/tests/apps/test_registry.py b/tests/apps/test_registry.py
new file mode 100644
index 0000000000..ad96c0fcbb
--- /dev/null
+++ b/tests/apps/test_registry.py
@@ -0,0 +1,28 @@
+from unittest.mock import patch
+
+from django.apps import apps
+from django.apps.registry import Apps
+from django.test import SimpleTestCase, override_settings
+
+
+class AppsCacheTests(SimpleTestCase):
+    @override_settings(
+        INSTALLED_APPS=[
+            "django.contrib.auth",
+            "django.contrib.contenttypes",
+            "swappable_models",
+        ],
+        TEST_ARTICLE_MODEL="swappable_models.AlternateArticle",
+    )
+    def test_clear_cache_clears_swappable_settings_cache(self):
+        """
+        Apps.clear_cache() should clear the get_swappable_settings_name()
+        cache.
+        """
+        # Populate get_swappable_settings_name() cache.
+        apps.get_swappable_settings_name("swappable_models.article")
+        with patch.object(
+            Apps.get_swappable_settings_name, "cache_clear"
+        ) as mock_cache_clear:
+            apps.clear_cache()
+        mock_cache_clear.assert_called_once()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/apps/registry\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 apps.test_registry
cat coverage.cover
git checkout 953f29f700a60fc09b08b2c2270c12c447490c6a
git apply /root/pre_state.patch
