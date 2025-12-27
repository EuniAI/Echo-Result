#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2d67222472f80f251607ae1b720527afceba06ad >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2d67222472f80f251607ae1b720527afceba06ad
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/expressions/test_temporal.py b/tests/expressions/test_temporal.py
new file mode 100644
index 0000000000..71632b1801
--- /dev/null
+++ b/tests/expressions/test_temporal.py
@@ -0,0 +1,22 @@
+import datetime
+
+from django.db.models import DurationField, F, Value
+from django.test import TestCase
+
+from .models import Experiment
+
+
+class TemporalExpressionsTests(TestCase):
+    def test_temporal_subtraction_with_timedelta_value(self):
+        """
+        A FieldError should not be raised when adding a timedelta to a
+        subtraction of two DateTimeFields.
+        """
+        # The FieldError is raised during query compilation, so no data is
+        # needed in the database.
+        qs = Experiment.objects.annotate(
+            delta=F('end') - F('start') + Value(datetime.timedelta(), output_field=DurationField())
+        )
+        # Compiling the query by calling str() will raise the FieldError.
+        # A successful compilation indicates that the bug is fixed.
+        str(qs.query)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.test_temporal
cat coverage.cover
git checkout 2d67222472f80f251607ae1b720527afceba06ad
git apply /root/pre_state.patch
