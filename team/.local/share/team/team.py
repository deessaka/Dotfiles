#!/usr/bin/env python3
"""Provider-neutral local mission ledger; no model calls, shell or network."""
import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

STATES = {
 'draft': {'ready','blocked'}, 'ready': {'developing','blocked'},
 'developing': {'verifying','blocked'}, 'verifying': {'correcting','integrating','blocked'},
 'correcting': {'developing','blocked'}, 'integrating': {'done','correcting','blocked'},
 'done': {'ready'}, 'blocked': {'draft','ready'}
}
ROLES = [
    'team_architect', 'team_backend', 'team_backend_tests', 'team_designer',
    'team_explorer', 'team_frontend', 'team_frontend_tests', 'team_qa',
    'team_researcher', 'team_reviewer',
]

def now(): return dt.datetime.now(dt.timezone.utc).isoformat()
def save(path, data):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.write-')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, ensure_ascii=False, indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)

def root_path(value):
    root = Path(value).resolve()
    if not root.is_dir(): raise ValueError('Projet absent')
    return root

@contextlib.contextmanager
def ledger(root):
    folder = root / '.team'
    if not (folder / 'board.json').is_file(): raise ValueError('Initialiser la mission avec init')
    with (folder / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        board = json.loads((folder / 'board.json').read_text())
        yield board
        save(folder / 'board.json', board)

def git(root, *args):
    p = subprocess.run(['git','-C',str(root),*args], capture_output=True)
    if p.returncode: raise ValueError('Commande Git impossible : ' + ' '.join(args))
    return p.stdout

def fingerprint(root):
    # Hash tracked and untracked nonignored files, excluding mission metadata.
    head = git(root,'rev-parse','HEAD').strip()
    names = git(root,'ls-files','-z','--cached','--others','--exclude-standard').split(b'\0')
    digest = hashlib.sha256(head)
    for raw in sorted(set(names)):
        if not raw: continue
        relative = os.fsdecode(raw)
        if relative == '.team' or relative.startswith('.team/'): continue
        path = root / relative
        digest.update(raw + b'\0')
        if path.is_symlink(): digest.update(b'LINK' + os.fsencode(os.readlink(path)))
        elif path.is_file():
            digest.update(str(path.stat().st_mode & 0o777).encode())
            with path.open('rb') as f:
                for chunk in iter(lambda: f.read(1024*1024), b''): digest.update(chunk)
        else: digest.update(b'MISSING')
    return digest.hexdigest()

def content_hash(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def event(board, kind, **data): board['events'].append({'at':now(),'kind':kind,**data})
def ticket(board, name):
    if name not in board['tickets']: raise ValueError('Ticket inconnu')
    return board['tickets'][name]
def validated(board, root):
    approval = board.get('approval')
    if not approval: raise ValueError('Mission non approuvée')
    if approval['mission_sha256'] != content_hash(root/'.team/mission.md'):
        raise ValueError('mission.md a changé : approbation à actualiser après validation utilisateur')

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--root',default='.')
    sub=p.add_subparsers(dest='command',required=True)
    sub.add_parser('init'); sub.add_parser('status')
    a=sub.add_parser('approve'); a.add_argument('--reference',required=True)
    a=sub.add_parser('add'); a.add_argument('id'); a.add_argument('--title',required=True); a.add_argument('--role',choices=ROLES,required=True); a.add_argument('--depends',action='append',default=[]); a.add_argument('--criterion',action='append',required=True)
    a=sub.add_parser('move'); a.add_argument('id'); a.add_argument('state',choices=STATES); a.add_argument('--reason',required=True)
    a=sub.add_parser('evidence'); a.add_argument('id'); a.add_argument('--check',required=True); a.add_argument('--result',choices=['pass','fail','unverified'],required=True); a.add_argument('--report',required=True)
    args=p.parse_args(); root=root_path(args.root); folder=root/'.team'
    if args.command=='init':
        if folder.exists(): raise ValueError('.team existe déjà : aucune modification')
        folder.mkdir(); (folder/'tickets').mkdir(); (folder/'reports').mkdir(); (folder/'proposals').mkdir()
        templates=Path(__file__).resolve().parent/'templates'
        for name in ['mission.md','handoff.md']:
            (folder/name).write_text((templates/name).read_text())
        save(folder/'board.json', {'schema':1,'created_at':now(),'approval':None,'limits':{'max_attempts':20,'max_minutes':120},'attempts':0,'tickets':{},'events':[]})
        print('Mission initialisée ; compléter mission.md et créer les tickets.'); return
    with ledger(root) as board:
        if args.command=='approve':
            if not args.reference.strip(): raise ValueError('Référence vide')
            previous=board.get('approval')
            board['approval']={'at': previous['at'] if previous else now(),'reference':args.reference,'mission_sha256':content_hash(folder/'mission.md')}
            event(board,'approval',reference=args.reference)
        elif args.command=='add':
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}',args.id): raise ValueError('Identifiant invalide')
            if args.id in board['tickets']: raise ValueError('Ticket existant')
            if any(d not in board['tickets'] for d in args.depends): raise ValueError('Créer les dépendances avant le ticket')
            criteria=list(dict.fromkeys(c.strip() for c in args.criterion))
            if not all(criteria): raise ValueError('Critère vide')
            board['tickets'][args.id]={'title':args.title,'role':args.role,'state':'draft','depends':args.depends,'criteria':criteria,'corrections':0,'evidence':[]}
            (folder/'tickets'/f'{args.id}.md').write_text('# '+args.id+' — '+args.title+'\n\n## Critères\n'+''.join('- '+c+'\n' for c in criteria)+'\n## Références et versions\nÀ compléter.\n\n## Périmètre de fichiers et propriétaire\nÀ compléter.\n\n## Contrats et dépendances\nÀ compléter.\n\n## Vérifications exécutables\nÀ compléter.\n\n## Exclusions et risques\nÀ compléter.\n')
            event(board,'add',ticket=args.id)
        elif args.command=='move':
            t=ticket(board,args.id); target=args.state
            if target not in STATES[t['state']]: raise ValueError('Transition interdite : '+t['state']+' -> '+target)
            if not args.reason.strip(): raise ValueError('Motif obligatoire')
            if target in {'developing','verifying','integrating','done'}: validated(board,root)
            if target=='developing':
                if any(ticket(board,d)['state']!='done' for d in t['depends']): raise ValueError('Dépendance inachevée')
                if t['corrections']>=3: raise ValueError('Trois corrections : diagnostic et blocage requis')
                if board['attempts']>=board['limits']['max_attempts']: raise ValueError('Budget de tentatives atteint')
                elapsed=(dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(board['approval']['at'])).total_seconds()/60
                if elapsed>=board['limits']['max_minutes']: raise ValueError('Budget temporel atteint')
                board['attempts']+=1
            if target=='correcting': t['corrections']+=1
            if target in {'ready','developing','correcting'}: t['evidence']=[]
            if target=='done':
                stamp=fingerprint(root); definition=content_hash(folder/'tickets'/f'{args.id}.md')
                passes=set()
                for e in t['evidence']:
                    report=root/e['report']
                    if (e['fingerprint']==stamp and e['definition']==definition and report.is_file()
                        and content_hash(report)==e['report_sha256']):
                        if e['result']=='pass': passes.add(e['check'])
                        else: passes.discard(e['check'])
                if not set(t['criteria']).issubset(passes): raise ValueError('Preuves absentes, en échec ou obsolètes')
            before=t['state']; t['state']=target; event(board,'move',ticket=args.id,before=before,after=target,reason=args.reason)
        elif args.command=='evidence':
            validated(board,root); t=ticket(board,args.id)
            if t['state']!='integrating': raise ValueError('Preuves finales uniquement pendant integrating')
            if args.check not in t['criteria']: raise ValueError('Critère inconnu')
            report=(root/args.report).resolve(); reports=(folder/'reports').resolve()
            if not report.is_relative_to(reports) or not report.is_file() or not report.stat().st_size: raise ValueError('Rapport non vide requis dans .team/reports/')
            e={'at':now(),'check':args.check,'result':args.result,'report':str(report.relative_to(root)),'report_sha256':content_hash(report),'fingerprint':fingerprint(root),'definition':content_hash(folder/'tickets'/f'{args.id}.md')}
            t['evidence'].append(e); event(board,'evidence',ticket=args.id,check=args.check,result=args.result)
        else:
            print(json.dumps(board,ensure_ascii=False,indent=2)); return
        print('État enregistré.')

if __name__=='__main__':
    try: main()
    except (ValueError,OSError,KeyError) as exc:
        raise SystemExit('Erreur : '+str(exc))
