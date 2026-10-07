#!/usr/bin/env python3
"""Exercise Installer branches using disposable stubs; never run system launch commands."""
import json, os, pathlib, subprocess, tempfile, unittest
SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'pkg-scripts' / 'postinstall'
class PostinstallTests(unittest.TestCase):
    def run_case(self, *, user='tester', uid='501', target='/', app=True, gui=True, running=False, launch=True):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            app_path = root / 'UniEnter.app'
            if app: app_path.mkdir()
            calls = root / 'calls'
            stub = root / 'stub'
            stub.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
name=pathlib.Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as f: f.write(json.dumps([name,*sys.argv[1:]])+'\\n')
if name=='stat': print(os.environ['TEST_USER'])
elif name=='id': print(os.environ['TEST_UID'])
elif name=='pgrep': sys.exit(0 if os.environ['RUNNING']=='1' else 1)
elif name=='launchctl': sys.exit(0 if os.environ['GUI' if sys.argv[1]=='print' else 'LAUNCH']=='1' else 1)
''')
            stub.chmod(0o755)
            source = SOURCE.read_text().replace('/Applications/UniEnter.app',str(app_path))
            for command in ('/usr/bin/stat','/usr/bin/id','/usr/bin/pgrep','/bin/launchctl','/usr/bin/sudo','/usr/bin/open'):
                replacement=root/pathlib.Path(command).name
                replacement.symlink_to(stub)
                source=source.replace(command,str(replacement))
            script=root/'postinstall'
            script.write_text(source)
            env=dict(os.environ,CALLS=str(calls),TEST_USER=user,TEST_UID=uid,GUI=str(int(gui)),RUNNING=str(int(running)),LAUNCH=str(int(launch)))
            result=subprocess.run(['/bin/bash',str(script),'package','/Applications',target],env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            entries=[json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            return [entry for entry in entries if entry[:2]==['launchctl','asuser']], result.stdout
    def test_launch_uses_user_credentials_and_home(self):
        launches,_=self.run_case()
        self.assertEqual(len(launches),1)
        args=launches[0]
        self.assertEqual(args[2],'501')
        self.assertEqual(pathlib.Path(args[3]).name,'sudo')
        self.assertEqual(args[4:7],['-H','-u','tester'])
        self.assertEqual(pathlib.Path(args[7]).name,'open')
        self.assertEqual(len(args),9)
    def test_skip_unsafe_or_unavailable_sessions(self):
        for case in [dict(user='root'),dict(user='loginwindow'),dict(user='_mbsetupuser'),dict(user=''),dict(uid='0'),dict(uid='500'),dict(uid='bad'),dict(uid=''),dict(gui=False),dict(app=False),dict(target='/Volumes/Other'),dict(target='')]:
            with self.subTest(case=case): self.assertEqual(self.run_case(**case)[0],[])
    def test_already_running_is_preserved(self):
        self.assertEqual(self.run_case(running=True)[0],[])
    def test_launch_failure_does_not_fail_install(self):
        launches,output=self.run_case(launch=False)
        self.assertEqual(len(launches),1)
        self.assertIn('open UniEnter from Applications',output)
if __name__=='__main__': unittest.main()
