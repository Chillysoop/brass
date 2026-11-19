import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, readFile, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {runCharacterBatch} from './sprite_fusion_character_batch.mjs';

const key = 'test-credential-never-persist';
function stream(events, interrupted = false) {
  const bytes = new TextEncoder().encode(events.map(event => 'data: ' + JSON.stringify(event) + '\r\n\r\n').join('')
    + (interrupted ? ': keep-alive\r\n\r\n' : ''));
  return new Response(new ReadableStream({start(controller) {
    // Deliberately split CRLF and JSON tokens across transport chunks.
    for (let offset = 0; offset < bytes.length; offset += 7) controller.enqueue(bytes.slice(offset, offset + 7));
    controller.close();
  }}), {headers: {'Content-Type': 'text/event-stream'}});
}
async function setup(jobs) {
  const folder = await mkdtemp(path.join(tmpdir(), 'brass-sf-client-test-'));
  const jobsPath = path.join(folder, 'jobs.json');
  await writeFile(jobsPath, JSON.stringify(jobs));
  return {key, jobsPath, journalPath: path.join(folder, 'requests.json'), rawDirectory: path.join(folder, 'raw'), concurrency: 2};
}
function job(name, inputs = [{asset_id: 'owned-source'}]) {
  return {name, request: {operation: 'animate', prompt: 'A short recoil.', inputs, output_frames: 8, colors: 32}};
}

test('streaming downloads, pose dependencies, credential isolation and idempotent resume', async () => {
  const options = await setup([job('pose'), job('dependent', [{from_job: 'pose', output_index: 0}])]);
  let submitted = 0;
  const payloads = [];
  const fetchImpl = async (url, request) => {
    if (String(url).startsWith('https://assets.test/')) return new Response(new Uint8Array([1, 2, 3]));
    submitted++;
    payloads.push(JSON.parse(request.body));
    return stream([{type: 'started', request_id: 'request-' + submitted},
      {type: 'output', index: 0, asset: {id: 'saved-' + submitted, type: 'animation', assetUrl: 'https://assets.test/preview.webp', spritesheetUrl: 'https://assets.test/sheet.png'}},
      {type: 'completed', status: 'succeeded', output_count: 1, credits: {remaining: 100}}]);
  };
  const result = await runCharacterBatch({...options, maxCredits: 30, fetchImpl});
  assert.equal(result.completed, 2);
  assert.equal(submitted, 2);
  assert.deepEqual(payloads[1].inputs, [{asset_id: 'saved-1'}]);
  const saved = await readFile(options.journalPath, 'utf8');
  assert.ok(!saved.includes(key));
  for (const entry of JSON.parse(saved)) assert.deepEqual([...await readFile(entry.outputs[0].asset.local_files.spritesheet)], [1, 2, 3]);
  await runCharacterBatch({...options, maxCredits: 30, fetchImpl});
  assert.equal(submitted, 2, 'Resume must not charge completed requests again.');
});

test('interrupted billed output is preserved and never automatically resubmitted', async () => {
  const options = await setup([job('interrupted')]);
  let submitted = 0;
  const fetchImpl = async url => {
    if (String(url).startsWith('https://assets.test/')) return new Response(new Uint8Array([9]));
    submitted++;
    return stream([{type: 'started', request_id: 'saved-before-disconnect'},
      {type: 'output', index: 0, asset: {id: 'already-persisted', type: 'image', assetUrl: 'https://assets.test/source.png'}}], true);
  };
  const first = await runCharacterBatch({...options, maxCredits: 15, fetchImpl});
  assert.equal(first.interrupted, 1);
  await runCharacterBatch({...options, maxCredits: 15, fetchImpl});
  assert.equal(submitted, 1);
  assert.equal(JSON.parse(await readFile(options.journalPath, 'utf8'))[0].outputs[0].asset.id, 'already-persisted');
});

test('credit ceiling prevents another submission and retains its pending job', async () => {
  const options = await setup([job('first'), job('second')]);
  let submitted = 0;
  const result = await runCharacterBatch({...options, maxCredits: 15, concurrency: 1, fetchImpl: async () => {
    submitted++;
    return stream([{type: 'completed', status: 'succeeded', output_count: 0, credits: {remaining: 0}}]);
  }});
  assert.equal(submitted, 1);
  assert.match(result.error, /credit limit/);
  assert.deepEqual(result.pending, ['second']);
});

test('a host-disconnected queued or started record requires recovery before more billing', async () => {
  const options = await setup([job('uncertain'), job('next')]);
  await writeFile(options.journalPath, JSON.stringify([{name: 'uncertain', status: 'started', completed: false,
    request_id: 'possibly-billed', outputs: []}]));
  let submitted = 0;
  const result = await runCharacterBatch({...options, maxCredits: 30, fetchImpl: async () => {submitted++; throw new Error('must not submit');}});
  assert.equal(submitted, 0);
  assert.match(result.error, /Recover incomplete/);
  assert.deepEqual(result.needs_recovery, ['uncertain']);
  assert.deepEqual(result.pending, ['next']);
});
