// Copyright 2026 The Khronos Group Inc.
// SPDX-License-Identifier: Apache-2.0
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const validator = require('../build/node/index.js');
const fixture = path.join(__dirname, '../test/ext/KHR_character/data/valid_complete.gltf');
const asset = () => JSON.parse(fs.readFileSync(fixture, 'utf8'));
const check = (json, bytes = false) => bytes
  ? validator.validateBytes(new Uint8Array(Buffer.from(JSON.stringify(json))), { writeTimestamp: false })
  : validator.validateString(JSON.stringify(json), { writeTimestamp: false });
const entry = a => a.extensions.KHR_character_expression.expressions[0];
const firstMapping = a => a.extensions.KHR_character_expression_mapping.expressionSetMappings['https://example.com/expressions/v1'].Smile[0];

test('compiled package exposes current family extension names', () => {
  const supported = validator.supportedExtensions();
  assert(supported.includes('KHR_character_expression_suppression'));
  assert(supported.includes('KHR_character_expression_texture_transform'));
  assert(!supported.includes('KHR_character_expression_mask'));
  assert(!supported.includes('KHR_character_expression_texture'));
});

test('bytes and string APIs accept canonical fixture and marker only assets', async () => {
  const marker = { asset: {version: '2.0'}, extensionsUsed: ['KHR_character'],
    extensionsRequired: ['KHR_character'], extensions: {KHR_character: {}} };
  for (const json of [marker, asset()]) for (const bytes of [false, true]) {
    assert.equal((await check(json, bytes)).issues.numErrors, 0);
  }
});

test('input-only legacy operation and target replacing source are rejected', async () => {
  const old = asset();
  const mapping = old.extensions.KHR_character_expression_mapping;
  mapping.expressionSetInputMappings = mapping.expressionSetMappings;
  delete mapping.expressionSetMappings;
  assert((await check(old)).issues.numErrors > 0);
  const wrong = asset();
  const source = firstMapping(wrong);
  source.target = source.source;
  delete source.source;
  assert((await check(wrong)).issues.numErrors > 0);
});

test('exact non-URI identifiers and independently named associations are accepted', async () => {
  const a = asset();
  firstMapping(a).name = '';
  const m = a.extensions.KHR_character_expression_mapping;
  m.expressionSetMappings.vrm1_expressions = m.expressionSetMappings['https://example.com/expressions/v1'];
  delete m.expressionSetMappings['https://example.com/expressions/v1'];
  const skeleton = a.extensions.KHR_character_skeleton_mapping;
  skeleton.skeletalRigMappings.vrm1_humanoid = { hips: {node: 1, name: 'Independent'}, spine: {node: 1, name: ''} };
  delete skeleton.skeletalRigMappings['https://example.com/skeleton/v1'];
  const report = await check(a);
  assert.equal(report.issues.numErrors, 0);
  assert.equal(report.issues.numWarnings, 0);
});

test('distinct names, shared animations, shared targets and nondefault neutral values are valid', async () => {
  const a = asset();
  a.nodes[1].translation = [1, 0, 0];
  a.extensions.KHR_character_expression.expressions.push({...structuredClone(entry(a)), name: 'sharedTarget'});
  const report = await check(a);
  assert.equal(report.issues.numErrors, 0);
  assert(!report.issues.messages.some(m => m.code === 'KHR_CHARACTER_EXPRESSION_VALIDATION_INCOMPLETE'));
});

test('both compiled APIs report duplicate native names at the later property', async () => {
  for (const bytes of [false, true]) for (const sameAnimation of [false, true]) {
    const a = asset();
    const duplicate = structuredClone(entry(a));
    if (!sameAnimation) {
      a.animations.push(structuredClone(a.animations[0]));
      duplicate.animation = a.animations.length - 1;
    }
    const expressions = a.extensions.KHR_character_expression.expressions;
    const later = expressions.length;
    expressions.push(duplicate);
    const report = await check(a, bytes);
    const issues = report.issues.messages.filter(m => m.code === 'KHR_CHARACTER_EXPRESSION_DUPLICATE_NAME');
    assert.equal(issues.length, 1);
    assert.equal(issues[0].pointer, `/extensions/KHR_character_expression/expressions/${later}/name`);
    assert.match(issues[0].message, /expressions\/0\/name/);
  }
});

test('compiled APIs compare native names exactly without normalization', async () => {
  for (const bytes of [false, true]) {
    const a = asset();
    a.extensions.KHR_character_expression.expressions = ['smile', 'Smile', ' smile', 'smile ', 'é', 'e\u0301', '__proto__', 'toString']
      .map(name => ({name, animation: 0}));
    const report = await check(a, bytes);
    assert.equal(report.issues.numErrors, 0);
    a.extensions.KHR_character_expression.expressions.push({name: JSON.parse('"\\u0073mile"'), animation: 0});
    assert((await check(a, bytes)).issues.messages.some(m => m.code === 'KHR_CHARACTER_EXPRESSION_DUPLICATE_NAME'));
  }
});

test('pose type and mapping bounds remain asset validity gates', async () => {
  for (const mutate of [a => delete a.animations[1].extensions.KHR_character_reference_pose.poseType,
    a => { firstMapping(a).weight = 1.1; }, a => { firstMapping(a).source = 999; }]) {
    const a = asset(); mutate(a);
    assert((await check(a)).issues.numErrors > 0);
  }
});

test('visibility ancestor conflicts and always roles are valid metadata', async () => {
  const a = asset();
  a.nodes[0].extensions.KHR_node_visibility_hint = {role: 'third_person'};
  a.nodes[2].extensions.KHR_node_visibility_hint = {role: 'first_person'};
  a.meshes[0].primitives[0].extensions.KHR_mesh_primitive_visibility_hint = {role: 'always'};
  assert.equal((await check(a)).issues.numErrors, 0);
});

test('blend threshold warns while custom tokens stay valid', async () => {
  const a = asset();
  entry(a).extensions.KHR_character_expression_suppression.suppressions = [
    {target: 0, threshold: 0.4}, {target: 0, type: 'ACME_custom', amount: 0.2}
  ];
  const report = await check(a);
  assert.equal(report.issues.numErrors, 0);
  assert(report.issues.messages.some(m => m.code === 'KHR_CHARACTER_SUPPRESSION_IGNORED_THRESHOLD' && m.severity === 1));
});
