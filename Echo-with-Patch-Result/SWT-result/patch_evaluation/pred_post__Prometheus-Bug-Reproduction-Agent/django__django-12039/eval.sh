#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 58c1acb1d6054dfec29d0f30b1033bae6ef62aec >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 58c1acb1d6054dfec29d0f30b1033bae6ef62aec
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/backends/ddl_references.py b/django/db/backends/ddl_references.py
--- a/django/db/backends/ddl_references.py
+++ b/django/db/backends/ddl_references.py
@@ -83,10 +83,14 @@ def __init__(self, table, columns, quote_name, col_suffixes=()):
 
     def __str__(self):
         def col_str(column, idx):
+            col = self.quote_name(column)
             try:
-                return self.quote_name(column) + self.col_suffixes[idx]
+                suffix = self.col_suffixes[idx]
+                if suffix:
+                    col = '{} {}'.format(col, suffix)
             except IndexError:
-                return self.quote_name(column)
+                pass
+            return col
 
         return ', '.join(col_str(column, idx) for idx, column in enumerate(self.columns))
 
@@ -114,7 +118,9 @@ def col_str(column, idx):
             # length as self.columns.
             col = '{} {}'.format(self.quote_name(column), self.opclasses[idx])
             try:
-                col = '{} {}'.format(col, self.col_suffixes[idx])
+                suffix = self.col_suffixes[idx]
+                if suffix:
+                    col = '{} {}'.format(col, suffix)
             except IndexError:
                 pass
             return col

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ddl_references/test_whitespace.py b/tests/ddl_references/test_whitespace.py
new file mode 100644
index 0000000000..475a4e66b4
--- /dev/null
+++ b/tests/ddl_references/test_whitespace.py
@@ -0,0 +1,23 @@
+from django.db.backends.ddl_references import Columns, IndexColumns
+from django.test import SimpleTestCase
+
+
+class DDLReferencesWhitespaceTests(SimpleTestCase):
+    def test_column_suffixes(self):
+        """
+        Tests that whitespace is handled correctly for column suffixes in index
+        definitions.
+        """
+        # A space should be added before the DESC suffix.
+        reference = Columns('table', ['name'], lambda c: f'"{c}"', col_suffixes=['DESC'])
+        self.assertEqual(str(reference), '"name" DESC')
+
+        # No trailing space should be added for opclasses without a suffix.
+        reference = IndexColumns(
+            'table',
+            ['name'],
+            lambda c: f'"{c}"',
+            opclasses=['text_pattern_ops'],
+            col_suffixes=[''],
+        )
+        self.assertEqual(str(reference), '"name" text_pattern_ops')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/ddl_references\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 ddl_references.test_whitespace
cat coverage.cover
git checkout 58c1acb1d6054dfec29d0f30b1033bae6ef62aec
git apply /root/pre_state.patch
