"""SOCKS5 routing regression tests. Optional: SING_BOX_BIN / XRAY_BIN for real-core checks."""
import contextlib
import http.server
import json
import os
from pathlib import Path
import shutil
import shlex
import socket
import socketserver
import struct
import subprocess
import tempfile
import threading
import time
import unittest

REPO = Path(__file__).resolve().parents[1]
SB = os.environ.get('SING_BOX_BIN') or shutil.which('sing-box')
XR = os.environ.get('XRAY_BIN') or shutil.which('xray')


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


def port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def recv_exact(sock, size):
    data = b''
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise EOFError()
        data += chunk
    return data


class SocksHandler(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            version, count = recv_exact(self.request, 2)
            if version != 5:
                return
            recv_exact(self.request, count)
            self.request.sendall(b'\x05\x00')
            _, command, _, kind = recv_exact(self.request, 4)
            if kind == 1:
                host = socket.inet_ntoa(recv_exact(self.request, 4))
            elif kind == 3:
                host = recv_exact(self.request, recv_exact(self.request, 1)[0]).decode()
            elif kind == 4:
                host = socket.inet_ntop(socket.AF_INET6, recv_exact(self.request, 16))
            else:
                return
            target_port = struct.unpack('!H', recv_exact(self.request, 2))[0]
            if command != 1:
                return
            with socket.create_connection((host, target_port), timeout=5) as remote:
                self.server.hits.append((host, target_port))
                self.request.sendall(b'\x05\x00\x00\x01\x7f\x00\x00\x01\x00\x00')
                import select
                while True:
                    readable, _, _ = select.select([self.request, remote], [], [], 5)
                    if not readable:
                        return
                    for source in readable:
                        data = source.recv(65536)
                        if not data:
                            return
                        (remote if source is self.request else self.request).sendall(data)
        except (EOFError, OSError):
            return


class SocksServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


class HttpHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'route-ok'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


class Fixture:
    def __init__(self, parent, cores=('sing-box', 'xray')):
        self.root = Path(parent) / 'agent'
        self.cores = cores
        self.state = self.root / 'socks5'
        self.ports = {}
        self.engine = Path(parent) / 'engine.sh'
        text = (REPO / 'install.sh').read_text()
        text = text[text.index('# SOCKS5 outbound state, compiler'):]
        text = text[:text.index('# End SOCKS5 outbound implementation')]
        self.engine.write_text(text)
        for core in cores:
            binary = SB if core == 'sing-box' else XR
            folder = self.root / core
            folder.mkdir(parents=True)
            (folder / core).symlink_to(binary or '/usr/bin/true')
            cfg = folder / 'conf' / ('config' if core == 'sing-box' else '')
            self.ports[core] = [port(), port()]
            if core == 'sing-box':
                write(cfg / 'custom-protocol.json', {
                    'log': {'level': 'error'},
                    'inbounds': [{'type': 'socks', 'tag': tag, 'listen': '127.0.0.1', 'listen_port': p}
                                 for tag, p in zip(['in-a', 'in-b'], self.ports[core])],
                    'outbounds': [{'type': 'direct', 'tag': 'direct'}],
                    'route': {'rules': [{'domain_suffix': ['direct.test'], 'outbound': 'direct'}]}})
            else:
                write(cfg / 'custom-protocol.json', {
                    'log': {'loglevel': 'none'},
                    'inbounds': [{'protocol': 'socks', 'tag': tag, 'listen': '127.0.0.1', 'port': p,
                                  'settings': {'auth': 'noauth', 'udp': True}}
                                 for tag, p in zip(['in-a', 'in-b'], self.ports[core])],
                    'outbounds': [{'protocol': 'freedom', 'tag': 'direct'}]})
                write(cfg / '09_routing.json', {'routing': {'domainStrategy': 'AsIs', 'rules': [
                    {'type': 'field', 'domain': ['domain:direct.test'], 'outboundTag': 'direct'}]}})
        self.state.mkdir(parents=True)
        self.nodes = {'version': 1, 'nodes': [self.node('a'), self.node('b'), self.node('c')]}
        self.routes = {'version': 1, 'routes': [], 'defaults': {'sing-box': None, 'xray': None}}
        self.save()

    def config(self, core):
        return self.root / core / 'conf' / ('config' if core == 'sing-box' else '')

    @staticmethod
    def node(id_, p=1080):
        return {'id': id_, 'name': id_, 'server': '127.0.0.1', 'server_port': p,
                'username': '', 'password': '', 'enabled': True,
                'core_tags': {'sing-box': 'socks5_' + id_, 'xray': 'socks5_' + id_}}

    @staticmethod
    def route(core, scope='all', id_='r1', tags=None, domains=None, ips=None, node='a', priority=100):
        return {'id': id_, 'core': core, 'scope': scope, 'inbound_tags': tags or (['in-a'] if scope != 'target_only' else []),
                'domains': domains or [], 'rule_sets': [], 'ip_cidrs': ips or [],
                'outbound_node': node, 'priority': priority, 'enabled': True}

    def save(self):
        write(self.state / 'outbounds.json', self.nodes)
        write(self.state / 'routes.json', self.routes)

    def run(self, command, check=True, extra=''):
        result = subprocess.run(['bash', '-c', 'source "$1"; socks5OutboundRoot=$2; '
                                 'socks5OutboundReload(){ return 0; }; ' + extra + command,
                                 '_', str(self.engine), str(self.root)], text=True, capture_output=True)
        if check and result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result

    def stage(self):
        self.save()
        work = self.root / 'stage'
        work.mkdir(exist_ok=True)
        for group, src in [('state', self.state), ('before', self.state)] + [
                ('sb' if c == 'sing-box' else 'xr', self.config(c)) for c in self.cores]:
            dst = work / group
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns('.transaction*', 'backup', '.lock'))
        self.run('socks5OutboundPaths; socks5OutboundValidate "$s5State"; '
                 'socks5OutboundStage "$s5Root/stage"')
        return work


class StateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.f = Fixture(self.temp.name)

    def test_dynamic_tags_use_contents_and_separate_cores(self):
        cfg = self.f.config('sing-box')
        write(cfg / 'new.json', {'inbounds': [{'type': 'socks', 'tag': 'new-tag', 'listen_port': 5}]})
        write(cfg / 'config.json', {'inbounds': [{'tag': 'merged-must-not-appear'}]})
        (cfg / 'invalid.json').write_text('not JSON')
        result = self.f.run('socks5InboundTagList sing-box')
        self.assertIn('new-tag', result.stdout)
        self.assertNotIn('merged-must-not-appear', result.stdout)
        self.assertIn('invalid.json', result.stderr)
        self.assertNotIn('invalid.json', result.stdout)

    def test_compilers_expand_or_and_keep_tags_and_credentials(self):
        self.f.nodes['nodes'][0].update(username='u"\\$', password='p"\\$\n')
        self.f.routes['routes'] = [Fixture.route(core, 'match', core, tags=['in-a', 'in-b'],
                                                domains=['example.com'], ips=['192.0.2.0/24'])
                                   for core in self.f.cores]
        self.f.save()
        for core in self.f.cores:
            result = self.f.run('socks5OutboundBuild ' + core + ' "$socks5OutboundRoot/socks5" true')
            compiled = json.loads(result.stdout)
            self.assertEqual(3, len(compiled['outbounds']))
            self.assertEqual(2, len(compiled['rules']))
            for rule in compiled['rules']:
                self.assertEqual(['in-a', 'in-b'], rule['inbound'] if core == 'sing-box' else rule['inboundTag'])
                self.assertFalse(('domain' in rule or 'domain_suffix' in rule) and ('ip' in rule or 'ip_cidr' in rule))

    def test_shadowing_and_dangling_references_rejected(self):
        for routes in [
            [Fixture.route('sing-box'), Fixture.route('sing-box', 'match', 'r2', domains=['x.test'], priority=101)],
            [Fixture.route('xray', node='missing')],
            [Fixture.route('sing-box', tags=['missing'])],
            [Fixture.route('xray'), Fixture.route('xray', id_='r2')],
        ]:
            self.f.routes['routes'] = routes
            self.f.save()
            self.assertNotEqual(0, self.f.run('socks5OutboundPaths; socks5OutboundValidate "$s5State"', check=False).returncode)

    def test_english_engine_has_same_logic(self):
        def block(path):
            text = path.read_text()
            return text[text.index('# SOCKS5 outbound state, compiler'):text.index('# End SOCKS5 outbound implementation')]
        self.assertEqual(block(REPO / 'install.sh').replace("printf '%s' cn", "printf '%s' en", 1),
                         block(REPO / 'shell/install_en.sh'))

    def test_rule_set_inputs_and_legacy_singbox_syntax(self):
        result = self.f.run('getDLCGeositeName(){ [[ "$2" == "$socks5OutboundRoot/sing-box" ]] && printf netflix; }; '
                            'socks5OutboundParseTargets "netflix,geosite:cn,full:example.com,192.0.2.0/24" sing-box')
        parsed = json.loads(result.stdout)
        self.assertEqual(['cn', 'netflix'], parsed['rule_sets'])
        self.f.routes['routes'] = [Fixture.route('sing-box')]
        self.f.save()
        result = self.f.run('socks5OutboundBuild sing-box "$socks5OutboundRoot/socks5" false')
        self.assertNotIn('action', json.loads(result.stdout)['rules'][0])


@unittest.skipUnless(SB and XR, 'Set SING_BOX_BIN and XRAY_BIN to validate with both real cores')
class CoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.f = Fixture(self.temp.name)

    def test_real_core_stage_and_default_order(self):
        for core in self.f.cores:
            self.f.routes['routes'] += [Fixture.route(core, 'all', core + '-all'),
                                        Fixture.route(core, 'match', core + '-match', domains=['example.test'], priority=10, node='b')]
        work = self.f.stage()
        sb = json.loads((work / 'sing-box.json').read_text())
        self.assertEqual('direct', sb['outbounds'][0]['tag'])
        rules = sb['route']['rules']
        self.assertEqual('socks5_b', rules[0]['outbound'])
        self.assertEqual('socks5_a', rules[1]['outbound'])
        dump = subprocess.run([XR, 'run', '-dump', '-confdir', str(work / 'xr')], capture_output=True, text=True, check=True)
        xr = json.loads(dump.stdout)
        self.assertEqual('direct', xr['outbounds'][0]['tag'])
        self.assertEqual('socks5_b', xr['routing']['rules'][0]['outboundTag'])
        self.assertEqual('socks5_a', xr['routing']['rules'][1]['outboundTag'])

    def test_global_default_is_explicit_and_can_be_cleared(self):
        for core in self.f.cores:
            self.f.routes['defaults'][core] = 'c'
        work = self.f.stage()
        sb = json.loads((work / 'sing-box.json').read_text())
        self.assertEqual('socks5_c', sb['route']['final'])
        xr = json.loads((work / 'xr' / 'zz_socks5_routes.json').read_text())
        self.assertEqual('socks5_c', xr['routing']['rules'][-1]['outboundTag'])
        self.assertEqual('tcp,udp', xr['routing']['rules'][-1]['network'])
        for core in self.f.cores:
            self.f.routes['defaults'][core] = None
        work = self.f.stage()
        self.assertNotIn('final', json.loads((work / 'sing-box.json').read_text())['route'])
        xr = json.loads((work / 'xr' / 'zz_socks5_routes.json').read_text())
        self.assertFalse(any(r.get('outboundTag') == 'socks5_c' for r in xr['routing']['rules']))

    def test_core_validation_failure_does_not_publish(self):
        before = {str(p): p.read_bytes() for p in self.f.root.rglob('*.json')}
        bad = Fixture.route('xray', 'match', ips=['192.0.2.1/99'])
        # Input is outside the runtime root; it must not become a core config fragment.
        desired = Path(self.temp.name) / 'bad-route.json'
        write(desired, bad)
        result = self.f.run('socks5OutboundTransaction socks5OutboundSaveRoute '
                            + shlex.quote(json.dumps(bad)), check=False)
        self.assertNotEqual(0, result.returncode)
        after = {str(p): p.read_bytes() for p in self.f.root.rglob('*.json')}
        self.assertEqual(before, after)
        self.assertFalse((self.f.state / '.lock').exists())

    def test_uninstall_preserves_foreign_config(self):
        self.f.routes['routes'] = [Fixture.route('sing-box'), Fixture.route('xray', id_='xr')]
        self.f.save()
        before = {str(p): p.read_bytes() for core in self.f.cores for p in self.f.config(core).glob('*.json')}
        self.f.run('socks5OutboundTransaction socks5OutboundSetDefault xray c')
        self.f.run('socks5OutboundTransaction socks5OutboundEmpty')
        for path, data in before.items():
            self.assertEqual(data, Path(path).read_bytes())
        self.assertEqual([], json.loads((self.f.state / 'outbounds.json').read_text())['nodes'])
        for core in self.f.cores:
            config = json.loads((self.f.config(core) / 'zz_socks5_outbounds_tail.json').read_text())
            self.assertEqual([], config['outbounds'])

    def test_pure_core_transactions_and_referenced_node_toggle(self):
        for core in ('sing-box', 'xray'):
            with tempfile.TemporaryDirectory() as temp:
                fixture = Fixture(temp, (core,))
                fixture.routes['routes'] = [Fixture.route(core)]
                fixture.save()
                fixture.run('socks5OutboundTransaction socks5OutboundSetDefault ' + core + ' b')
                self.assertNotEqual(0, fixture.run('socks5OutboundTransaction socks5OutboundToggle node a', check=False).returncode)
                fixture.run('socks5OutboundTransaction socks5OutboundToggle route r1')
                fixture.run('socks5OutboundTransaction socks5OutboundToggle node a')
                nodes = json.loads((fixture.state / 'outbounds.json').read_text())['nodes']
                self.assertFalse(next(n for n in nodes if n['id'] == 'a')['enabled'])

    def test_xray_custom_blackhole_tag_precedes_selected_all(self):
        cfg = self.f.config('xray')
        write(cfg / 'deny.json', {'outbounds': [{'protocol': 'blackhole', 'tag': 'custom-deny'}]})
        write(cfg / '09_routing.json', {'routing': {'rules': [
            {'type': 'field', 'ip': ['192.0.2.0/24'], 'outboundTag': 'custom-deny'}]}})
        self.f.routes['routes'] = [Fixture.route('xray')]
        work = self.f.stage()
        rules = json.loads((work / 'xr' / 'zz_socks5_routes.json').read_text())['routing']['rules']
        self.assertEqual('custom-deny', rules[0]['outboundTag'])
        self.assertEqual('socks5_a', rules[1]['outboundTag'])

    def test_singbox_reject_blocks_traffic_before_socks5_with_and_without_guard(self):
        for use_guard in (False, True):
            with self.subTest(standalone_guard=use_guard), tempfile.TemporaryDirectory() as temp, contextlib.ExitStack() as stack:
                fixture = Fixture(temp, ('sing-box',))
                upstream = stack.enter_context(SocksServer(('127.0.0.1', 0), SocksHandler))
                upstream.hits = []
                threading.Thread(target=upstream.serve_forever, daemon=True).start()
                stack.callback(upstream.shutdown)
                http_server = stack.enter_context(http.server.ThreadingHTTPServer(('127.0.0.1', 0), HttpHandler))
                threading.Thread(target=http_server.serve_forever, daemon=True).start()
                stack.callback(http_server.shutdown)
                fixture.nodes['nodes'][0]['server_port'] = upstream.server_address[1]
                tag = 'socks5_inbound' if use_guard else 'in-a'
                fixture.routes['routes'] = [Fixture.route('sing-box', tags=[tag])]
                cfg = fixture.config('sing-box')
                write(cfg / 'blacklist.json', {'route': {'rules': [
                    {'domain': ['localhost'], 'action': 'reject'}]}})
                if use_guard:
                    inbound = json.loads((cfg / 'custom-protocol.json').read_text())
                    inbound['inbounds'][0]['tag'] = tag
                    write(cfg / 'custom-protocol.json', inbound)
                    write(cfg / '01_direct_outbound.json', {'outbounds': [
                        {'type': 'direct', 'tag': '01_direct_outbound'}]})
                    write(cfg / '00_socks5_guard.json', {'route': {'rules': [
                        {'type': 'logical', 'mode': 'and', 'rules': [
                            {'inbound': [tag]}, {'source_ip_cidr': ['127.0.0.1/32'], 'invert': True}],
                         'action': 'reject'},
                        {'inbound': [tag], 'source_ip_cidr': ['127.0.0.1/32'], 'outbound': '01_direct_outbound'},
                        {'inbound': [tag], 'action': 'reject'}]}})
                work = fixture.stage()
                if use_guard:
                    source = (REPO / 'install.sh').read_text()
                    start = source.index('checkSocks5Candidate() {')
                    end = source.index('# Install, replace rules, and uninstall', start)
                    with fixture.engine.open('a') as engine:
                        engine.write(source[start:end].replace('/etc/v2ray-agent', str(fixture.root)))
                    # Rule edits must still accept an existing blacklist before the inbound guard.
                    fixture.run('checkSocks5Candidate "$socks5OutboundRoot/stage/sb" '
                                '"$socks5OutboundRoot/checked.json"')
                process = subprocess.Popen([SB, 'run', '-c', str(work / 'sing-box.json')],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                def stop():
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=5)
                stack.callback(stop)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    try:
                        with socket.create_connection(('127.0.0.1', fixture.ports['sing-box'][0]), timeout=.1):
                            break
                    except OSError:
                        time.sleep(.05)
                self.assertIsNone(process.poll(), 'sing-box exited before listening')
                command = ['curl', '--silent', '--show-error', '--fail', '--max-time', '3', '--noproxy', '',
                           '--socks5-hostname', '127.0.0.1:' + str(fixture.ports['sing-box'][0])]
                allowed = subprocess.run(command + ['http://127.0.0.1:' + str(http_server.server_address[1])],
                                         text=True, capture_output=True)
                self.assertEqual(0, allowed.returncode, allowed.stderr)
                self.assertEqual('route-ok', allowed.stdout)
                self.assertEqual(1, len(upstream.hits))
                denied = subprocess.run(command + ['http://localhost:' + str(http_server.server_address[1])],
                                        text=True, capture_output=True)
                self.assertNotEqual(0, denied.returncode)
                self.assertEqual(1, len(upstream.hits), 'blacklisted traffic reached the SOCKS5 upstream')

    def test_transaction_rollback_after_second_core_reload_failure(self):
        self.f.routes['routes'] = [Fixture.route('sing-box')]
        self.f.save()
        before = {str(p): p.read_bytes() for p in self.f.root.rglob('*.json')}
        result = self.f.run('socks5OutboundTransaction socks5OutboundSetDefault xray b', check=False,
                            extra='socks5OutboundReload(){ if [[ "$1" == xray && ! -e "$s5Root/failed" ]]; then touch "$s5Root/failed"; return 1; fi; return 0; }; ')
        self.assertNotEqual(0, result.returncode)
        after = {str(p): p.read_bytes() for p in self.f.root.rglob('*.json')}
        self.assertEqual(before, after)
        self.assertFalse((self.f.state / '.lock').exists())

    def test_guard_preserved_with_injected_intersection(self):
        cfg = self.f.config('sing-box')
        guard = {'route': {'rules': [
            {'type': 'logical', 'mode': 'and', 'rules': [
                {'inbound': ['in-a']}, {'source_ip_cidr': ['127.0.0.1/32'], 'invert': True}], 'action': 'reject'},
            {'inbound': ['in-a'], 'source_ip_cidr': ['127.0.0.1/32'], 'outbound': '01_direct_outbound'},
            {'inbound': ['in-a'], 'action': 'reject'}]}}
        write(cfg / '00_socks5_guard.json', guard)
        write(cfg / '01_direct_outbound.json', {'outbounds': [{'type': 'direct', 'tag': '01_direct_outbound'}]})
        self.f.routes['routes'] = [Fixture.route('sing-box')]
        work = self.f.stage()
        rules = json.loads((work / 'sing-box.json').read_text())['route']['rules']
        self.assertEqual('reject', rules[0]['action'])
        self.assertEqual('and', rules[1]['mode'])
        self.assertEqual('socks5_a', rules[1]['outbound'])
        self.assertEqual('reject', rules[3]['action'])

    def test_inbound_edit_normalizes_with_candidate_guard(self):
        self.f.routes['routes'] = [Fixture.route('sing-box')]
        work = self.f.stage()
        guard = {'route': {'rules': [
            {'type': 'logical', 'mode': 'and', 'rules': [
                {'inbound': ['in-a']}, {'source_ip_cidr': ['127.0.0.2/32'], 'invert': True}], 'action': 'reject'},
            {'inbound': ['in-a'], 'source_ip_cidr': ['127.0.0.2/32'], 'outbound': '01_direct_outbound'},
            {'inbound': ['in-a'], 'action': 'reject'}]}}
        write(work / 'sb' / '00_socks5_guard.json', guard)
        write(work / 'sb' / '01_direct_outbound.json', {'outbounds': [{'type': 'direct', 'tag': '01_direct_outbound'}]})
        subprocess.run([SB, 'merge', str(work / 'edited.json'), '-C', str(work / 'sb')], capture_output=True, check=True)
        self.f.run('socks5OutboundPrepareSingBoxMerged "$socks5OutboundRoot/stage/edited.json" '
                   '"$socks5OutboundRoot/stage" "$socks5OutboundRoot/stage/sb"')
        rules = json.loads((work / 'edited.json').read_text())['route']['rules']
        self.assertEqual(guard['route']['rules'][0], rules[0])
        self.assertEqual(['127.0.0.2/32'], rules[1]['rules'][0]['source_ip_cidr'])
        self.assertEqual('socks5_a', rules[1]['outbound'])

    def test_migration_preserves_raw_rules_and_tags(self):
        (self.f.state / 'outbounds.json').unlink()
        (self.f.state / 'routes.json').unlink()
        cfg = self.f.config('sing-box')
        write(cfg / 'socks5_outbound.json', {'outbounds': [{'type': 'socks', 'tag': 'socks5_outbound', 'server': '127.0.0.1', 'server_port': 1080}]})
        raw = {'domain_regex': ['.*legacy.*'], 'outbound': 'socks5_outbound'}
        write(cfg / 'socks5_01_outbound_route.json', {'route': {'rules': [raw]}})
        self.f.run('socks5OutboundTransaction socks5OutboundSetDefault xray ""')
        state = json.loads((self.f.state / 'routes.json').read_text())
        self.assertEqual(raw, state['routes'][0]['legacy_rule'])
        self.assertFalse((cfg / 'socks5_outbound.json').exists())
        merged = json.loads((cfg.parent / 'config.json').read_text())
        self.assertIn(raw, merged['route']['rules'])

    def test_real_traffic_all_match_target_only_and_default(self):
        with contextlib.ExitStack() as stack:
            nodes = []
            for _ in range(3):
                server = stack.enter_context(SocksServer(('127.0.0.1', 0), SocksHandler))
                server.hits = []
                threading.Thread(target=server.serve_forever, daemon=True).start()
                stack.callback(server.shutdown)
                nodes.append(server)
            http_server = stack.enter_context(http.server.ThreadingHTTPServer(('127.0.0.1', 0), HttpHandler))
            threading.Thread(target=http_server.serve_forever, daemon=True).start()
            stack.callback(http_server.shutdown)
            for node, server in zip(self.f.nodes['nodes'], nodes):
                node['server_port'] = server.server_address[1]
            # Selected SOCKS inbounds retain their existing source access restrictions.
            write(self.f.config('sing-box') / '00_socks5_guard.json', {'route': {'rules': [
                {'type': 'logical', 'mode': 'and', 'rules': [
                    {'inbound': ['in-a']}, {'source_ip_cidr': ['127.0.0.1/32'], 'invert': True}], 'action': 'reject'},
                {'inbound': ['in-a'], 'source_ip_cidr': ['127.0.0.1/32'], 'outbound': '01_direct_outbound'},
                {'inbound': ['in-a'], 'action': 'reject'}]}})
            write(self.f.config('sing-box') / '01_direct_outbound.json',
                  {'outbounds': [{'type': 'direct', 'tag': '01_direct_outbound'}]})
            for core in self.f.cores:
                self.f.routes['routes'] += [
                    Fixture.route(core, 'match', core + '-match', domains=['full:localhost'], priority=10, node='b'),
                    Fixture.route(core, 'all', core + '-all', node='a'),
                    Fixture.route(core, 'target_only', core + '-target', ips=['127.0.0.1/32'], node='c', priority=200)]
            work = self.f.stage()
            processes = []
            for core, binary, args in [
                    ('sing-box', SB, ['-c', str(work / 'sing-box.json')]),
                    ('xray', XR, ['-confdir', str(work / 'xr')])]:
                process = subprocess.Popen([binary, 'run'] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                processes.append(process)
                stack.callback(lambda p=process: p.kill() if p.poll() is None else None)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    try:
                        with socket.create_connection(('127.0.0.1', self.f.ports[core][0]), timeout=.1):
                            break
                    except OSError:
                        time.sleep(.05)
                self.assertIsNone(process.poll(), core + ' exited before listening')
            for core in self.f.cores:
                for inbound, host, expected in [(0, '127.0.0.1', 0), (0, 'localhost', 1), (1, '127.0.0.1', 2), (1, 'localhost', None)]:
                    before = [len(s.hits) for s in nodes]
                    result = subprocess.run(['curl', '--silent', '--show-error', '--fail', '--max-time', '5',
                                             '--noproxy', '', '--socks5-hostname', '127.0.0.1:' + str(self.f.ports[core][inbound]),
                                             'http://' + host + ':' + str(http_server.server_address[1])],
                                            text=True, capture_output=True, check=True)
                    self.assertEqual('route-ok', result.stdout)
                    self.assertEqual([n + (i == expected) for i, n in enumerate(before)], [len(s.hits) for s in nodes], core)
            before = [len(s.hits) for s in nodes]
            rejected = subprocess.run(['curl', '--silent', '--fail', '--max-time', '3', '--noproxy', '',
                                       '--interface', '127.0.0.2', '--socks5-hostname',
                                       '127.0.0.1:' + str(self.f.ports['sing-box'][0]),
                                       'http://127.0.0.1:' + str(http_server.server_address[1])],
                                      capture_output=True)
            self.assertNotEqual(0, rejected.returncode)
            self.assertEqual(before, [len(s.hits) for s in nodes])
            for process in processes:
                process.terminate()
                process.wait(timeout=5)
            # Changing a global default affects unmatched traffic on either core.
            self.f.routes['defaults'] = {'sing-box': 'c', 'xray': 'c'}
            work = self.f.stage()
            for core, binary, args in [
                    ('sing-box', SB, ['-c', str(work / 'sing-box.json')]),
                    ('xray', XR, ['-confdir', str(work / 'xr')])]:
                process = subprocess.Popen([binary, 'run'] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                stack.callback(lambda p=process: p.kill() if p.poll() is None else None)
                time.sleep(.15)
                before = len(nodes[2].hits)
                subprocess.run(['curl', '--silent', '--fail', '--max-time', '5', '--noproxy', '',
                                '--socks5-hostname', '127.0.0.1:' + str(self.f.ports[core][1]),
                                'http://localhost:' + str(http_server.server_address[1])],
                               text=True, capture_output=True, check=True)
                self.assertEqual(before + 1, len(nodes[2].hits))
                process.terminate()
                process.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
