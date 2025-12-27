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
diff --git a/tests/queries/test_q_combinatorics.py b/tests/queries/test_q_combinatorics.py
new file mode 100644
index 0000000000..093447bdee
--- /dev/null
+++ b/tests/queries/test_q_combinatorics.py
@@ -0,0 +1,121 @@
+from django.contrib.auth import get_user_model
+from django.db.models import Exists, F, Q
+from django.test import SimpleTestCase
+
+
+class QTests(SimpleTestCase):
+    def test_combine_and_empty(self):
+        q = Q(x=1)
+        self.assertEqual(q & Q(), q)
+        self.assertEqual(Q() & q, q)
+
+        q = Q(x__in={}.keys())
+        self.assertEqual(q & Q(), q)
+        self.assertEqual(Q() & q, q)
+
+    def test_combine_and_both_empty(self):
+        self.assertEqual(Q() & Q(), Q())
+
+    def test_combine_or_empty(self):
+        q = Q(x=1)
+        self.assertEqual(q | Q(), q)
+        self.assertEqual(Q() | q, q)
+
+        q = Q(x__in={}.keys())
+        self.assertEqual(q | Q(), q)
+        self.assertEqual(Q() | q, q)
+
+    def test_combine_or_both_empty(self):
+        self.assertEqual(Q() | Q(), Q())
+
+    def test_combine_not_q_object(self):
+        obj = object()
+        q = Q(x=1)
+        with self.assertRaisesMessage(TypeError, str(obj)):
+            q | obj
+        with self.assertRaisesMessage(TypeError, str(obj)):
+            q & obj
+
+    def test_deconstruct(self):
+        q = Q(price__gt=F('discounted_price'))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(path, 'django.db.models.Q')
+        self.assertEqual(args, ())
+        self.assertEqual(kwargs, {'price__gt': F('discounted_price')})
+
+    def test_deconstruct_negated(self):
+        q = ~Q(price__gt=F('discounted_price'))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(args, ())
+        self.assertEqual(kwargs, {
+            'price__gt': F('discounted_price'),
+            '_negated': True,
+        })
+
+    def test_deconstruct_or(self):
+        q1 = Q(price__gt=F('discounted_price'))
+        q2 = Q(price=F('discounted_price'))
+        q = q1 | q2
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(args, (
+            ('price__gt', F('discounted_price')),
+            ('price', F('discounted_price')),
+        ))
+        self.assertEqual(kwargs, {'_connector': 'OR'})
+
+    def test_deconstruct_and(self):
+        q1 = Q(price__gt=F('discounted_price'))
+        q2 = Q(price=F('discounted_price'))
+        q = q1 & q2
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(args, (
+            ('price__gt', F('discounted_price')),
+            ('price', F('discounted_price')),
+        ))
+        self.assertEqual(kwargs, {})
+
+    def test_deconstruct_multiple_kwargs(self):
+        q = Q(price__gt=F('discounted_price'), price=F('discounted_price'))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(args, (
+            ('price', F('discounted_price')),
+            ('price__gt', F('discounted_price')),
+        ))
+        self.assertEqual(kwargs, {})
+
+    def test_deconstruct_nested(self):
+        q = Q(Q(price__gt=F('discounted_price')))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(args, (Q(price__gt=F('discounted_price')),))
+        self.assertEqual(kwargs, {})
+
+    def test_reconstruct(self):
+        q = Q(price__gt=F('discounted_price'))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(Q(*args, **kwargs), q)
+
+    def test_reconstruct_negated(self):
+        q = ~Q(price__gt=F('discounted_price'))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(Q(*args, **kwargs), q)
+
+    def test_reconstruct_or(self):
+        q1 = Q(price__gt=F('discounted_price'))
+        q2 = Q(price=F('discounted_price'))
+        q = q1 | q2
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(Q(*args, **kwargs), q)
+
+    def test_reconstruct_and(self):
+        q1 = Q(price__gt=F('discounted_price'))
+        q2 = Q(price=F('discounted_price'))
+        q = q1 & q2
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(Q(*args, **kwargs), q)
+
+    def test_deconstruct_exists(self):
+        q = Q(Exists(get_user_model().objects.filter(username='jim')))
+        path, args, kwargs = q.deconstruct()
+        self.assertEqual(path, 'django.db.models.Q')
+        self.assertEqual(args, (Exists(get_user_model().objects.filter(username='jim')),))
+        self.assertEqual(kwargs, {})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_q_combinatorics
cat coverage.cover
git checkout 45814af6197cfd8f4dc72ee43b90ecde305a1d5a
git apply /root/pre_state.patch
