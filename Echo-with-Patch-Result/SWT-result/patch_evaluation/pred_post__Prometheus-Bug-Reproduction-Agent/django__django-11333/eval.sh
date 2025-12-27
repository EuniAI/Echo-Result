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
diff --git a/django/urls/base.py b/django/urls/base.py
--- a/django/urls/base.py
+++ b/django/urls/base.py
@@ -7,7 +7,7 @@
 from django.utils.translation import override
 
 from .exceptions import NoReverseMatch, Resolver404
-from .resolvers import get_ns_resolver, get_resolver
+from .resolvers import _get_cached_resolver, get_ns_resolver, get_resolver
 from .utils import get_callable
 
 # SCRIPT_NAME prefixes for each thread are stored here. If there's no entry for
@@ -92,7 +92,7 @@ def reverse(viewname, urlconf=None, args=None, kwargs=None, current_app=None):
 
 def clear_url_caches():
     get_callable.cache_clear()
-    get_resolver.cache_clear()
+    _get_cached_resolver.cache_clear()
     get_ns_resolver.cache_clear()
 
 
diff --git a/django/urls/resolvers.py b/django/urls/resolvers.py
--- a/django/urls/resolvers.py
+++ b/django/urls/resolvers.py
@@ -63,10 +63,14 @@ def __repr__(self):
         )
 
 
-@functools.lru_cache(maxsize=None)
 def get_resolver(urlconf=None):
     if urlconf is None:
         urlconf = settings.ROOT_URLCONF
+    return _get_cached_resolver(urlconf)
+
+
+@functools.lru_cache(maxsize=None)
+def _get_cached_resolver(urlconf=None):
     return URLResolver(RegexPattern(r'^/'), urlconf)
 
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_resolver_cache_optimization.py b/tests/test_resolver_cache_optimization.py
new file mode 100644
index 0000000000..6072065df7
--- /dev/null
+++ b/tests/test_resolver_cache_optimization.py
@@ -0,0 +1,52 @@
+from unittest.mock import patch
+
+from django.conf import settings
+from django.test import SimpleTestCase, override_settings
+from django.urls import (
+    URLResolver,
+    clear_url_caches,
+    reverse,
+    set_urlconf,
+)
+
+
+@override_settings(ROOT_URLCONF="urlpatterns_reverse.urls")
+class ResolverCacheOptimizationTests(SimpleTestCase):
+    def setUp(self):
+        clear_url_caches()
+        set_urlconf(None)
+
+    def tearDown(self):
+        clear_url_caches()
+        set_urlconf(None)
+
+    def test_get_resolver_cache_optimization(self):
+        # Spy on URLResolver._populate to count how many times it's called.
+        populate_call_count = [0]
+        original_populate = URLResolver._populate
+
+        def spy_populate(resolver_instance):
+            populate_call_count[0] += 1
+            return original_populate(resolver_instance)
+
+        with patch.object(URLResolver, "_populate", spy_populate):
+            # 1. First call to reverse(), e.g., at import time before a request.
+            # get_urlconf() returns None.
+            reverse("hardcoded")
+            # The resolver and its children are populated. Record the call count.
+            first_call_count = populate_call_count[0]
+            self.assertGreater(first_call_count, 0)
+
+            # 2. A request comes in, and BaseHandler calls set_urlconf().
+            set_urlconf(settings.ROOT_URLCONF)
+
+            # 3. Second call to reverse() during the request.
+            # get_urlconf() now returns settings.ROOT_URLCONF.
+            reverse("hardcoded")
+
+            # With the bug, get_resolver gets a different argument, misses the
+            # cache, creates a new resolver, and populates it again.
+            # With the fix, get_resolver(None) resolves to the same cached
+            # resolver as get_resolver(ROOT_URLCONF), so _populate is not
+            # called again.
+            self.assertEqual(populate_call_count[0], first_call_count)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/urls/resolvers\.py|django/urls/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_resolver_cache_optimization
cat coverage.cover
git checkout 55b68de643b5c2d5f0a8ea7587ab3b2966021ccc
git apply /root/pre_state.patch
