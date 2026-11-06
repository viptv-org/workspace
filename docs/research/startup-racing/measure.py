#!/usr/bin/env python3
"""Run the startup trials: for each title, the ranked top three rows and a race of the top two.

Also probes the HTTP add-on's ranked direct rows and measures the first two that deliver
bytes, single and raced. One record per title is appended to the output file, so a run can
be resumed or split into batches.

  python3 measure.py --titles titles.json --out runs.jsonl --only 0,1,2
  HTTP_ADDON=https://... python3 measure.py ...
"""
import argparse, json, os, random, subprocess, sys, threading, time, traceback, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import Backend, run_flow, run_http_flow, close_flow, rx_bytes

HTTP_ADDON = os.environ['HTTP_ADDON']


def summarize(flow):
    row = flow.get('row') or {}
    admission = flow.get('admission') or {}
    delivery = admission.get('delivery') or {}
    grant = delivery.get('grant') or {}
    return {
        'id': row.get('id'),
        'delivery': row.get('delivery'),
        'detail': (row.get('detail') or '').split('\n')[0][:140],
        'seeders': row.get('seeders'),
        'height': row.get('quality_height'),
        'provider': (row.get('presentation') or {}).get('provider_name'),
        'kind': delivery.get('kind') or flow.get('kind'),
        'info_hash': grant.get('info_hash'),
        'admission_s': round(admission.get('seconds', 0), 3),
        'prebuffer_s': round(flow['prebuffer'], 3) if flow.get('prebuffer') is not None else None,
        'ttff_s': round(flow['ttff'], 3) if flow.get('ttff') is not None else None,
        'bytes': flow.get('bytes'),
        'prebuffer_bytes': flow.get('prebuffer_bytes'),
        'sockets': flow.get('sockets'),
        'error': flow.get('error'),
        'reason': flow.get('reason'),
    }


def direct_rows(title):
    request = urllib.request.Request(f"{HTTP_ADDON}/stream/{title['type']}/{title['id']}.json",
                                     headers={'User-Agent': 'viptv-startup-research/1'})
    rows = json.loads(urllib.request.urlopen(request, timeout=25).read()).get('streams', [])
    return [{'name': row.get('name') or '', 'title': row.get('title') or '', 'url': row['url'],
             'quality': row.get('quality_height')} for row in rows if row.get('url')]


def probe_url(url):
    """Range GET through the add-on redirect: does this row deliver media bytes, and when is the first one."""
    result = subprocess.run(['curl', '-sS', '-L', '-m', '12', '-r', '0-1023', '-o', '/dev/null',
                             '-w', '%{http_code} %{time_starttransfer}', url], capture_output=True, text=True)
    parts = result.stdout.split()
    try:
        return {'code': int(parts[0]), 'ttfb': round(float(parts[1]), 3)}
    except Exception:
        return {'code': 0, 'ttfb': None}


def first_line(text):
    return (text or '').strip().split('\n')[0].strip()


def match_url(candidate, pool, used):
    wanted = (candidate.get('name') or '', first_line(candidate.get('detail')))
    for index, row in enumerate(pool):
        if index not in used and (row['name'], first_line(row['title'])) == wanted:
            used.add(index)
            return row['url']
    for index, row in enumerate(pool):
        if index not in used and row['name'] == candidate.get('name'):
            used.add(index)
            return row['url']
    return None


def single(backend, row, url=None):
    flow = None
    try:
        flow = run_http_flow(row, url) if url else run_flow(backend, row)
        if (flow.get('error') or '').__contains__('playback_capacity'):
            close_flow(backend, flow)
            time.sleep(1.5)
            flow = run_http_flow(row, url) if url else run_flow(backend, row)
        return summarize(flow)
    finally:
        if flow is not None:
            close_flow(backend, flow)


def race(backend, pairs):
    """Open both rows together; the first decoded frame wins and cancels the other."""
    started = time.perf_counter()
    base = rx_bytes()
    stop = threading.Event()
    won = threading.Event()
    summaries = {}
    errors = {}
    result = {}

    def one(index, row, url):
        flow = None
        try:
            flow = run_http_flow(row, url, t0=started, stop_event=stop, bytes_base=base) if url else \
                run_flow(backend, row, t0=started, stop_event=stop, bytes_base=base, cancel=stop)
            summaries[index] = summarize(flow)
            if flow.get('frame') is not None and not won.is_set():
                won.set()
                result['winner'] = index
                result['ttff'] = flow['ttff']
                stop.set()
        except Exception as error:
            errors[index] = repr(error)
        finally:
            if flow is not None:
                close_flow(backend, flow)

    threads = [threading.Thread(target=one, args=(index, row, url)) for index, (row, url) in enumerate(pairs)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=80)
    stop.set()
    return {'ttff_s': round(result['ttff'], 3) if 'ttff' in result else None,
            'winner': result.get('winner'),
            'bytes': rx_bytes() - base,
            'sockets': sum((summary.get('sockets') or 0) for summary in summaries.values()),
            'flows': [summaries[key] for key in sorted(summaries)],
            'errors': errors}


def record_title(backend, title, index, bandwidth_only):
    record = {'title': title, 'index': index, 'started': time.time()}
    rows, resolve_s, arrivals, error = backend.discover(title)
    record.update({'resolve_s': round(resolve_s, 3) if resolve_s else None,
                   'arrivals': [{'source': a[0], 'rows': a[1], 'at_s': round(a[2], 3), 'error': a[3]} for a in arrivals],
                   'rows': len(rows), 'discovery_error': error})
    if error or not rows:
        record['ok'] = False
        return record
    ranked = backend.rank([row['id'] for row in rows])
    by_id = {row['id']: row for row in rows}
    top = [by_id[row['id']] for row in ranked[:3]]
    record['ranked_top'] = [{'id': row['id'], 'delivery': row.get('delivery'),
                             'provider': (row.get('presentation') or {}).get('provider_name'),
                             'height': row.get('quality_height'), 'seeders': row.get('seeders'),
                             'detail': (row.get('detail') or '').split('\n')[0][:120]} for row in top]
    record['best_match_id'] = ranked[0]['id'] if ranked else None
    http_ranked = [row for row in ranked if row.get('delivery') == 'direct'][:6]
    http_candidates = []
    http_urls = {}
    probes = []
    if http_ranked:
        pool = direct_rows(title)
        used = set()
        for candidate in http_ranked:
            url = match_url(candidate, pool, used)
            if not url:
                continue
            probe = probe_url(url)
            probes.append({'detail': (candidate.get('detail') or '').split('\n')[0][:80],
                           'height': candidate.get('quality_height'), **probe})
            if probe['code'] in (200, 206) and len(http_candidates) < 2:
                http_candidates.append(candidate)
                http_urls[candidate['id']] = url
        record['http_probes'] = probes
        record['http_working'] = sum(1 for probe in probes if probe['code'] in (200, 206))
    slots = [0, 1] if bandwidth_only else [0, 0, 1, 1] + ([2] if len(top) > 2 else [])
    random.Random(index).shuffle(slots)
    singles = []
    for slot in slots:
        row = top[slot]
        summary = single(backend, row, http_urls.get(row['id']) if row.get('delivery') == 'direct' else None)
        summary['slot'] = slot
        singles.append(summary)
    record['singles'] = singles
    if len(top) >= 2:
        pairs = [(top[0], http_urls.get(top[0]['id']) if top[0].get('delivery') == 'direct' else None),
                 (top[1], http_urls.get(top[1]['id']) if top[1].get('delivery') == 'direct' else None)]
        record['races'] = [race(backend, pairs) for _ in range(1 if bandwidth_only else 2)]
    if http_candidates and all(http_urls.get(candidate['id']) for candidate in http_candidates):
        record['http_singles'] = [single(backend, candidate, http_urls[candidate['id']]) for candidate in http_candidates]
        record['http_races'] = [race(backend, [(candidate, http_urls[candidate['id']]) for candidate in http_candidates])
                                for _ in range(2)]
    record['ok'] = True
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--titles', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--only', default=None, help='comma separated title indexes')
    parser.add_argument('--bandwidth', action='store_true', help='one single per head row and one race')
    args = parser.parse_args()
    titles = json.load(open(args.titles))
    wanted = set(int(value) for value in args.only.split(',')) if args.only else None
    records = json.load(open(args.out)) if os.path.exists(args.out) else []
    done = {record['title']['id'] for record in records if record.get('ok')}
    backend = Backend()
    for index, title in enumerate(titles):
        if wanted is not None and index not in wanted:
            continue
        if title['id'] in done:
            continue
        try:
            record = record_title(backend, title, index, args.bandwidth)
        except Exception:
            record = {'title': title, 'index': index, 'ok': False, 'traceback': traceback.format_exc()}
        records.append(record)
        json.dump(records, open(args.out, 'w'), indent=1)
        print(index, title['id'], 'ok' if record.get('ok') else record.get('discovery_error') or 'failed', flush=True)
        backend = Backend()


if __name__ == '__main__':
    main()