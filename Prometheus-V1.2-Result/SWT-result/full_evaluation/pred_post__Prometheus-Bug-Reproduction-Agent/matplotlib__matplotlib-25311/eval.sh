#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 430fb1db88843300fb4baae3edc499bbfe073b0c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 430fb1db88843300fb4baae3edc499bbfe073b0c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/offsetbox.py b/lib/matplotlib/offsetbox.py
--- a/lib/matplotlib/offsetbox.py
+++ b/lib/matplotlib/offsetbox.py
@@ -1505,7 +1505,6 @@ def __init__(self, ref_artist, use_blit=False):
         if not ref_artist.pickable():
             ref_artist.set_picker(True)
         self.got_artist = False
-        self.canvas = self.ref_artist.figure.canvas
         self._use_blit = use_blit and self.canvas.supports_blit
         self.cids = [
             self.canvas.callbacks._connect_picklable(
@@ -1514,6 +1513,9 @@ def __init__(self, ref_artist, use_blit=False):
                 'button_release_event', self.on_release),
         ]
 
+    # A property, not an attribute, to maintain picklability.
+    canvas = property(lambda self: self.ref_artist.figure.canvas)
+
     def on_motion(self, evt):
         if self._check_still_parented() and self.got_artist:
             dx = evt.x - self.mouse_x

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_pickle_draggable_legend.py b/lib/matplotlib/tests/test_pickle_draggable_legend.py
new file mode 100644
index 0000000000..f27cbd05e7
--- /dev/null
+++ b/lib/matplotlib/tests/test_pickle_draggable_legend.py
@@ -0,0 +1,50 @@
+import pickle
+from io import BytesIO
+import matplotlib.pyplot as plt
+from matplotlib.cbook import CallbackRegistry
+
+def test_pickle_draggable_legend():
+    """
+    A figure with a draggable legend should be picklable even on backends with
+    unpicklable canvases.
+
+    This test simulates an interactive backend by using a mock canvas that is
+    not picklable. The bug is that DraggableLegend holds a reference to the
+    canvas, making the Figure unpicklable on interactive backends.
+    """
+
+    # This mock canvas has just enough attributes to get past the setup
+    # and Figure's own __getstate__ method.
+    class UnpicklableCanvas:
+        def __init__(self, figure):
+            self.figure = figure
+            # Needed for leg.set_draggable() to connect events.
+            self.callbacks = CallbackRegistry()
+            # Needed for Figure.__getstate__() to run without error.
+            self.manager = None
+
+        def mpl_connect(self, s, func):
+            return self.callbacks.connect(s, func)
+
+        # This method makes the canvas unpicklable, simulating a real GUI
+        # canvas. When pickle tries to get the state of this object, it
+        # will raise the TypeError, reproducing the bug.
+        def __getstate__(self):
+            raise TypeError(f"cannot pickle '{type(self).__name__}' object")
+
+    # Use the code from the bug report.
+    fig = plt.figure()
+    # Replace the default, picklable 'Agg' canvas with our mock.
+    fig.canvas = UnpicklableCanvas(fig)
+
+    ax = fig.add_subplot(111)
+    ax.plot([0, 1, 2, 3, 4], [40, 43, 45, 47, 48], label="speed")
+
+    leg = ax.legend()
+    # This call should now succeed.
+    leg.set_draggable(True)
+
+    # This is where the TypeError should be raised. The pickling process will
+    # traverse from the Figure to the Legend, and then to the unpicklable
+    # canvas reference held by the DraggableLegend helper object.
+    pickle.dump(fig, BytesIO())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/offsetbox\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_pickle_draggable_legend.py
cat coverage.cover
git checkout 430fb1db88843300fb4baae3edc499bbfe073b0c
git apply /root/pre_state.patch
