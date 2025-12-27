#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e972620ada4f9ed7bc57f28e133e85c85b0a7b20 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e972620ada4f9ed7bc57f28e133e85c85b0a7b20
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_bulk_update_f_expression.py b/tests/queries/test_bulk_update_f_expression.py
new file mode 100644
index 0000000000..934cfd47ff
--- /dev/null
+++ b/tests/queries/test_bulk_update_f_expression.py
@@ -0,0 +1,24 @@
+import datetime
+
+from django.core.exceptions import FieldDoesNotExist
+from django.db.models import F
+from django.db.models.functions import Lower
+from django.test import TestCase, skipUnlessDBFeature
+
+from .models import (
+    Article, CustomDbColumn, CustomPk, Detail, Individual, JSONFieldNullable,
+    Member, Note, Number, Order, Paragraph, RelatedObject, SingleObject,
+    SpecialCategory, Tag, Valid,
+)
+
+
+class BulkUpdateTests(TestCase):
+    def test_update_with_plain_f_expression(self):
+        """
+        Test that bulk_update() works with plain F() expressions.
+        """
+        note = Note.objects.create(note='test-note', misc='test-misc')
+        note.misc = F('note')
+        Note.objects.bulk_update([note], ['misc'])
+        note.refresh_from_db()
+        self.assertEqual(note.misc, 'test-note')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_bulk_update_f_expression
cat coverage.cover
git checkout e972620ada4f9ed7bc57f28e133e85c85b0a7b20
git apply /root/pre_state.patch
