#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 45814af6197cfd8f4dc72ee43b90ecde305a1d5a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 45814af6197cfd8f4dc72ee43b90ecde305a1d5a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/query_utils.py b/django/db/models/query_utils.py
--- a/django/db/models/query_utils.py
+++ b/django/db/models/query_utils.py
@@ -84,14 +84,10 @@ def deconstruct(self):
         path = '%s.%s' % (self.__class__.__module__, self.__class__.__name__)
         if path.startswith('django.db.models.query_utils'):
             path = path.replace('django.db.models.query_utils', 'django.db.models')
-        args, kwargs = (), {}
-        if len(self.children) == 1 and not isinstance(self.children[0], Q):
-            child = self.children[0]
-            kwargs = {child[0]: child[1]}
-        else:
-            args = tuple(self.children)
-            if self.connector != self.default:
-                kwargs = {'_connector': self.connector}
+        args = tuple(self.children)
+        kwargs = {}
+        if self.connector != self.default:
+            kwargs['_connector'] = self.connector
         if self.negated:
             kwargs['_negated'] = True
         return path, args, kwargs

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_q_deconstruct.py b/tests/test_q_deconstruct.py
new file mode 100644
index 0000000000..b24eae676e
--- /dev/null
+++ b/tests/test_q_deconstruct.py
@@ -0,0 +1,20 @@
+from django.db.models import F, Q
+from django.test import SimpleTestCase
+
+
+class QDeconstructTests(SimpleTestCase):
+    def test_deconstruct_expression_child(self):
+        """
+        Q.deconstruct() should handle non-subscriptable children like
+        expressions.
+        """
+        # F() is an expression that is not subscriptable.
+        expression = F('foo')
+        q = Q(expression)
+        # Before the patch, this line raises a TypeError because deconstruct
+        # attempts to use integer indices on the expression object.
+        path, args, kwargs = q.deconstruct()
+        # After the patch, the expression should be in args.
+        self.assertEqual(path, 'django.db.models.Q')
+        self.assertEqual(args, (expression,))
+        self.assertEqual(kwargs, {})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_q_deconstruct
cat coverage.cover
git checkout 45814af6197cfd8f4dc72ee43b90ecde305a1d5a
git apply /root/pre_state.patch
