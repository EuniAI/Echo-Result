#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/get_object_or_404/test_lazy_object_in_get_object_or_404.py b/tests/get_object_or_404/test_lazy_object_in_get_object_or_404.py
new file mode 100644
index 0000000000..31ac4a4e2b
--- /dev/null
+++ b/tests/get_object_or_404/test_lazy_object_in_get_object_or_404.py
@@ -0,0 +1,18 @@
+from django.shortcuts import get_object_or_404
+from django.test import TestCase
+from django.utils.functional import SimpleLazyObject
+
+from .models import Article
+
+
+class GetObjectOr404LazyTests(TestCase):
+    def test_lazy_kwarg_resolved(self):
+        """
+        get_object_or_404() should resolve lazy objects passed in kwargs.
+        """
+        article = Article.objects.create(title='A lazy title')
+        lazy_title = SimpleLazyObject(lambda: 'A lazy title')
+        # Before the patch, this raises a DatabaseError because the query
+        # is made with a SimpleLazyObject.
+        retrieved_object = get_object_or_404(Article, title=lazy_title)
+        self.assertEqual(retrieved_object, article)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/views/generic/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 get_object_or_404.test_lazy_object_in_get_object_or_404
cat coverage.cover
git checkout 8954f255bbf5f4ee997fd6de62cb50fc9b5dd697
git apply /root/pre_state.patch
