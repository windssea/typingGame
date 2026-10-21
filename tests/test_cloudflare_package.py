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

    def test_streamed_manifest_keeps_game_packs_off_pages(self):
        import gzip
        import hashlib
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'source';source.mkdir()
            (source/'index.html').write_text('<script src="index.js"></script>')
            (source/'index.js').write_text('// fixture')
            (source/'index.wasm').write_bytes(b'engine')
            (source/'index.pck').write_bytes(b'bootstrap')
            pack=b'independent game payload'
            (source/'content-dojo.pck').write_bytes(pack)
            (source/'content-packs.json').write_text(json.dumps({'modes':{'dojo':['dojo']},'packs':{'dojo':{'file':'content-dojo.pck','bytes':len(pack)}}}))
            (source/'pack-plan.json').write_text('{}')
            output=Path(directory)/'release'
            subprocess.run([sys.executable,str(ROOT/'tools/prepare-cloudflare.py'),'--source',str(source),'--out',str(output),'--asset-base-url','https://assets.example'],check=True,stdout=subprocess.DEVNULL)
            manifest=json.loads((output/'manifest.json').read_text())
            self.assertEqual(len(manifest['objects']),3)
            self.assertFalse((output/'pages/content-dojo.pck').exists())
            self.assertFalse((output/'pages/pack-plan.json').exists())
            scripts=list((output/'pages').glob('content-manifest-*.js'))
            loaders=list((output/'pages').glob('content-packs-*.js'))
            self.assertEqual(len(scripts),1)
            self.assertEqual(len(loaders),1)
            runtime=scripts[0].read_text()
            self.assertIn(hashlib.sha256(pack).hexdigest(),runtime)
            self.assertIn(hashlib.sha256(b'bootstrap').hexdigest(),runtime)
            self.assertIn(hashlib.sha256(scripts[0].read_bytes()).hexdigest()[:16],scripts[0].name)
            html=(output/'pages/index.html').read_text()
            self.assertLess(html.index(scripts[0].name),html.index(loaders[0].name))
            self.assertLess(html.index(loaders[0].name),html.index('src="index.js"'))
            self.assertNotIn('src="content-manifest.js"',html)
            self.assertIn('window.keyboundBootstrapSHA',html)
            obj=next(item for item in manifest['objects'] if 'content-dojo-' in item['key'])
            self.assertEqual(gzip.decompress(Path(obj['file']).read_bytes()),pack)
            (source/'content-dojo.pck').write_bytes(pack+b'new native animation')
            revised=Path(directory)/'revised'
            subprocess.run([sys.executable,str(ROOT/'tools/prepare-cloudflare.py'),'--source',str(source),'--out',str(revised),'--asset-base-url','https://assets.example'],check=True,stdout=subprocess.DEVNULL)
            self.assertNotEqual(scripts[0].name,next((revised/'pages').glob('content-manifest-*.js')).name)


if __name__ == '__main__':
    unittest.main()
