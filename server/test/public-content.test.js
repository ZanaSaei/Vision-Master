'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { publicContentFor } = require('../src/public_content');

test('public Wordef projection never exposes the correct choice as its prompt', () => {
  const row = { public_content: { questions: [
    { index: 0, kind: 'meaning', word: 'serene', prompt: 'calm', options: ['calm', 'angry', 'loud', 'fast'] },
    { index: 1, kind: 'synonym', word: 'rapid', prompt: 'swift', options: ['swift', 'slow', 'calm', 'sad'] },
    { index: 2, kind: 'antonym', word: 'bright', prompt: 'dull', options: ['dull', 'shiny', 'dark', 'clear'] },
  ] }, secret_content: { answers: ['calm', 'swift', 'dull'] } };
  const projected = publicContentFor('2026-03-21', 'wordef', row);
  assert.equal(projected.questions[0].prompt, '');
  assert.equal(projected.questions[1].prompt, '');
  assert.equal(projected.questions[2].prompt, '');
  assert.deepEqual(projected.questions.map((question) => question.options), row.public_content.questions.map((question) => question.options));
});
