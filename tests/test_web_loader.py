"""Protect shell upgrades, repeated exports, and existing R2 resource mappings."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = '''<!doctype html><html lang="en"><head><title>Godot</title>EXTRA</head><body>
<canvas id="canvas"></canvas><div id="status"><img id="status-splash" src="index.png">
<progress id="status-progress"></progress><div id="status-notice"></div></div>
<script>const assets={pck:'https://assets.example/game-verified.pck'};</script>
<script src="index.js"></script><script>const GODOT_CONFIG={fileSizes:{'index.pck':125776632}};</script>
</body></html>'''


class WebLoaderTests(unittest.TestCase):
    def prepare(self, path):
        executable = shutil.which('pwsh') or shutil.which('powershell')
        if not executable:
            self.skipTest('PowerShell is required to run the export preparation script')
        subprocess.run([executable, '-NoProfile', '-File', str(ROOT/'tools/prepare-web.ps1'),
                        '-Path', str(path)], check=True, capture_output=True)

    def test_repeat_preparation_preserves_engine_and_r2(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'index.html'
            path.write_text(SHELL.replace('EXTRA', ''), encoding='utf-8')
            self.prepare(path)
            first = path.read_text(encoding='utf-8')
            self.prepare(path)
            self.assertEqual(first, path.read_text(encoding='utf-8'))
            self.assertEqual(first.count('id="status"'), 1)
            self.assertEqual(first.count('id="status-progress"'), 1)
            self.assertEqual(first.count('src="loading-v191.js"'), 1)
            self.assertIn('https://assets.example/game-verified.pck', first)
            self.assertIn("'index.pck':125776632", first)
            for name in ['loading-v191.css','loading-v191.js','loading-robot-v191.webp','loading-knight-v191.webp']:
                self.assertTrue((path.parent/name).is_file())

    def test_upgrade_removes_old_conflicting_styles_and_title_script(self):
        legacy = '<style>body { background:#f4f9fd; } #status-progress {left:35%;right:0;}</style><script>const publicTitle="old";</script>'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'index.html'
            path.write_text(SHELL.replace('EXTRA', legacy), encoding='utf-8')
            self.prepare(path)
            text = path.read_text(encoding='utf-8')
            self.assertNotIn('left:35%', text)
            self.assertNotIn('const publicTitle=', text)
            self.assertIn('<html lang="zh-CN">', text)
            self.assertIn('和机器人打招呼', text)

    def test_unsupported_shell_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'index.html'
            path.write_text('<html>unrelated page</html>', encoding='utf-8')
            with self.assertRaises(subprocess.CalledProcessError):
                self.prepare(path)
            self.assertEqual(path.read_text(), '<html>unrelated page</html>')


if __name__ == '__main__':
    unittest.main()
