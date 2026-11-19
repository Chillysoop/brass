import {readFile, writeFile, mkdir, rename} from 'node:fs/promises';
import path from 'node:path';

// Credentials are supplied in memory by the local agent, never saved to the plan,
// result journal, game, command line, or generated asset provenance.
export async function runCharacterBatch({key, jobsPath, journalPath, rawDirectory,
  maxCredits = 1200, concurrency = 3, onProgress = () => {}, fetchImpl = fetch}) {
  if (!key) throw new Error('Sprite Fusion credential unavailable.');
  const jobs = JSON.parse(await readFile(jobsPath, 'utf8'));
  const entries = await readFile(journalPath, 'utf8').then(JSON.parse).catch(error => {
    if (error.code === 'ENOENT') return [];
    throw error;
  });
  await mkdir(path.dirname(journalPath), {recursive: true});
  await mkdir(rawDirectory, {recursive: true});
  const existing = new Map(entries.map(entry => [entry.name, entry]));
  const queue = jobs.filter(job => !existing.has(job.name));
  const unresolved = entries.filter(entry => !entry.completed && !['rejected', 'failed'].includes(entry.status));
  if (unresolved.length) {
    // A host timeout may leave a billed request marked queued/started. Recover its
    // saved asset through GET /assets before submitting any additional work.
    return {error: 'Recover incomplete Sprite Fusion requests before resuming.',
      needs_recovery: unresolved.map(entry => entry.name), pending: queue.map(job => job.name),
      submitted_credit_ceiling: 0, journalPath};
  }
  const active = new Set();
  let reserved = 0;
  let fatal = null;
  let serialSave = Promise.resolve();
  const persist = () => {
    const snapshot = JSON.stringify(entries, null, 2);
    serialSave = serialSave.then(async () => {
      await writeFile(journalPath + '.tmp', snapshot);
      await rename(journalPath + '.tmp', journalPath);
    });
    return serialSave;
  };
  const dependencies = job => (job.request.inputs || []).filter(input => input.from_job).map(input => input.from_job);
  const usable = entry => entry?.outputs?.some(output => output.asset?.id);
  async function execute(job) {
    const body = structuredClone(job.request);
    body.inputs = await Promise.all((body.inputs || []).map(async input => {
      if (input.local_path) return {data_url: 'data:image/png;base64,' + (await readFile(input.local_path)).toString('base64')};
      if (input.from_job) {
        const outputs = existing.get(input.from_job)?.outputs || [];
        const output = outputs.find(item => item.index === (input.output_index || 0)) || outputs[0];
        if (!output?.asset?.id) throw new Error('Missing completed pose: ' + input.from_job);
        return {asset_id: output.asset.id};
      }
      return input;
    }));
    if (!['animate', 'edit'].includes(body.operation)) throw new Error('Unsupported character operation.');
    const entry = {name: job.name, created_at: new Date().toISOString(), request: job.request,
      events: [], outputs: [], http_status: null, request_id: null, status: 'queued', completed: false};
    entries.push(entry);
    existing.set(job.name, entry);
    await persist();
    let response;
    for (let attempt = 0; attempt < 5; attempt++) {
      response = await fetchImpl('https://www.spritefusion.com/api/v1/generate', {
        method: 'POST', headers: {Authorization: 'Bearer ' + key, 'Content-Type': 'application/json'}, body: JSON.stringify(body)});
      if (response.status !== 429) break;
      const seconds = Math.max(1, Number(response.headers.get('Retry-After')) || 8);
      await response.arrayBuffer();
      onProgress({name: job.name, status: 'rate_limited', seconds});
      await new Promise(resolve => setTimeout(resolve, seconds * 1000));
    }
    entry.http_status = response.status;
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      entry.status = 'rejected';
      entry.error = error.error || {code: 'http_' + response.status};
      await persist();
      onProgress({name: job.name, status: entry.status, code: entry.error.code});
      if ([401, 402].includes(response.status)) fatal = new Error('Sprite Fusion request rejected: ' + entry.error.code);
      return;
    }
    entry.status = 'started';
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let complete = false;
    async function eventBlock(block) {
      const json = block.split('\n').filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
      if (!json) return;
      const event = JSON.parse(json);
      entry.events.push(event);
      if (event.request_id) entry.request_id = event.request_id;
      if (event.type === 'output') {
        const copy = structuredClone(event);
        copy.asset.local_files = {};
        const folder = path.join(rawDirectory, job.name.replace(/[^a-zA-Z0-9_-]/g, '_'));
        await mkdir(folder, {recursive: true});
        for (const [kind, url] of Object.entries({asset: event.asset.assetUrl, spritesheet: event.asset.spritesheetUrl, source: event.asset.sourceImageUrl})) {
          if (!url) continue;
          const suffix = path.extname(new URL(url).pathname) || (kind === 'asset' && event.asset.type === 'animation' ? '.webp' : '.png');
          const local = path.join(folder, String(event.index) + '-' + kind + suffix);
          const download = await fetchImpl(url);
          if (!download.ok) throw new Error('Asset download failed: ' + download.status);
          await writeFile(local, new Uint8Array(await download.arrayBuffer()));
          copy.asset.local_files[kind] = local;
        }
        entry.outputs.push(copy);
        await persist();
      }
      if (event.type === 'completed') {
        complete = true;
        entry.completed = true;
        entry.status = event.status;
        entry.remaining_credits = event.credits?.remaining;
        entry.error = event.error;
        if (entry.outputs.length !== event.output_count) throw new Error('Saved output count mismatch.');
      }
    }
    try {
      while (true) {
        const {value, done} = await reader.read();
        if (done) break;
        buffer = (buffer + decoder.decode(value, {stream: true})).replaceAll('\r\n', '\n');
        let end;
        while ((end = buffer.indexOf('\n\n')) >= 0) {
          const block = buffer.slice(0, end);
          buffer = buffer.slice(end + 2);
          await eventBlock(block);
        }
      }
      buffer += decoder.decode();
      if (buffer.trim()) await eventBlock(buffer);
      if (!complete) throw new Error('stream_interrupted');
    } catch (error) {
      entry.status = 'interrupted';
      entry.error = {code: error.message};
      // An output may already have been charged. Never automatically resubmit a POST.
      onProgress({name: job.name, status: entry.status, outputs: entry.outputs.length});
    }
    await persist();
    onProgress({name: job.name, status: entry.status, outputs: entry.outputs.length, remaining: entry.remaining_credits});
  }
  async function worker() {
    while (!fatal && queue.length) {
      const index = queue.findIndex(job => dependencies(job).every(name => usable(existing.get(name))));
      if (index < 0) {
        if (!active.size) break;
        await new Promise(resolve => setTimeout(resolve, 250));
        continue;
      }
      if (reserved + 15 > maxCredits) {fatal = new Error('Character batch credit limit reached.'); break;}
      const job = queue.splice(index, 1)[0];
      reserved += 15;
      active.add(job.name);
      try {await execute(job);} catch (error) {fatal = error;}
      finally {active.delete(job.name);}
    }
  }
  await Promise.all(Array.from({length: Math.max(1, Math.min(3, concurrency))}, worker));
  await persist();
  const result = {completed: entries.filter(entry => entry.status === 'succeeded').length,
    interrupted: entries.filter(entry => entry.status === 'interrupted').length,
    rejected: entries.filter(entry => ['rejected', 'failed'].includes(entry.status)).length,
    pending: queue.map(job => job.name), submitted_credit_ceiling: reserved, journalPath};
  if (fatal) result.error = fatal.message;
  return result;
}
