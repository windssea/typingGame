"""Protect custom-domain CORS when producing subsequent release packages."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CloudflareCorsTests(unittest.TestCase):
    def package(self, page_origin):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source'
            source.mkdir()
            (source / 'index.html').write_text('<script src="index.js"></script>')
            (source / 'index.js').write_text('// fixture')
            (source / 'index.wasm').write_bytes(b'wasm-fixture')
            (source / 'index.pck').write_bytes(b'game-fixture')
            output = Path(directory) / 'release'
            subprocess.run([
                sys.executable, str(ROOT / 'tools/prepare-cloudflare.py'),
                '--source', str(source), '--out', str(output),
                '--asset-base-url', 'https://assets.example',
                '--page-origin', page_origin,
            ], check=True, stdout=subprocess.DEVNULL)
            return json.loads((output / 'cors.json').read_text())

    def test_release_preserves_custom_domain(self):
        policy = self.package('https://typinggame-cl5.pages.dev')
        origins = policy['rules'][0]['allowed']['origins']
        self.assertIn('https://typing.nanokid.win', origins)
        self.assertIn('https://typinggame-cl5.pages.dev', origins)
        self.assertNotIn('*', origins)
        self.assertEqual(len(origins), len(set(origins)))

    def test_preview_adds_origin_without_removing_production(self):
        policy = self.package('https://preview.typinggame-cl5.pages.dev')
        origins = policy['rules'][0]['allowed']['origins']
        self.assertIn('https://preview.typinggame-cl5.pages.dev', origins)
        self.assertIn('https://typing.nanokid.win', origins)
        self.assertIn('https://typinggame-cl5.pages.dev', origins)


if __name__ == '__main__':
    unittest.main()
