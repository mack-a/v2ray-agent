#!/usr/bin/env python3
"""Isolated SOCKS5 installer regression tests; never source/run the installer itself.

SOCKS5_TEST_CORE=/absolute/path/to/sing-box enables merge/check and TCP tests.
Service/firewall/package commands are stubbed; all /etc paths are redirected.
"""
import contextlib
import http.server
import json
import os
from pathlib import Path
import re
import shlex
import socket
import struct
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLERS = (ROOT / 'install.sh', ROOT / 'shell/install_en.sh')
CORE = os.environ.get('SOCKS5_TEST_CORE')
HELPERS = ('prepareSingBoxCoreForSocks5 socks5SingBoxService socks5InboundFirewall '
           'socks5PortAvailable normalizeSocks5Sources generateSocks5InboundConfig '
           'checkSocks5Candidate commitSocks5Inbound isDomainFormat').split()


def function(source, name):
    start = re.search(r'^' + re.escape(name) + r'\(\)\s*([({])', source, re.M)
    if start is None:
        raise AssertionError('Missing function: ' + name)
    closing = '\n}' if start[1] == '{' else '\n)'
    return source[start.start():source.index(closing, start.end()) + 2] + '\n'


def run(code, stdin='', timeout=20):
    return subprocess.run(['bash', '-c', code], input=stdin, text=True,
                          capture_output=True, timeout=timeout)


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


class InstallerTests(unittest.TestCase):
    def test_sources_reject_bad_addresses(self):
        valid = ('127.0.0.1, ::1,192.0.2.0/24,2001:db8::/32,::ffff:192.0.2.1')
        for installer in INSTALLERS:
            code = function(installer.read_text(), 'normalizeSocks5Sources')
            result = run(code + 'normalizeSocks5Sources ' + shlex.quote(valid))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('127.0.0.1/32', json.loads(result.stdout))
            for bad in ('', '1:::2', '1::2::3', '256.1.1.1', '01.2.3.4',
                        '192.0.2.1/33', '::1/129', '1:2:3:4:5:6:7', '::1,', 'test'):
                with self.subTest(installer=installer, bad=bad):
                    self.assertNotEqual(run(code + 'normalizeSocks5Sources ' + shlex.quote(bad)).returncode, 0)

    def test_existing_binary_never_queries_or_downloads(self):
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                binary = Path(tmp) / 'sing-box'
                binary.write_text('#!/bin/sh\nexit 0\n')
                binary.chmod(0o700)
                code = function(installer.read_text(), 'prepareSingBoxCoreForSocks5')
                code = code.replace('/etc/v2ray-agent/sing-box/sing-box', str(binary))
                stubs = '\nechoContent() { :; }; curl() { exit 80; }; installCoreRelease() { exit 81; }\n'
                self.assertEqual(run(code + stubs + 'prepareSingBoxCoreForSocks5').returncode, 0)
                binary.chmod(0o600)
                self.assertEqual(run(code + stubs + 'prepareSingBoxCoreForSocks5').returncode, 1)
                binary.unlink()
                self.assertEqual(run(code + stubs + 'prepareSingBoxCoreForSocks5').returncode, 1)

    def test_empty_and_mixed_detection_and_readers(self):
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                source = installer.read_text()
                code = ''.join(function(source, n) for n in (
                    'readInstallType', 'readInstallProtocolType', 'readConfigHostPathUUID'))
                code = code.replace('/etc/v2ray-agent', tmp)
                code += '\nreadInstallType; readInstallProtocolType; readConfigHostPathUUID\nprintf "RESULT %s:%s:%s" "$coreInstallType" "$currentInstallProtocolType" "$singBoxSocks5Port"\n'
                self.assertEqual(run(code).stdout, 'RESULT ::')
                sing = Path(tmp) / 'sing-box'
                (sing / 'conf/config').mkdir(parents=True)
                (sing / 'sing-box').touch(); (sing / 'sing-box').chmod(0o700)
                inbound = {'inbounds': [{'type': 'socks', 'listen_port': 12345}]}
                (sing / 'conf/config.json').write_text(json.dumps(inbound))
                (sing / 'conf/config/20_socks5_inbounds.json').write_text(json.dumps(inbound))
                (Path(tmp) / 'xray').mkdir(); (Path(tmp) / 'xray/xray').touch()
                result = run(code)
                self.assertEqual(result.stdout, 'RESULT 2:,20,:12345')
                self.assertEqual(result.stderr, '')
                xray = Path(tmp) / 'xray/conf'; xray.mkdir()
                (xray / '02_VLESS_TCP_inbounds.json').write_text('{"inbounds":[{"port":443,"settings":{"clients":[]},"streamSettings":{"tlsSettings":{"certificates":[]}}}]}')
                # Only detect protocols here: the Xray host reader needs real TLS fixtures.
                result = run(code.replace('; readConfigHostPathUUID', ''))
                self.assertEqual(result.stdout, 'RESULT 1:,0,20,:12345')
                (sing / 'conf/config.json').write_text('{}')
                (xray / '02_VLESS_TCP_inbounds.json').unlink()
                self.assertEqual(run(code).stdout, 'RESULT ::')

    def test_fresh_menu_reaches_inbound_without_touching_outbound(self):
        for installer in INSTALLERS:
            code = function(installer.read_text(), 'socks5Routing')
            code += '\nechoContent() { :; }; socks5InboundRoutingMenu() { echo reached; }; coreInstallType=\nsocks5Routing\n'
            self.assertIn('reached', run(code, '2\n').stdout)

    def test_service_registration_defers_enabling_on_both_managers(self):
        for installer in INSTALLERS:
            for release in ('debian', 'alpine'):
                with self.subTest(installer=installer, release=release), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    (root / 'systemd/system').mkdir(parents=True)
                    (root / 'init.d').mkdir()
                    code = ''.join(function(installer.read_text(), n) for n in (
                        'installSingBoxService', 'installAlpineStartup'))
                    code = code.replace('/etc/', tmp + '/')
                    code += '\nrelease=' + release + '\n' + '''
echoContent() { :; }
find() { echo /bin/systemctl; }
bootStartup() { echo premature-enable; }
systemctl() { echo "$*"; }
installSingBoxService 1 defer
'''
                    result = run(code)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertNotIn('premature-enable', result.stdout)
                    if release == 'debian':
                        self.assertEqual(result.stdout.strip(), 'daemon-reload')
                        self.assertTrue((root / 'systemd/system/sing-box.service').is_file())
                    else:
                        self.assertTrue((root / 'init.d/sing-box').is_file())

    def test_service_start_only_calls_the_selected_service_manager(self):
        for installer in INSTALLERS:
            for release in ('debian', 'alpine'):
                code = function(installer.read_text(), 'socks5SingBoxService')
                code += '\nrelease=' + release + '\n' + '''
systemctl() { echo "systemctl $*"; }
rc-service() { echo "rc-service $*"; }
singBoxMergeConfig() { exit 90; }
socks5SingBoxService start
'''
                result = run(code)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = 'rc-service sing-box start' if release == 'alpine' else 'systemctl start sing-box.service'
                self.assertEqual(result.stdout.strip(), expected)

    def test_uninstall_all_does_not_restart_an_empty_core(self):
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                guard = Path(tmp) / 'sing-box/conf/config/00_socks5_guard.json'
                guard.parent.mkdir(parents=True); guard.touch()
                code = function(installer.read_text(), 'removeSocks5Routing')
                code = code.replace('/etc/v2ray-agent', tmp)
                code += '''
echoContent() { :; }
commitSocks5Inbound() { echo removed; }
readInstallType() { coreInstallType=; singBoxConfigPath=; }
readInstallProtocolType() { currentInstallProtocolType=; }
reloadCore() { [[ -z $currentInstallProtocolType && -z $singBoxConfigPath ]]; }
socks5OutboundTransaction() { :; }
coreInstallType=2
singBoxConfigPath=/old/path/
currentInstallProtocolType=,20,
removeSocks5Routing
'''
                result = run(code, '3\n')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('removed', result.stdout)

    def test_firewall_ownership_and_failure(self):
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                code = function(installer.read_text(), 'socks5InboundFirewall')
                code += f'\njournal={shlex.quote(tmp + "/journal")}\n'
                code += '''
command() { [[ $1 == -v && $2 == ufw ]]; }
ufw() { if [[ $1 == status ]]; then printf 'Status: active\\n1080/tcp ALLOW Anywhere\\n'; else echo mutation; fi; }
socks5InboundFirewall add 1080 "$journal" || exit 1
[[ ! -f $journal ]] || exit 2
ufw() { [[ $1 == status ]] && { printf 'Status: active\\n'; return; }; return 1; }
socks5InboundFirewall add 1081 "$journal" && exit 3
[[ $(cat "$journal") == 'ufw 1081' ]]
'''
                result = run(code)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, '')

    def test_cancel_and_invalid_input_do_not_publish_or_open_ports(self):
        for installer in INSTALLERS:
            code = ''.join(function(installer.read_text(), name) for name in (
                'installSocks5InboundStandalone', 'normalizeSocks5Sources'))
            code += '''
echoContent() { :; }
installSocks5InboundTools() { :; }
prepareSingBoxCoreForSocks5() { echo unexpected-core; return 1; }
commitSocks5Inbound() { echo unexpected-publish; return 1; }
socks5InboundFirewall() { echo unexpected-firewall; return 1; }
installSocks5InboundStandalone
'''
            for stdin in ('', '127.0.0.1\n0\n', '\n1080\n\n1\n\ny\n',
                          '\n1080\n\n1\ninvalid\ny\n'):
                result = run(code, stdin)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('unexpected-', result.stdout)


SERVICE_STUB = r'''
# Real child process, fake service manager. State is on disk across subshells.
socks5SingBoxService() {
    local action=$1 pid
    printf '%s\n' "$action" >>"$fixture/events"
    case $action in
    exists) [[ -f "$fixture/service" ]] ;;
    enabled) [[ -f "$fixture/enabled" ]] ;;
    status) [[ -f "$fixture/running" ]] ;;
    pid) cat "$fixture/pid" ;;
    stop) if [[ -f "$fixture/pid" ]]; then kill "$(cat "$fixture/pid")" 2>/dev/null || :; fi; rm -f "$fixture/running" "$fixture/pid" ;;
    start)
        if [[ -f "$fixture/fail-start" ]]; then rm "$fixture/fail-start"; return 1; fi
        if [[ -f "$fixture/running" ]]; then return 0; fi
        "$fixture/sing-box/sing-box" run -c "$fixture/sing-box/conf/config.json" >"$fixture/core.log" 2>&1 &
        pid=$!; printf '%s' "$pid" >"$fixture/pid"
        sleep .25
        kill -0 "$pid" 2>/dev/null || return 1
        touch "$fixture/running" ;;
    enable) [[ ! -f "$fixture/fail-enable" ]] || { rm "$fixture/fail-enable"; return 1; }; touch "$fixture/enabled" ;;
    disable) rm -f "$fixture/enabled" ;;
    remove) rm -f "$fixture/service" ;;
    esac
}
installSingBoxService() { touch "$fixture/service"; }
socks5InboundFirewall() {
    echo "firewall-$1" >>"$fixture/events"
    [[ ! -f "$fixture/fail-firewall" ]] || { rm "$fixture/fail-firewall"; return 1; }
}
systemctl() {
    [[ $1 != show ]] || printf 'argv[]=%s/sing-box/sing-box run -c %s/sing-box/conf/config.json ;' "$fixture" "$fixture"
}
getDLCGeositeName() { return 1; }
echoContent() { printf '%s\n' "$2"; }
'''


@unittest.skipUnless(CORE, 'Set SOCKS5_TEST_CORE for real-core checks')
class RealCoreTests(unittest.TestCase):
    def fixture(self, installer, tmp):
        root = Path(tmp)
        (root / 'sing-box/conf/config').mkdir(parents=True)
        (root / 'sing-box/sing-box').symlink_to(Path(CORE).resolve())
        code = ''.join(function(installer.read_text(), n) for n in HELPERS)
        code = code.replace('/etc/v2ray-agent', tmp)
        return code + '\nfixture=' + shlex.quote(tmp) + '\nrelease=debian\n' + SERVICE_STUB

    def invoke(self, code, tail):
        result = run(code + tail)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    @staticmethod
    def stop(tmp):
        pid = Path(tmp) / 'pid'
        if pid.exists():
            with contextlib.suppress(ProcessLookupError):
                os.kill(int(pid.read_text()), 15)

    def test_standalone_regular_merge_reuses_dns_and_http_client(self):
        for installer in INSTALLERS:
            for domains in ('*', 'geosite:netflix'):
                with self.subTest(installer=installer, domains=domains), tempfile.TemporaryDirectory() as tmp:
                    source = installer.read_text()
                    code = self.fixture(installer, tmp)
                    # Include complete heredoc functions as well as the normal merge entry point.
                    start = source.index('initSingBoxLocalDNSConfig() {')
                    end = source.index('singBoxMergeConfig() (', start)
                    code += source[start:end].replace('/etc/v2ray-agent', tmp)
                    code += function(source, 'singBoxMergeConfig').replace('/etc/v2ray-agent', tmp)
                    code += '\nsocks5OutboundPrepareSingBoxMerged() { return 0; }\n'
                    conf = Path(tmp) / 'sing-box/conf'
                    (conf / 'config/base.json').write_text('{}')
                    self.invoke(code, f"""
generateSocks5InboundConfig "$fixture/sing-box/conf/config" {free_port()} pass '["127.0.0.1/32"]' ipv4_only {shlex.quote(domains)} 127.0.0.1 || exit 1
singBoxMergeConfig || exit 2
singBoxMergeConfig || exit 3
""")
                    merged = json.loads((conf / 'config.json').read_text())
                    self.assertEqual(1, sum(s.get('tag') == 'local' for s in merged['dns']['servers']))
                    self.assertEqual(1, sum(c.get('tag') == 'rule_set_http' for c in merged['http_clients']))
                    self.assertEqual('rule_set_http', merged['route']['default_http_client'])

    def test_transactions_restore_exact_config_and_service_state(self):
        for installer in INSTALLERS:
            for failure in ('fail-start', 'fail-enable', 'fail-firewall'):
                with self.subTest(installer=installer, failure=failure), tempfile.TemporaryDirectory() as tmp:
                    code = self.fixture(installer, tmp)
                    conf = Path(tmp) / 'sing-box/conf'
                    try:
                        port = free_port()
                        self.invoke(code, f'commitSocks5Inbound install {port} pass \'["127.0.0.1/32"]\' ipv4_only "*" 127.0.0.1\n')
                        before = {p.name: p.read_bytes() for p in (conf / 'config').iterdir()}
                        # Deliberately preserve formatting. Rollback must not regenerate the main file.
                        main = (conf / 'config.json').read_bytes() + b'\n\n'
                        (conf / 'config.json').write_bytes(main)
                        (Path(tmp) / failure).touch()
                        self.invoke(code, f'''
commitSocks5Inbound install {port} changed '["192.0.2.1/32"]' ipv4_only '*' 127.0.0.1 && exit 70
socks5SingBoxService status && socks5SingBoxService enabled
''')
                        self.assertEqual((conf / 'config.json').read_bytes(), main)
                        self.assertEqual({p.name: p.read_bytes() for p in (conf / 'config').iterdir()}, before)
                        self.assertFalse(list(conf.glob('.socks5.*')))
                        self.assertNotIn('xray', (Path(tmp) / 'events').read_text())
                        self.invoke(code, 'commitSocks5Inbound remove\n! socks5SingBoxService status && ! socks5SingBoxService enabled\n')
                        self.assertFalse((conf / 'config/20_socks5_inbounds.json').exists())
                    finally:
                        self.stop(tmp)

    def test_first_install_failure_leaves_no_service_or_configuration(self):
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                code = self.fixture(installer, tmp)
                (Path(tmp) / 'fail-start').touch()
                self.invoke(code, f'''commitSocks5Inbound install {free_port()} pass '["127.0.0.1/32"]' ipv4_only '*' 127.0.0.1 && exit 70
! socks5SingBoxService exists && ! socks5SingBoxService enabled
''')
                conf = Path(tmp) / 'sing-box/conf'
                self.assertFalse((conf / 'config.json').exists())
                self.assertEqual(list((conf / 'config').iterdir()), [])

    def test_invalid_candidate_does_not_stop_running_service(self):
        for installer in INSTALLERS:
            for conflict in ('forwarding-rule', 'direct-tag', 'bad-json'):
                with self.subTest(installer=installer, conflict=conflict), tempfile.TemporaryDirectory() as tmp:
                    code = self.fixture(installer, tmp)
                    conf = Path(tmp) / 'sing-box/conf'
                    (Path(tmp) / 'service').touch(); (Path(tmp) / 'running').touch()
                    cases = {
                        'forwarding-rule': {'route': {'rules': [{'action': 'route', 'outbound': '01_direct_outbound'}]}},
                        'direct-tag': {'outbounds': [{'type': 'block', 'tag': '01_direct_outbound'}]},
                    }
                    (conf / 'config/00_conflict.json').write_text(json.dumps(cases[conflict]) if conflict in cases else 'invalid json')
                    (conf / 'config.json').write_text('{"original":true}')
                    before = (conf / 'config.json').read_bytes()
                    self.invoke(code, f'''commitSocks5Inbound install {free_port()} pass '["127.0.0.1/32"]' ipv4_only '*' 127.0.0.1 && exit 70
socks5SingBoxService status
''')
                    self.assertEqual((conf / 'config.json').read_bytes(), before)
                    self.assertNotIn('stop\n', (Path(tmp) / 'events').read_text())
                    self.assertNotIn('firewall-add', (Path(tmp) / 'events').read_text())

    def test_remote_rule_set_configuration_with_real_core(self):
        # merge/check do not need to download the remote rule set or start a service.
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                code = self.fixture(installer, tmp)
                conf = Path(tmp) / 'sing-box/conf'
                (conf / 'config/base.json').write_text('{}')
                result = run(code + f'''
generateSocks5InboundConfig "$fixture/sing-box/conf/config" {free_port()} pass '["127.0.0.1/32"]' ipv4_only geosite:netflix 127.0.0.1 &&
checkSocks5Candidate "$fixture/sing-box/conf/config" "$fixture/merged.json"
''')
                version = subprocess.check_output([CORE, 'version'], text=True).splitlines()[0]
                if re.search(r'1\.1[0-3]\.', version):
                    # Existing old cores stay installed; unsupported config must fail safely.
                    self.assertNotEqual(result.returncode, 0)
                else:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_ipv6_listener_authentication(self):
        try:
            listener = socket.socket(socket.AF_INET6)
            listener.bind(('::1', 0))
        except OSError:
            self.skipTest('IPv6 loopback unavailable')
        port = listener.getsockname()[1]; listener.close()
        for installer in INSTALLERS:
            with tempfile.TemporaryDirectory() as tmp:
                code = self.fixture(installer, tmp)
                try:
                    self.invoke(code, f'''commitSocks5Inbound install {port} pass '["::1/128"]' ipv6_only '*' ::1\n''')
                    with socket.create_connection(('::1', port), timeout=2) as sock:
                        sock.sendall(b'\x05\x01\x02')
                        self.assertEqual(sock.recv(2), b'\x05\x02')
                        sock.sendall(b'\x01\x04pass\x04pass')
                        self.assertEqual(sock.recv(2), b'\x01\x00')
                finally:
                    self.stop(tmp)

    def test_tcp_auth_source_domain_guard_and_other_inbound(self):
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200); self.end_headers(); self.wfile.write(b'socks-ok')
            def log_message(self, *_):
                pass
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            for installer in INSTALLERS:
                with tempfile.TemporaryDirectory() as tmp:
                    code = self.fixture(installer, tmp)
                    port, other = free_port(), free_port()
                    conf = Path(tmp) / 'sing-box/conf/config'
                    existing = {'inbounds': [{'type': 'socks', 'tag': 'other', 'listen': '127.0.0.1', 'listen_port': other}],
                                'log': {'level': 'debug'},
                                'route': {'final': '01_direct_outbound'}}
                    (conf / '10_other.json').write_text(json.dumps(existing))
                    try:
                        self.invoke(code, f'''commitSocks5Inbound install {port} 'pa"ss' '["127.0.0.1/32"]' ipv4_only allowed.test 127.0.0.1\n''')
                        merged = json.loads((conf.parent / 'config.json').read_text())
                        self.assertNotIn('http_clients', merged)
                        self.assertIn(b'socks-ok', self.request(port, server.server_port, 'pa"ss', 'allowed.test'),
                                      (Path(tmp) / 'core.log').read_text())
                        self.assertNotIn(b'socks-ok', self.request(port, server.server_port, 'pa"ss', 'denied.test'))
                        self.assertNotIn(b'socks-ok', self.request(port, server.server_port, 'wrong', 'allowed.test'))
                        # Same auth, but no source permission, including allow-all target mode.
                        self.invoke(code, f'''commitSocks5Inbound install {port} 'pa"ss' '["192.0.2.1/32"]' ipv4_only '*' 127.0.0.1\n''')
                        self.assertNotIn(b'socks-ok', self.request(port, server.server_port, 'pa"ss', 'allowed.test'))
                        self.assertEqual(json.loads((conf / '10_other.json').read_text()), existing)
                        self.invoke(code, 'commitSocks5Inbound remove\nsocks5SingBoxService status\n')
                        with socket.create_connection(('127.0.0.1', other), timeout=2) as sock:
                            sock.sendall(b'\x05\x01\x00'); self.assertEqual(sock.recv(2), b'\x05\x00')
                    finally:
                        self.stop(tmp)
        finally:
            server.shutdown(); server.server_close()

    @staticmethod
    def request(port, target, password, host):
        def receive(sock, size):
            data = b''
            while len(data) < size:
                chunk = sock.recv(size - len(data))
                if not chunk:
                    raise ConnectionError('Incomplete SOCKS5 response')
                data += chunk
            return data
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=3) as sock:
                sock.sendall(b'\x05\x01\x02')
                if receive(sock, 2) != b'\x05\x02':
                    return b''
                cred = password.encode()
                sock.sendall(b'\x01' + bytes([len(cred)]) + cred + bytes([len(cred)]) + cred)
                if receive(sock, 2) != b'\x01\x00':
                    return b''
                sock.sendall(b'\x05\x01\x00\x01' + socket.inet_aton('127.0.0.1') + struct.pack('!H', target))
                # Finish SOCKS negotiation before sending application data, as clients do.
                reply = receive(sock, 4)
                if reply[1] != 0:
                    return b''
                length = {1: 4, 4: 16}.get(reply[3])
                if reply[3] == 3:
                    length = receive(sock, 1)[0]
                if length is None:
                    return b''
                receive(sock, length + 2)
                sock.sendall(('GET / HTTP/1.0\r\nHost: ' + host + '\r\n\r\n').encode())
                response = b''
                while True:
                    part = sock.recv(4096)
                    if not part:
                        return response
                    response += part
        except (OSError, TimeoutError):
            return b''


if __name__ == '__main__':
    unittest.main()
