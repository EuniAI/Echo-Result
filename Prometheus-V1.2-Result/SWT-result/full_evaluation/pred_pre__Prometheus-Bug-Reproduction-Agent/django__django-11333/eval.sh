#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 55b68de643b5c2d5f0a8ea7587ab3b2966021ccc >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 55b68de643b5c2d5f0a8ea7587ab3b2966021ccc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/urlpatterns_reverse/test_resolver_caching.py b/tests/urlpatterns_reverse/test_resolver_caching.py
new file mode 100644
index 0000000000..8e1aad8ede
--- /dev/null
+++ b/tests/urlpatterns_reverse/test_resolver_caching.py
@@ -0,0 +1,38 @@
+from django.test import SimpleTestCase, override_settings
+from django.urls import get_resolver, reverse, set_urlconf
+
+
+@override_settings(ROOT_URLCONF='urlpatterns_reverse.named_urls')
+class URLResolverPopulationTests(SimpleTestCase):
+    """
+    Tests for the caching behavior of get_resolver to prevent multiple
+    expensive URLResolver constructions.
+    """
+    def test_get_resolver_cache_size(self):
+        """
+        get_resolver() should not create and cache multiple URLResolver
+        instances when called before and after the URLconf is set.
+        """
+        # Ensure a clean state for the test.
+        get_resolver.cache_clear()
+        set_urlconf(None)
+
+        # Simulate a call to reverse() at import time, before any request has
+        # happened. This calls get_resolver(None) and caches a resolver.
+        # This call is expected to fail before the fix, so we wrap it to
+        # allow the test to continue to the assertion.
+        try:
+            reverse('named-url1')
+        except Exception:
+            pass
+
+        # Simulate a request. The request handling logic sets the URLconf,
+        # leading to a second call to get_resolver() with the actual
+        # ROOT_URLCONF from settings.
+        self.client.get('/')
+
+        # The bug is that a second, distinct resolver is cached. The cache
+        # size will be 2. With the fix, the first call to get_resolver(None)
+        # should use settings.ROOT_URLCONF, resulting in a single cached
+        # resolver. This assertion will fail until the bug is fixed.
+        self.assertEqual(get_resolver.cache_info().currsize, 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/urls/base\.py|django/urls/resolvers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 urlpatterns_reverse.test_resolver_caching
cat coverage.cover
git checkout 55b68de643b5c2d5f0a8ea7587ab3b2966021ccc
git apply /root/pre_state.patch
