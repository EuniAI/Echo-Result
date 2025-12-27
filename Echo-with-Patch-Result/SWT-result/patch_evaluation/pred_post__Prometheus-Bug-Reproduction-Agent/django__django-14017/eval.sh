#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 466920f6d726eee90d5566e0a9948e92b33a122e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 466920f6d726eee90d5566e0a9948e92b33a122e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/query_utils.py b/django/db/models/query_utils.py
--- a/django/db/models/query_utils.py
+++ b/django/db/models/query_utils.py
@@ -40,7 +40,7 @@ def __init__(self, *args, _connector=None, _negated=False, **kwargs):
         super().__init__(children=[*args, *sorted(kwargs.items())], connector=_connector, negated=_negated)
 
     def _combine(self, other, conn):
-        if not isinstance(other, Q):
+        if not(isinstance(other, Q) or getattr(other, 'conditional', False) is True):
             raise TypeError(other)
 
         # If the other Q() is empty, ignore it and just use `self`.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_q_exists_interaction.py b/tests/test_q_exists_interaction.py
new file mode 100644
index 0000000000..76a64a677b
--- /dev/null
+++ b/tests/test_q_exists_interaction.py
@@ -0,0 +1,24 @@
+from unittest.mock import Mock
+
+from django.db.models import Exists, Q
+from django.db.models.query import QuerySet
+from django.test import SimpleTestCase
+
+
+class QExistsInteractionTests(SimpleTestCase):
+    def test_q_and_exists(self):
+        """
+        Tests that Q() & Exists(...) does not raise a TypeError.
+        """
+        # A mock QuerySet is sufficient since we are only testing the
+        # ability to construct the expression tree, not to execute it.
+        # This avoids any database interaction and the associated setup issues.
+        mock_queryset = Mock(spec=QuerySet)
+
+        # This is the operation that raises a TypeError on the unpatched code.
+        # The patched code correctly wraps the Exists object in a Q object.
+        q_expression = Q() & Exists(mock_queryset)
+
+        # The assertion simply checks that the operation returns a Q object,
+        # which it will if the TypeError is no longer raised.
+        self.assertIsInstance(q_expression, Q)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query_utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_q_exists_interaction
cat coverage.cover
git checkout 466920f6d726eee90d5566e0a9948e92b33a122e
git apply /root/pre_state.patch
