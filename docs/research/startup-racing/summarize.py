#!/usr/bin/env python3
"""Summarise trial records: medians, p90s, paired deltas, bytes, connections.

  python3 summarize.py runs.jsonl bandwidth.jsonl > summary.json
"""
import json, statistics, sys

MAIN = json.load(open(sys.argv[1]))
BANDWIDTH = json.load(open(sys.argv[2]))


def indexed(records):
    return {record['title']['id']: record for record in records if record.get('ok')}


main = indexed(MAIN)
bandwidth = indexed(BANDWIDTH)
identifiers = [identifier for identifier in main if identifier in bandwidth]


def median(values):
    return round(statistics.median(values), 3) if values else None


def p90(values):
    if not values:
        return None
    values = sorted(values)
    rank = 0.9 * (len(values) - 1)
    low = int(rank)
    high = min(low + 1, len(values) - 1)
    return round(values[low] + (values[high] - values[low]) * (rank - low), 3)


def samples(record, slot):
    return [single['ttff_s'] for single in record['singles'] if single['slot'] == slot and single['ttff_s'] is not None]


def failures(record, slot):
    return [single for single in record['singles'] if single['slot'] == slot and single['ttff_s'] is None]


def races(record):
    return [race['ttff_s'] for race in record.get('races', []) if race.get('ttff_s') is not None]


def http_singles(record, index):
    rows = record.get('http_singles') or []
    return [rows[index]['ttff_s']] if len(rows) > index and rows[index]['ttff_s'] is not None else []


def http_races(record):
    return [race['ttff_s'] for race in record.get('http_races', []) if race.get('ttff_s') is not None]


rows = []
for identifier in identifiers:
    head, bw = main[identifier], bandwidth[identifier]
    s0 = samples(head, 0) + samples(bw, 0)
    s1 = samples(head, 1) + samples(bw, 1)
    s2 = samples(head, 2) + samples(bw, 2)
    race = races(head) + races(bw)
    f0 = len(failures(head, 0)) + len(failures(bw, 0))
    f1 = len(failures(head, 1)) + len(failures(bw, 1))
    http0 = http_singles(head, 0) + http_singles(bw, 0)
    http1 = http_singles(head, 1) + http_singles(bw, 1)
    http_race = http_races(head) + http_races(bw)
    single = median(s0)
    if single is None and median(s1) is not None:
        single = 20.0 + 2.0 + median(s1)
    best_single = [value for value in (median(s0), median(s1)) if value is not None]
    best_http = [value for value in (median(http0), median(http1)) if value is not None]
    bw_single = next((single for single in bw['singles'] if single['slot'] == 0), None)
    bw_race = (bw.get('races') or [None])[0]
    hashes = [flow.get('info_hash') for flow in (bw_race or {}).get('flows', [])] if bw_race else []
    rows.append({
        'id': identifier, 'title': head['title']['name'], 'kind': head['title']['type'],
        'resolve_s': head.get('resolve_s'),
        's0': median(s0), 's1': median(s1), 's2': median(s2),
        's0_trials': len(s0) + f0, 's1_trials': len(s1) + f1, 's0_failures': f0, 's1_failures': f1,
        'race': median(race), 'race_trials': len(head.get('races', [])) + len(bw.get('races', [])),
        'race_failures': sum(1 for item in head.get('races', []) + bw.get('races', []) if item.get('ttff_s') is None),
        'single': single, 'ideal_race': min(best_single) if best_single else None,
        'h0': median(http0), 'h1': median(http1), 'http_race': median(http_race),
        'best_http': min(best_http) if best_http else None,
        'bytes_single': bw_single.get('bytes') if bw_single else None,
        'sockets_single': bw_single.get('sockets') if bw_single else None,
        'bytes_race': bw_race.get('bytes') if bw_race else None,
        'sockets_race': bw_race.get('sockets') if bw_race else None,
        'race_same_hash': bool(hashes and hashes[0] and hashes[0] == hashes[1]),
        'race_winner': bw_race.get('winner') if bw_race else None,
        'http_bytes_single': (bw.get('http_singles') or [{}])[0].get('bytes'),
        'http_sockets_single': (bw.get('http_singles') or [{}])[0].get('sockets'),
        'http_bytes_race': (bw.get('http_races') or [{}])[0].get('bytes'),
        'http_sockets_race': (bw.get('http_races') or [{}])[0].get('sockets'),
        'http_probes': (head.get('http_probes') or []) + (bw.get('http_probes') or []),
        'http_probe_ttfb': [probe['ttfb'] for probe in (head.get('http_probes') or []) + (bw.get('http_probes') or [])
                            if probe['code'] in (200, 206) and probe.get('ttfb') is not None],
    })


def column(key):
    return [row[key] for row in rows if row.get(key) is not None]


paired = [row['single'] - row['race'] for row in rows if row['single'] is not None and row['race'] is not None]
http_paired = [row['h0'] - row['http_race'] for row in rows if row['h0'] is not None and row['http_race'] is not None]
faster_second = [row for row in rows if row['s0'] is not None and row['s1'] is not None and row['s1'] < row['s0']]
slower_second = [row for row in rows if row['s0'] is not None and row['s1'] is not None and row['s1'] >= row['s0']]
probes = [probe for row in rows for probe in row['http_probes']]

summary = {
    'titles': len(rows),
    'resolve_median': median(column('resolve_s')), 'resolve_p90': p90(column('resolve_s')),
    'single_median': median(column('single')), 'single_p90': p90(column('single')),
    'head_single_median': median(column('s0')), 'head_single_p90': p90(column('s0')),
    'second_single_median': median(column('s1')), 'second_single_p90': p90(column('s1')),
    'race_median': median(column('race')), 'race_p90': p90(column('race')),
    'ideal_race_median': median(column('ideal_race')), 'ideal_race_p90': p90(column('ideal_race')),
    'single_failures': sum(row['s0_failures'] for row in rows), 'single_trials': sum(row['s0_trials'] for row in rows),
    'second_failures': sum(row['s1_failures'] for row in rows), 'second_trials': sum(row['s1_trials'] for row in rows),
    'race_failures': sum(row['race_failures'] for row in rows), 'race_trials': sum(row['race_trials'] for row in rows),
    'paired_n': len(paired), 'paired_delta_median': median(paired), 'paired_delta_p90': p90(paired),
    'race_better_1s': sum(1 for delta in paired if delta >= 1.0),
    'race_better_05s': sum(1 for delta in paired if delta >= 0.5),
    'race_worse_1s': sum(1 for delta in paired if delta <= -1.0),
    'race_worse_05s': sum(1 for delta in paired if delta <= -0.5),
    'race_slower_than_both': sum(1 for row in rows if row['race'] and row['s0'] and row['s1']
                                 and row['race'] > max(row['s0'], row['s1']) + 0.5),
    'race_within_half_second_of_ideal': sum(1 for row in rows if row['race'] and row['ideal_race']
                                            and row['race'] - row['ideal_race'] <= 0.5),
    'race_won_by_second_row': sum(1 for row in rows if row['race_winner'] == 1),
    'race_same_hash': sum(1 for row in rows if row['race_same_hash']),
    'second_row_faster_titles': len(faster_second),
    'second_row_faster_gain_median': median([row['s1'] - row['s0'] for row in faster_second]),
    'second_row_faster_race_gain_median': median([row['single'] - row['race'] for row in faster_second
                                                  if row['race'] is not None]),
    'second_row_slower_titles': len(slower_second),
    'second_row_slower_race_gain_median': median([row['single'] - row['race'] for row in slower_second
                                                  if row['race'] is not None]),
    'bytes_single_median': median(column('bytes_single')), 'bytes_race_median': median(column('bytes_race')),
    'bytes_ratio_median': median([row['bytes_race'] / row['bytes_single'] for row in rows
                                  if row['bytes_single'] and row['bytes_race']]),
    'sockets_single_median': median(column('sockets_single')), 'sockets_race_median': median(column('sockets_race')),
    'sockets_ratio_median': median([row['sockets_race'] / row['sockets_single'] for row in rows
                                    if row['sockets_single'] and row['sockets_race']]),
    'http_single_median': median(column('h0')), 'http_single_p90': p90(column('h0')),
    'http_second_median': median(column('h1')), 'http_second_p90': p90(column('h1')),
    'http_race_median': median(column('http_race')), 'http_race_p90': p90(column('http_race')),
    'http_best_single_median': median(column('best_http')), 'http_best_single_p90': p90(column('best_http')),
    'http_paired_n': len(http_paired), 'http_paired_delta_median': median(http_paired),
    'http_paired_delta_p90': p90(http_paired),
    'http_race_better_1s': sum(1 for delta in http_paired if delta >= 1.0),
    'http_race_worse_1s': sum(1 for delta in http_paired if delta <= -1.0),
    'http_probe_count': len(probes),
    'http_probe_ok': sum(1 for probe in probes if probe['code'] in (200, 206)),
    'http_probe_codes': {code: sum(1 for probe in probes if probe['code'] == code)
                         for code in sorted({probe['code'] for probe in probes})},
    'http_probe_ttfb_median': median([ttfb for row in rows for ttfb in row['http_probe_ttfb']]),
    'http_bytes_single_median': median(column('http_bytes_single')),
    'http_bytes_race_median': median(column('http_bytes_race')),
    'http_sockets_single_median': median(column('http_sockets_single')),
    'http_sockets_race_median': median(column('http_sockets_race')),
}
json.dump({'summary': summary, 'rows': rows}, open(sys.argv[3] if len(sys.argv) > 3 else '/dev/stdout', 'w'), indent=1)
print(json.dumps(summary, indent=1))
print()
print(f"{'title':<34}{'resolve':>8}{'single':>8}{'race':>8}{'ideal':>8}{'http':>8}{'httprace':>9}{'MB s':>8}{'MB r':>8}{'sock s':>8}{'sock r':>8}")
for row in rows:
    def number(value, width=8, decimals=2):
        return f"{value:>{width}.{decimals}f}" if isinstance(value, (int, float)) else f"{'-':>{width}}"
    print(f"{row['title'][:33]:<34}{number(row['resolve_s'])}{number(row['single'])}{number(row['race'])}"
          f"{number(row['ideal_race'])}{number(row['h0'])}{number(row['http_race'], 9)}"
          f"{number((row['bytes_single'] or 0) / 1e6)}{number((row['bytes_race'] or 0) / 1e6)}"
          f"{number(row['sockets_single'], 8, 0)}{number(row['sockets_race'], 8, 0)}")