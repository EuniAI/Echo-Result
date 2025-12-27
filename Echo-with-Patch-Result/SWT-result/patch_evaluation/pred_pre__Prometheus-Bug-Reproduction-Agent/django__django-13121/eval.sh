#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ec5aa2161d8015a3fe57dcbbfe14200cd18f0a16 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ec5aa2161d8015a3fe57dcbbfe14200cd18f0a16
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/expressions/tests/test_durationfield_add.py b/expressions/tests/test_durationfield_add.py
new file mode 100644
index 0000000000..f7bc8b366c
--- /dev/null
+++ b/expressions/tests/test_durationfield_add.py
@@ -0,0 +1,129 @@
+import datetime
+import pickle
+import unittest
+import uuid
+from copy import deepcopy
+from unittest import mock
+
+from django.core.exceptions import FieldError
+from django.db import DatabaseError, NotSupportedError, connection
+from django.db.models import (
+    Avg, BooleanField, Case, CharField, Count, DateField, DateTimeField,
+    DurationField, Exists, Expression, ExpressionList, ExpressionWrapper, F,
+    Func, IntegerField, Max, Min, Model, OrderBy, OuterRef, Q, StdDev,
+    Subquery, Sum, TimeField, UUIDField, Value, Variance, When,
+)
+from django.db.models.expressions import Col, Combinable, Random, RawSQL, Ref
+from django.db.models.functions import (
+    Coalesce, Concat, Left, Length, Lower, Substr, Upper,
+)
+from django.db.models.sql import constants
+from django.db.models.sql.datastructures import Join
+from django.test import SimpleTestCase, TestCase, skipIf, skipUnlessDBFeature
+from django.test.utils import Approximate, isolate_apps
+from django.utils.functional import SimpleLazyObject
+
+from .models import (
+    UUID, UUIDPK, Company, Employee, Experiment, Manager, Number,
+    RemoteEmployee, Result, SimulationRun, Time,
+)
+
+
+class FTimeDeltaTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.sday = sday = datetime.date(2010, 6, 25)
+        cls.stime = stime = datetime.datetime(2010, 6, 25, 12, 15, 30, 747000)
+        midnight = datetime.time(0)
+
+        delta0 = datetime.timedelta(0)
+        delta1 = datetime.timedelta(microseconds=253000)
+        delta2 = datetime.timedelta(seconds=44)
+        delta3 = datetime.timedelta(hours=21, minutes=8)
+        delta4 = datetime.timedelta(days=10)
+        delta5 = datetime.timedelta(days=90)
+
+        # Test data is set so that deltas and delays will be
+        # strictly increasing.
+        cls.deltas = []
+        cls.delays = []
+        cls.days_long = []
+
+        # e0: started same day as assigned, zero duration
+        end = stime + delta0
+        cls.e0 = Experiment.objects.create(
+            name='e0', assigned=sday, start=stime, end=end,
+            completed=end.date(), estimated_time=delta0,
+        )
+        cls.deltas.append(delta0)
+        cls.delays.append(cls.e0.start - datetime.datetime.combine(cls.e0.assigned, midnight))
+        cls.days_long.append(cls.e0.completed - cls.e0.assigned)
+
+        # e1: started one day after assigned, tiny duration, data
+        # set so that end time has no fractional seconds, which
+        # tests an edge case on sqlite.
+        delay = datetime.timedelta(1)
+        end = stime + delay + delta1
+        e1 = Experiment.objects.create(
+            name='e1', assigned=sday, start=stime + delay, end=end,
+            completed=end.date(), estimated_time=delta1,
+        )
+        cls.deltas.append(delta1)
+        cls.delays.append(e1.start - datetime.datetime.combine(e1.assigned, midnight))
+        cls.days_long.append(e1.completed - e1.assigned)
+
+        # e2: started three days after assigned, small duration
+        end = stime + delta2
+        e2 = Experiment.objects.create(
+            name='e2', assigned=sday - datetime.timedelta(3), start=stime,
+            end=end, completed=end.date(), estimated_time=datetime.timedelta(hours=1),
+        )
+        cls.deltas.append(delta2)
+        cls.delays.append(e2.start - datetime.datetime.combine(e2.assigned, midnight))
+        cls.days_long.append(e2.completed - e2.assigned)
+
+        # e3: started four days after assigned, medium duration
+        delay = datetime.timedelta(4)
+        end = stime + delay + delta3
+        e3 = Experiment.objects.create(
+            name='e3', assigned=sday, start=stime + delay, end=end,
+            completed=end.date(), estimated_time=delta3,
+        )
+        cls.deltas.append(delta3)
+        cls.delays.append(e3.start - datetime.datetime.combine(e3.assigned, midnight))
+        cls.days_long.append(e3.completed - e3.assigned)
+
+        # e4: started 10 days after assignment, long duration
+        end = stime + delta4
+        e4 = Experiment.objects.create(
+            name='e4', assigned=sday - datetime.timedelta(10), start=stime,
+            end=end, completed=end.date(), estimated_time=delta4 - datetime.timedelta(1),
+        )
+        cls.deltas.append(delta4)
+        cls.delays.append(e4.start - datetime.datetime.combine(e4.assigned, midnight))
+        cls.days_long.append(e4.completed - e4.assigned)
+
+        # e5: started a month after assignment, very long duration
+        delay = datetime.timedelta(30)
+        end = stime + delay + delta5
+        e5 = Experiment.objects.create(
+            name='e5', assigned=sday, start=stime + delay, end=end,
+            completed=end.date(), estimated_time=delta5,
+        )
+        cls.deltas.append(delta5)
+        cls.delays.append(e5.start - datetime.datetime.combine(e5.assigned, midnight))
+        cls.days_long.append(e5.completed - e5.assigned)
+
+        cls.expnames = [e.name for e in Experiment.objects.all()]
+    
+    @skipIf(connection.features.has_native_duration_field,
+            "This test is for backends that don't support duration fields natively.")
+    def test_duration_field_and_timedelta_add(self):
+        # Test timedelta addition to a DurationField on backends without a
+        # native duration field.
+        delta = datetime.timedelta(days=1)
+        exp = Experiment.objects.annotate(
+            duration=F('estimated_time') + delta,
+        ).get(name='e0')
+        self.assertEqual(exp.duration, self.e0.estimated_time + delta)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py|django/db/backends/mysql/operations\.py|django/db/backends/base/operations\.py|django/db/backends/sqlite3/operations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 expressions.tests.test_durationfield_add
cat coverage.cover
git checkout ec5aa2161d8015a3fe57dcbbfe14200cd18f0a16
git apply /root/pre_state.patch
