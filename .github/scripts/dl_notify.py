"""Download notifier: compares the download counts of the release files with the last run and sends a push
notification for every file that was downloaded since.

Run every few minutes: by a GitHub Actions workflow (state kept in the Actions cache) or by a scheduled task on
a PC (DL_STATE = path of the state file). State = the counts of the last run. Where the notification goes, from
the environment (repository secrets in Actions):
  NTFY_TOPIC            ntfy.sh topic (subscribe to it in the ntfy app on the phone)
  TG_TOKEN + TG_CHAT    Telegram bot token and chat id (optional)
"""
import json
import os
import urllib.parse
import urllib.request

REPO = os.environ.get('GITHUB_REPOSITORY', 'AHceky/hotline-miami-coop')
STATE = os.environ.get('DL_STATE', 'dl_state.json')


def releases():
    req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/releases?per_page=100',
                                 headers={'Accept': 'application/vnd.github+json'})
    tok = os.environ.get('GH_TOKEN')
    if tok:
        req.add_header('Authorization', f'Bearer {tok}')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def notify(title, text):
    topic = os.environ.get('NTFY_TOPIC')
    if topic:
        # the title goes in the query: HTTP headers cannot carry Cyrillic
        url = f'https://ntfy.sh/{topic}?' + urllib.parse.urlencode({'title': title, 'tags': 'inbox_tray',
                                                                     'click': f'https://github.com/{REPO}/releases'})
        req = urllib.request.Request(url, data=text.encode('utf-8'), method='POST')
        urllib.request.urlopen(req, timeout=30).read()
    tg, chat = os.environ.get('TG_TOKEN'), os.environ.get('TG_CHAT')
    if tg and chat:
        data = urllib.parse.urlencode({'chat_id': chat, 'text': f'{title}\n{text}'}).encode()
        urllib.request.urlopen(f'https://api.telegram.org/bot{tg}/sendMessage', data=data, timeout=30).read()
    print(title, '|', text)


def main():
    counts = {f'{r["tag_name"]}/{a["name"]}': a['download_count'] for r in releases() for a in r['assets']}
    total = sum(counts.values())
    try:
        old = json.load(open(STATE))
    except (OSError, ValueError):
        old = None
    if old is None:
        notify('HM co-op: бот скачиваний запущен', f'Сейчас скачиваний всего: {total}. О новых сообщу сюда.')
    else:
        new = [(k, v - old.get(k, 0)) for k, v in counts.items() if v > old.get(k, 0)]
        if new:
            lines = [f'{k.split("/", 1)[1]}: +{d}' for k, d in sorted(new)]
            n = sum(d for _, d in new)
            notify(f'HM co-op скачали {n} раз(а)', '\n'.join(lines) + f'\nВсего скачиваний: {total}')
        else:
            print('no new downloads, total', total)
    json.dump(counts, open(STATE, 'w'))


if __name__ == '__main__':
    main()
